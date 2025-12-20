require "cml"
require "atomic"
require "./par_sort"

module Nucleoc
  # CML-based worker pool using proper event composition
  class CMLWorkerPool
    getter size : Int32
    getter config : Config

    @workers : Array(CML::Chan(Task))

    # Task for a worker to process
    private struct Task
      getter id : Int32
      getter haystack : String
      getter needle : String
      getter? compute_indices : Bool
      getter reply_channel : CML::Chan(TaskResult)

      def initialize(@id, @haystack, @needle, @compute_indices, @reply_channel)
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

    def initialize(size : Int32 = CMLWorkerPool.default_size, @config : Config = Config::DEFAULT)
      @size = size > 0 ? size : 1
      @workers = Array.new(@size) { CML::Chan(Task).new }
      start_workers
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

      # Create a response channel for this batch
      response_ch = CML::Chan(TaskResult).new

      # Submit tasks in a separate fiber to avoid deadlock
      spawn do
        haystacks.each_with_index do |haystack, idx|
          task = Task.new(idx, haystack, needle, compute_indices, response_ch)

          # Simple round-robin distribution
          worker_idx = idx % @size
          @workers[worker_idx].send(task)
        end
      end

      # Collect results as they arrive
      scores = Array(UInt16?).new(haystacks.size, nil)
      indices = compute_indices ? Array(Array(UInt32)?).new(haystacks.size, nil) : nil

      if timeout
        # Use timeout event
        timeout_evt = CML.wrap(CML.timeout(timeout.as(Time::Span))) { :timeout.as(TaskResult | Symbol) }
        # Wrap receive event to ensure consistent Event type
        recv_evt = CML.wrap(response_ch.recv_evt) { |result| result.as(TaskResult | Symbol) }
        remaining = haystacks.size
        while remaining > 0
          # Create choice between receiving next result and timeout
          choice = CML.choose([recv_evt, timeout_evt])

          result = CML.sync(choice)
          if result.is_a?(TaskResult)
            scores[result.id] = result.score
            if compute_indices && indices
              indices[result.id] = result.indices
            end
            remaining -= 1
          else
            # Timeout occurred
            break
          end
        end
      else
        # No timeout - original behavior
        haystacks.size.times do
          result = response_ch.recv
          scores[result.id] = result.score
          if compute_indices && indices
            indices[result.id] = result.indices
          end
        end
      end

      {scores, indices}
    end

    # Submit a batch of haystacks to match against a single needle,
    # returning results sorted by score descending (higher scores first).
    # Returns sorted scores and indices (if requested).
    def match_many_sorted(haystacks : Array(String), needle : String, compute_indices : Bool = false, cancelled : Atomic(Bool)? = nil, timeout : Time::Span? = nil) : {Array(UInt16?), Array(Array(UInt32)?)?}
      return {[] of UInt16?, nil} if haystacks.empty?

      # Create a response channel for this batch
      response_ch = CML::Chan(TaskResult).new

      # Submit tasks in a separate fiber to avoid deadlock
      spawn do
        haystacks.each_with_index do |haystack, idx|
          task = Task.new(idx, haystack, needle, compute_indices, response_ch)

          # Simple round-robin distribution
          worker_idx = idx % @size
          @workers[worker_idx].send(task)
        end
      end

      # Collect results as they arrive
      matches = Array(SortedMatch).new(haystacks.size)

      if timeout
        # Use timeout event
        timeout_evt = CML.wrap(CML.timeout(timeout.as(Time::Span))) { :timeout.as(TaskResult | Symbol) }
        # Wrap receive event to ensure consistent Event type
        recv_evt = CML.wrap(response_ch.recv_evt) { |result| result.as(TaskResult | Symbol) }
        remaining = haystacks.size
        while remaining > 0
          # Create choice between receiving next result and timeout
          choice = CML.choose([recv_evt, timeout_evt])

          result = CML.sync(choice)
          if result.is_a?(TaskResult)
            matches << SortedMatch.new(result.score, result.id, result.indices)
            remaining -= 1
          else
            # Timeout occurred
            break
          end
        end
      else
        # No timeout - original behavior
        haystacks.size.times do
          result = response_ch.recv
          matches << SortedMatch.new(result.score, result.id, result.indices)
        end
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

    # Submit single match with timeout using CML.choose
    def match_with_timeout(haystack : String, needle : String, timeout : Time::Span = 5.seconds, compute_indices : Bool = false) : {UInt16?, Array(UInt32)?}
      response_ch = CML::Chan(TaskResult).new
      task = Task.new(0, haystack, needle, compute_indices, response_ch)

      # Create events for sending to each worker
      # Each event will: send to worker, then wait for response
      worker_events = @workers.map do |worker_ch|
        # Create an event that sends to worker and waits for response
        CML.wrap(worker_ch.send_evt(task)) do
          response_ch.recv
        end
      end

      # Create a choice among all workers
      # All worker_events return TaskResult
      work_choice = CML.choose(worker_events)
      # Wrap to union type for compatibility with timeout event
      work_choice = CML.wrap(work_choice) { |result| result.as(TaskResult | Symbol) }

      # Timeout event returns Nil, wrap to Symbol to match type
      timeout_evt = CML.wrap(CML.timeout(timeout)) { :timeout.as(TaskResult | Symbol) }

      # Now we have Event(TaskResult) and Event(Symbol)
      # CML.choose will return TaskResult | Symbol
      begin
        result = CML.sync(CML.choose([work_choice, timeout_evt]))

        # Handle union type
        if result.is_a?(TaskResult)
          {result.score, result.indices}
        else
          # result is :timeout symbol
          {nil, nil}
        end
      rescue ex
        {nil, nil}
      end
    end

    private def start_workers
      @size.times do |worker_idx|
        worker_ch = @workers[worker_idx]

        spawn do
          matcher = Matcher.new(@config)

          loop do
            # Wait for task (blocks until task arrives)
            task = worker_ch.recv

            # Process the task
            score = if task.compute_indices?
                      indices = [] of UInt32
                      matcher.fuzzy_indices(task.haystack, task.needle, indices)
                    else
                      matcher.fuzzy_match(task.haystack, task.needle)
                    end

            indices = task.compute_indices? ? indices : nil

            # Send result back
            task.reply_channel.send(TaskResult.new(task.id, score, indices))
          end
        end
      end
    end
  end
end
