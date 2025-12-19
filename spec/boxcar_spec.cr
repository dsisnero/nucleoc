require "./spec_helper"
require "../src/nucleoc/boxcar"

describe Nucleoc::BoxcarVector do
  describe "basic operations" do
    it "pushes and retrieves values" do
      vec = Nucleoc::BoxcarVector(Int32).new
      idx1 = vec.push(42)
      idx2 = vec.push(100)

      idx1.should eq 0
      idx2.should eq 1
      vec.get(0).should eq 42
      vec.get(1).should eq 100
      vec.get(2).should be_nil
    end

    it "returns size" do
      vec = Nucleoc::BoxcarVector(String).new
      vec.size.should eq 0
      vec.push("a")
      vec.size.should eq 1
      vec.push("b")
      vec.size.should eq 2
    end

    it "gets with bang method" do
      vec = Nucleoc::BoxcarVector(Int32).new
      vec.push(99)
      vec.get!(0).should eq 99
      expect_raises(IndexError) { vec.get!(1) }
    end

    it "handles push_all with small batch" do
      vec = Nucleoc::BoxcarVector(Int32).new
      vec.push_all([1, 2, 3, 4, 5])
      vec.size.should eq 5
      (0...5).each do |i|
        vec.get(i).should eq(i + 1)
      end
    end

    it "creates snapshot" do
      vec = Nucleoc::BoxcarVector(Int32).new
      10.times { |i| vec.push(i) }

      snapshot = vec.snapshot
      result = [] of Int32
      snapshot.each { |v| result << v }
      result.should eq (0...10).to_a

      # Snapshot should be immutable (won't see new elements)
      vec.push(99)
      snapshot2 = vec.snapshot
      snapshot2.to_a.size.should eq 11
    end

    it "handles snapshot with start index" do
      vec = Nucleoc::BoxcarVector(Int32).new
      20.times { |i| vec.push(i) }

      snapshot = vec.snapshot(5)
      snapshot.to_a.should eq (5...20).to_a
    end

    it "clears vector" do
      vec = Nucleoc::BoxcarVector(Int32).new
      10.times { |i| vec.push(i) }
      vec.size.should eq 10

      vec.clear
      vec.size.should eq 0
      vec.get(0).should be_nil

      # Should be reusable
      vec.push(999)
      vec.get(0).should eq 999
    end
  end

  describe "bucket allocation" do
    it "grows buckets automatically" do
      vec = Nucleoc::BoxcarVector(Int32).new(initial_capacity: 10)
      # Should allocate first bucket (size 32)
      40.times { |i| vec.push(i) }

      vec.size.should eq 40
      vec.get(0).should eq 0
      vec.get(31).should eq 31
      vec.get(32).should eq 32
      vec.get(39).should eq 39
    end

    it "handles large number of elements" do
      vec = Nucleoc::BoxcarVector(Int32).new
      count = 10_000

      count.times { |i| vec.push(i) }
      vec.size.should eq count

      # Random sampling
      vec.get(0).should eq 0
      vec.get(999).should eq 999
      vec.get(5000).should eq 5000
      vec.get(9999).should eq 9999
      vec.get(10000).should be_nil
    end
  end

  describe "parallel operations" do
    it "pushes from multiple fibers concurrently" do
      vec = Nucleoc::BoxcarVector(Int32).new
      fiber_count = 10
      pushes_per_fiber = 100

      # Use CML.spawn for concurrent pushes
      completion_channel = CML::Chan(Nil).new

      fiber_count.times do |i|
        CML.spawn do
          pushes_per_fiber.times do |j|
            vec.push(i * 1000 + j)
          end
          completion_channel.send(nil)
        end
      end

      # Wait for all fibers to complete
      fiber_count.times { completion_channel.recv }

      # All values should be stored (order not guaranteed)
      vec.size.should eq fiber_count * pushes_per_fiber

      # Verify we can retrieve all values
      count = 0
      vec.snapshot.each do |value|
        value.should be >= 0
        value.should be < fiber_count * 1000 + pushes_per_fiber
        count += 1
      end
      count.should eq vec.size
    end

    it "uses push_all with CML.spawn for large batches" do
      vec = Nucleoc::BoxcarVector(Int32).new
      values = Array.new(1000) { |i| i }

      vec.push_all(values)
      vec.size.should eq 1000

      # All values should be present (order preserved due to sequential indices)
      snapshot = vec.snapshot
      snapshot.to_a.should eq values
    end

    it "supports parallel snapshot processing" do
      vec = Nucleoc::BoxcarVector(Int32).new
      1000.times { |i| vec.push(i) }

      # Use parallel snapshot to sum values
      sum = Atomic(Int32).new(0)
      vec.par_snapshot.each_parallel do |value|
        sum.add(value)
      end

      expected_sum = (0...1000).sum
      sum.get.should eq expected_sum
    end
  end

  describe "edge cases" do
    it "handles empty vector" do
      vec = Nucleoc::BoxcarVector(Int32).new
      vec.size.should eq 0
      vec.get(0).should be_nil
      vec.snapshot.to_a.should be_empty
      vec.par_snapshot.size.should eq 0
    end

    it "handles negative indices" do
      vec = Nucleoc::BoxcarVector(Int32).new
      vec.push(42)
      vec.get(-1).should be_nil
    end

    it "handles zero initial capacity" do
      vec = Nucleoc::BoxcarVector(Int32).new(initial_capacity: 0)
      vec.size.should eq 0
      vec.push(1)
      vec.size.should eq 1
    end
  end
end
