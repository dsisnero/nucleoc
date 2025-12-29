require "cml"
require "atomic"
require "./par_sort"
require "./error_handling"

module Nucleoc
  # CML-based worker pool using proper event composition
  class CMLWorkerPool
    getter size : Int32
    getter config : Config

    private alias WorkerTask = Task | BatchTask
    @workers : Array(CML::Mailbox(WorkerTask))
    @circuit_breaker : ErrorHandling::CircuitBreaker
    @supervisor : ErrorHandling::Supervisor
    @error_mailbox : CML::Mailbox(ErrorHandling::WorkerError)
    @error_handler : Proc(ErrorHandling::WorkerError, Nil)?
    @next_worker : Atomic(Int32)

    # Task for a worker to process
    private struct Task
      getter id : Int32
      getter haystack : String
      getter needle : String
      getter? compute_indices : Bool
      getter reply_channel : CML::Mailbox(TaskResult)

      def initialize(@id, @haystack, @needle, @compute_indices, @reply_channel)
      end
    end

    # Batch task for processing multiple haystacks with a single needle
    private struct BatchTask
      getter start_idx : Int32
      getter haystacks : Array(String)
      getter needle : String
      getter? compute_indices : Bool
      getter reply_channel : CML::Mailbox(BatchTaskResult)

      def initialize(@start_idx, @haystacks, @needle, @compute_indices, @reply_channel)
      end
    end

    # Result from a batch worker
    private struct BatchTaskResult
      getter start_idx : Int32
      getter scores : Array(UInt16?)
      getter indices : Array(Array(UInt32)?)?

      def initialize(@start_idx, @scores, @indices)
      end
    end

    # Result from a worker
    private struct TaskResult
      getter id : Int32
      getter score : UInt16?
      getter indices : Array(UInt32)?

      def initialize(@id, @score, @indices)
      end
    end

    # For sorting match results
    private struct SortedMatch
      getter score : UInt16?
      getter id : Int32
      getter indices : Array(UInt32)?

      def initialize(@score, @id, @indices)
      end
    end

    def initialize(size : Int32 = CMLWorkerPool.default_size, @config : Config = Config::DEFAULT, @error_handler : Proc(ErrorHandling::WorkerError, Nil)? = nil)
      @size = size > 0 ? size : 1
      @workers = Array.new(@size) { CML::Mailbox(WorkerTask).new }
      @circuit_breaker = ErrorHandling::CircuitBreaker.new
      @supervisor = ErrorHandling::Supervisor.new
      @error_mailbox = CML::Mailbox(ErrorHandling::WorkerError).new
      @next_worker = Atomic(Int32).new(0)
      start_workers
      @supervisor.start
    end

    def error_mailbox : CML::Mailbox(ErrorHandling::WorkerError)
      @error_mailbox
    end

    def self.default_size : Int32
      cpu_count = System.cpu_count
      size = cpu_count.is_a?(Int32) ? cpu_count : cpu_count.to_i32
      size.clamp(1, 16)
    end

    # Submit a batch of haystacks to match against a single needle
    # Returns scores (and optional indices) in the original order
    def match_many(haystacks : Array(String), needle : String, compute_indices : Bool = false, timeout : Time::Span? = nil) : {Array(UInt16?), Array(Array(UInt32)?)?}
      return {[] of UInt16?, nil} if haystacks.empty?

      collect_batch_results(haystacks, needle, compute_indices, timeout)
    end

    # Submit a batch of haystacks to match against a single needle,
    # returning results sorted by score descending (higher scores first).
    # Returns sorted scores and indices (if requested).
    def match_many_sorted(haystacks : Array(String), needle : String, compute_indices : Bool = false, cancelled : Atomic(Bool)? = nil, timeout : Time::Span? = nil) : {Array(UInt16?), Array(Array(UInt32)?)?}
      return {[] of UInt16?, nil} if haystacks.empty?

      scores, indices = collect_batch_results(haystacks, needle, compute_indices, timeout)
      matches = Array(SortedMatch).new(haystacks.size) do |idx|
        SortedMatch.new(scores[idx], idx, indices ? indices[idx] : nil)
      end

      # Sort matches using parallel quicksort
      cancel_flag = cancelled || Atomic(Bool).new(false)
      ParSort.par_quicksort(matches, cancel_flag) do |a, b|
        # Sort by score descending (higher score first)
        # Nil scores (no match) go to the end
        a_score = a.score
        b_score = b.score
        case {a_score, b_score}
        when {nil, nil}
          a.id < b.id
        when {nil, _}
          false
        when {_, nil}
          true
        else
          # Both scores are non-nil (guaranteed by case above)
          a_val = a_score.as(UInt16)
          b_val = b_score.as(UInt16)
          if a_val == b_val
            a.id < b.id
          else
            a_val > b_val
          end
        end
      end

      # Extract sorted results
      sorted_scores = matches.map(&.score)
      sorted_indices = compute_indices ? matches.map(&.indices) : nil

      {sorted_scores, sorted_indices}
    end

    # Submit a batch of haystacks using chunked distribution and intra-worker parallelism
    def match_many_batch(haystacks : Array(String), needle : String, compute_indices : Bool = false) : {Array(UInt16?), Array(Array(UInt32)?)?}
      match_many(haystacks, needle, compute_indices)
    end

    # Submit single match with timeout using CML.choose
    def match_with_timeout(haystack : String, needle : String, timeout : Time::Span = 5.seconds, compute_indices : Bool = false) : {UInt16?, Array(UInt32)?}
      response_ch = CML::Mailbox(TaskResult).new
      normalized_needle = normalize_needle(needle)
      task = Task.new(0, haystack, normalized_needle, compute_indices, response_ch)

      worker_idx = (@next_worker.add(1) % @size).abs
      @workers[worker_idx].send(task)

      timeout_evt = CML.wrap(CML.timeout(timeout)) { :timeout.as(TaskResult | Symbol) }
      recv_evt = CML.wrap(response_ch.recv_evt) { |result| result.as(TaskResult | Symbol) }
      circuit_event = @circuit_breaker.call_event(recv_evt)
      circuit_wrapped = CML.wrap(circuit_event) { |result| result || :circuit_open.as(TaskResult | Symbol) }

      begin
        result = CML.sync(CML.choose([circuit_wrapped, timeout_evt]))

        # Handle union type
        case result
        when TaskResult
          {result.score, result.indices}
        when :timeout
          {nil, nil}
        when :circuit_open
          {nil, nil}
        else
          {nil, nil}
        end
      rescue ex
        {nil, nil}
      end
    end

    private def start_workers
      @size.times do |worker_idx|
        worker_ch = @workers[worker_idx]

        # Supervise worker fiber for fault tolerance
        _control_ch = @supervisor.supervise(worker_idx) do
          matcher = Matcher.new(@config)
          indices_buffer = [] of UInt32

          loop do
            # Wait for task (blocks until task arrives)
            task = worker_ch.recv

            begin
              case task
              when Task
                # Process single task
                score = if task.compute_indices?
                          indices_buffer.clear
                          matcher.fuzzy_indices_normalized(task.haystack, task.needle, indices_buffer)
                        else
                          matcher.fuzzy_match_normalized(task.haystack, task.needle)
                        end

                indices = task.compute_indices? ? indices_buffer.dup : nil
                task.reply_channel.send(TaskResult.new(task.id, score, indices))
              when BatchTask
                # Process batch using parallel matcher for intra-task parallelism
                scores = Array(UInt16?).new(task.haystacks.size, nil)
                indices = task.compute_indices? ? Array(Array(UInt32)?).new(task.haystacks.size, nil) : nil

                task.haystacks.each_with_index do |haystack, idx|
                  if task.compute_indices?
                    indices_buffer.clear
                    score = matcher.fuzzy_indices_normalized(haystack, task.needle, indices_buffer)
                    scores[idx] = score
                    indices.not_nil![idx] = indices_buffer.dup
                  else
                    scores[idx] = matcher.fuzzy_match_normalized(haystack, task.needle)
                  end
                end

                task.reply_channel.send(BatchTaskResult.new(task.start_idx, scores, indices))
              end
            rescue ex
              # Log the error and send a failure result
              Log.error(exception: ex) { "Worker #{worker_idx} failed processing task: #{ex.message}" }
              worker_error = case task
                             when Task
                               ErrorHandling::WorkerError.new(worker_idx, ex, task.id, nil)
                             when BatchTask
                               ErrorHandling::WorkerError.new(worker_idx, ex, nil, task.start_idx)
                             else
                               ErrorHandling::WorkerError.new(worker_idx, ex)
                             end
              @error_mailbox.send(worker_error)
              begin
                @error_handler.try(&.call(worker_error))
              rescue handler_ex
                Log.error(exception: handler_ex) { "Worker error handler failed: #{handler_ex.message}" }
              end

              case task
              when Task
                # Send nil result to indicate failure
                task.reply_channel.send(TaskResult.new(task.id, nil, nil))
              when BatchTask
                # Send nil scores for all items in batch
                nil_scores = Array(UInt16?).new(task.haystacks.size, nil)
                nil_indices = task.compute_indices? ? Array(Array(UInt32)?).new(task.haystacks.size, nil) : nil
                task.reply_channel.send(BatchTaskResult.new(task.start_idx, nil_scores, nil_indices))
              end
            end
          end
        end
        # _control_ch can be used to stop/restart worker if needed
      end
    end

    private def normalize_needle(needle : String) : String
      Matcher.new(@config).normalize_needle(needle)
    end

    private def chunk_size_for(total : Int32) : Int32
      target_chunks = (@size * 4).clamp(1, 64)
      (total // target_chunks).clamp(1, total)
    end

    private def collect_batch_results(haystacks : Array(String), needle : String, compute_indices : Bool, timeout : Time::Span?) : {Array(UInt16?), Array(Array(UInt32)?)?}
      response_ch = CML::Mailbox(BatchTaskResult).new
      chunk_size = chunk_size_for(haystacks.size)
      chunk_count = (haystacks.size + chunk_size - 1) // chunk_size
      normalized_needle = normalize_needle(needle)

      haystacks.each_slice(chunk_size).with_index do |slice, chunk_idx|
        start_idx = chunk_idx * chunk_size
        task = BatchTask.new(start_idx, slice, normalized_needle, compute_indices, response_ch)
        worker_idx = chunk_idx % @size
        @workers[worker_idx].send(task)
      end

      scores = Array(UInt16?).new(haystacks.size, nil)
      indices = compute_indices ? Array(Array(UInt32)?).new(haystacks.size, nil) : nil

      if timeout
        timeout_evt = CML.wrap(CML.timeout(timeout.as(Time::Span))) { :timeout.as(BatchTaskResult | Symbol) }
        remaining = chunk_count
        while remaining > 0
          recv_evt = CML.wrap(response_ch.recv_evt) { |result| result.as(BatchTaskResult | Symbol) }
          result = CML.sync(CML.choose([recv_evt, timeout_evt]))

          if result.is_a?(BatchTaskResult)
            result.scores.each_with_index do |score, idx|
              scores[result.start_idx + idx] = score
            end
            if compute_indices && indices && result.indices
              result.indices.as(Array(Array(UInt32)?)).each_with_index do |idx_list, idx|
                indices[result.start_idx + idx] = idx_list
              end
            end
            remaining -= 1
          else
            break
          end
        end
        remaining.times { response_ch.recv } if remaining > 0
      else
        chunk_count.times do
          result = response_ch.recv
          result.scores.each_with_index do |score, idx|
            scores[result.start_idx + idx] = score
          end
          if compute_indices && indices && result.indices
            result.indices.as(Array(Array(UInt32)?)).each_with_index do |idx_list, idx|
              indices[result.start_idx + idx] = idx_list
            end
          end
        end
      end

      {scores, indices}
    end
  end
end
