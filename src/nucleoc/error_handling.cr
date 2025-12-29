# Error handling utilities for CML-based concurrent operations
require "cml"
require "atomic"

module Nucleoc
  # Error handling patterns using CML.wrap_handler
  module ErrorHandling
    # Error report for worker failures.
    struct WorkerError
      getter worker_id : Int32
      getter exception : Exception
      getter task_id : Int32?
      getter batch_start_idx : Int32?

      def initialize(@worker_id, @exception, @task_id = nil, @batch_start_idx = nil)
      end
    end

    # Wraps an event with exception handling using CML.wrap_handler
    # Returns an event that either yields the original result or a fallback value
    # if an exception occurs during event execution.
    def self.with_error_handler(evt : CML::Event(T), fallback : T) : CML::Event(T) forall T
      CML.wrap_handler(evt) do |ex|
        Log.error { "Error in event execution: #{ex.message}" }
        fallback
      end
    end

    # Wraps an event with exception handling and returns a union type
    # that includes either the result or the exception.
    # Useful when you need to propagate errors rather than swallow them.
    def self.with_error_propagation(evt : CML::Event(T)) : CML::Event(T | Exception) forall T
      union_evt = CML.wrap(evt) { |value| value.as(T | Exception) }
      CML.wrap_handler(union_evt) do |ex|
        Log.error { "Error in event execution: #{ex.message}" }
        ex.as(T | Exception)
      end
    end

    # Creates an event that retries another event up to max_attempts times
    # with exponential backoff between attempts.
    # The retry event returns the successful result or the last exception.
    # Provide a type hint so the retry event has a stable result type.
    def self.with_retry(type : T.class, max_attempts : Int32 = 3, base_delay : Time::Span = 100.milliseconds, &evt : -> CML::Event(T)) : CML::Event(T | Exception) forall T
      CML.guard do
        attempts = 0
        last_ex = nil.as(Exception?)

        loop do
          attempts += 1
          begin
            inner_evt = evt.call
            result = CML.sync(inner_evt)
            break CML.always(result.as(T | Exception))
          rescue ex
            last_ex = ex
            if attempts >= max_attempts
              break CML.always(last_ex.not_nil!.as(T | Exception))
            end
            sleep base_delay * (2 ** (attempts - 1))
          end
        end
      end
    end

    # Circuit breaker pattern for rate limiting failing operations
    class CircuitBreaker
      @state = :closed
      @failure_count = 0
      @last_failure_time = Time.utc
      @reset_timeout = 1.second

      # States:
      # - :closed: normal operation
      # - :open: failing fast (circuit open)
      # - :half_open: testing if service has recovered
      property state : Symbol

      def initialize(@failure_threshold : Int32 = 5, @reset_timeout : Time::Span = 1.second)
        @lock = Mutex.new
      end

      # Executes an operation through the circuit breaker
      def call(operation)
        case current_state
        when :open
          return # Fast fail
        when :half_open
          # Allow one trial
        when :closed
          # Normal operation
        end

        begin
          result = operation.call
          record_success
          result
        rescue ex
          record_failure
          raise ex
        end
      end

      # Executes an event through the circuit breaker
      def call_event(evt : CML::Event(T)) : CML::Event(T?) forall T
        case current_state
        when :open
          # Circuit open, fast fail with nil
          return CML.always(nil.as(T?))
        end

        # First convert Event(T) to Event(T?)
        evt_t_nil = CML.wrap(evt) { |value| value.as(T?) }

        # Then add exception handling that returns nil on failure
        CML.wrap_handler(evt_t_nil) do |ex|
          record_failure
          nil.as(T?)
        end
      end

      private def current_state : Symbol
        @lock.synchronize do
          if @state == :open && Time.utc - @last_failure_time >= @reset_timeout
            @state = :half_open
          end
          @state
        end
      end

      private def record_success
        @lock.synchronize do
          @state = :closed
          @failure_count = 0
        end
      end

      private def record_failure
        @lock.synchronize do
          @failure_count += 1
          @last_failure_time = Time.utc

          if @failure_count >= @failure_threshold
            @state = :open
          elsif @state == :half_open
            @state = :open # Trial failed, go back to open
          end
        end
      end
    end

    # Supervisor for monitoring and restarting fibers
    class Supervisor
      @workers = [] of CML::Chan(WorkerCommand)
      @supervisor_ch = CML::Chan(SupervisorMessage).new

      enum WorkerCommand
        Stop
        Restart
        Status
      end

      struct SupervisorMessage
        getter worker_id : Int32
        getter status : Symbol
        getter exception : Exception?

        def initialize(@worker_id, @status, @exception = nil)
        end
      end

      # Creates a supervisor that monitors a worker fiber
      # The worker block should run a loop and rescue any exceptions
      def supervise(worker_id : Int32, &worker : ->) : CML::Chan(WorkerCommand)
        control_ch = CML::Chan(WorkerCommand).new

        spawn do
          restart_count = 0
          max_restarts = 3
          stop_requested = Atomic(Bool).new(false)

          spawn do
            loop do
              cmd = control_ch.recv
              case cmd
              when WorkerCommand::Stop
                stop_requested.set(true)
                break
              when WorkerCommand::Restart
                stop_requested.set(true)
              when WorkerCommand::Status
              end
            end
          end

          loop do
            break if stop_requested.get
            begin
              worker.call
              # Worker exited normally (shouldn't happen for long-running workers)
              @supervisor_ch.send(SupervisorMessage.new(worker_id, :exited))
              break
            rescue ex
              restart_count += 1
              @supervisor_ch.send(SupervisorMessage.new(worker_id, :crashed, ex))

              if restart_count >= max_restarts
                # Too many restarts, give up
                @supervisor_ch.send(SupervisorMessage.new(worker_id, :failed))
                break
              end

              # Wait before restarting (exponential backoff)
              delay = ((2 ** restart_count) * 100).milliseconds
              sleep delay

              # Command checking disabled for now
              # CML::Chan doesn't have non-blocking receive
              # In production, use CML.choice with timeout
            end
          end
        end

        control_ch
      end

      # Starts the supervisor fiber that monitors all workers
      def start
        spawn do
          loop do
            msg = @supervisor_ch.recv
            case msg.status
            when :crashed
              Log.warn { "Worker #{msg.worker_id} crashed: #{msg.exception.try(&.message)}" }
            when :exited
              Log.info { "Worker #{msg.worker_id} exited normally" }
            when :failed
              Log.error { "Worker #{msg.worker_id} failed after too many restarts" }
            end
          end
        end
      end
    end
  end
end
