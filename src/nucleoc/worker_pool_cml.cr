require "cml"

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
      getter compute_indices : Bool
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
    def match_many(haystacks : Array(String), needle : String, compute_indices : Bool = false) : {Array(UInt16?), Array(Array(UInt32)?)?}
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

      haystacks.size.times do
        result = response_ch.recv
        scores[result.id] = result.score
        if compute_indices && indices
          indices[result.id] = result.indices
        end
      end

      {scores, indices}
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

      # Timeout event returns Symbol
      timeout_evt = CML.timeout(timeout)

      # Now we have Event(TaskResult) and Event(Symbol)
      # CML.choose will return TaskResult | Symbol
      begin
        result = CML.sync(CML.choose(work_choice, timeout_evt))

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
            score = if task.compute_indices
                      indices = [] of UInt32
                      matcher.fuzzy_indices(task.haystack, task.needle, indices)
                    else
                      matcher.fuzzy_match(task.haystack, task.needle)
                    end

            indices = task.compute_indices ? indices : nil

            # Send result back
            task.reply_channel.send(TaskResult.new(task.id, score, indices))
          end
        end
      end
    end
  end
end
