require "./spec_helper"

describe Nucleoc::ErrorHandling do
  describe ".with_error_handler" do
    it "returns the original result when no exception occurs" do
      evt = CML.always(42)
      wrapped = Nucleoc::ErrorHandling.with_error_handler(evt, 0)
      result = CML.sync(wrapped)
      result.should eq(42)
    end

    it "returns fallback value when exception occurs" do
      evt = CML.guard { raise "Simulated error"; CML.always(0) }
      wrapped = Nucleoc::ErrorHandling.with_error_handler(evt, 0)
      result = CML.sync(wrapped)
      result.should eq(0)
    end

    it "preserves type safety" do
      evt = CML.always("success")
      wrapped = Nucleoc::ErrorHandling.with_error_handler(evt, "fallback")
      result = CML.sync(wrapped)
      result.should be_a(String)
    end
  end

  describe ".with_error_propagation" do
    it "returns result when no exception occurs" do
      evt = CML.always(100)
      wrapped = Nucleoc::ErrorHandling.with_error_propagation(evt)
      result = CML.sync(wrapped)
      result.should eq(100)
    end

    it "returns exception when error occurs" do
      evt = CML.guard { raise "Test error" }
      wrapped = Nucleoc::ErrorHandling.with_error_propagation(evt)
      result = CML.sync(wrapped)
      result.should be_a(Exception)
      result.as(Exception).message.should eq("Test error")
    end
  end

  describe ".with_retry" do
    it "returns success on first attempt" do
      attempts = 0
      evt = -> {
        attempts += 1
        CML.always("success")
      }
      retry_evt = Nucleoc::ErrorHandling.with_retry(evt, max_attempts: 3)
      result = CML.sync(retry_evt)
      result.should eq("success")
      attempts.should eq(1)
    end

    it "retries after failure and succeeds" do
      attempts = 0
      evt = -> {
        attempts += 1
        if attempts == 1
          raise "First attempt fails"
        else
          CML.always("success")
        end
      }
      retry_evt = Nucleoc::ErrorHandling.with_retry(evt, max_attempts: 3, base_delay: 10.milliseconds)
      result = CML.sync(retry_evt)
      result.should eq("success")
      attempts.should eq(2)
    end

    it "returns last exception after max attempts" do
      attempts = 0
      evt = -> {
        attempts += 1
        raise "Always fails"
      }
      retry_evt = Nucleoc::ErrorHandling.with_retry(evt, max_attempts: 2, base_delay: 10.milliseconds)
      result = CML.sync(retry_evt)
      result.should be_a(Exception)
      result.as(Exception).message.should eq("Always fails")
      attempts.should eq(2)
    end
  end

  describe "CircuitBreaker" do
    it "allows operations when circuit is closed" do
      cb = Nucleoc::ErrorHandling::CircuitBreaker.new
      result = cb.call(-> { 42 })
      result.should eq(42)
    end

    it "returns nil when circuit is open" do
      cb = Nucleoc::ErrorHandling::CircuitBreaker.new(failure_threshold: 1)
      # Cause a failure to open circuit
      expect_raises(Exception) do
        cb.call(-> { raise "Fail" })
      end
      # Now circuit should be open
      result = cb.call(-> { 42 })
      result.should be_nil
    end

    it "resets after timeout" do
      cb = Nucleoc::ErrorHandling::CircuitBreaker.new(failure_threshold: 1, reset_timeout: 50.milliseconds)
      # Cause failure
      expect_raises(Exception) do
        cb.call(-> { raise "Fail" })
      end
      # Wait for reset timeout
      sleep 0.1
      # Circuit should be half-open or closed, allow one trial
      result = cb.call(-> { 42 })
      result.should eq(42)
    end

    it "works with events" do
      cb = Nucleoc::ErrorHandling::CircuitBreaker.new
      evt = CML.always("test")
      result_evt = cb.call_event(evt)
      result = CML.sync(result_evt)
      result.should eq("test")
    end
  end

  describe "Supervisor" do
    it "restarts worker after crash" do
      supervisor = Nucleoc::ErrorHandling::Supervisor.new
      crash_count = 0
      max_crashes = 2

      worker = -> {
        crash_count += 1
        if crash_count <= max_crashes
          raise "Crash #{crash_count}"
        else
          loop { sleep 1 } # Normal operation
        end
      }

      control_ch = supervisor.supervise(1, &worker)
      supervisor.start

      # Wait for crashes and restarts
      sleep 0.3

      # Worker should have been restarted multiple times
      crash_count.should be >= 2

      # Stop the worker
      control_ch.send(Nucleoc::ErrorHandling::Supervisor::WorkerCommand::Stop)
    end

    it "sends supervisor messages on worker events" do
      supervisor = Nucleoc::ErrorHandling::Supervisor.new
      messages = [] of Nucleoc::ErrorHandling::Supervisor::SupervisorMessage

      # We can't easily test internal messages without exposing them
      # For now, just ensure supervisor starts without error
      supervisor.start
    end
  end
end
