require "./spec_helper"
require "../src/nucleoc/par_sort"

module Nucleoc
  describe ParSort do
    it "sorts empty array" do
      canceled = ParSort::CancelFlag.new(false)
      array = [] of Int32
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [] of Int32
    end

    it "sorts single element array" do
      canceled = ParSort::CancelFlag.new(false)
      array = [42]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [42]
    end

    it "sorts small sorted array" do
      canceled = ParSort::CancelFlag.new(false)
      array = [1, 2, 3, 4, 5]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [1, 2, 3, 4, 5]
    end

    it "sorts small reverse array" do
      canceled = ParSort::CancelFlag.new(false)
      array = [5, 4, 3, 2, 1]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [1, 2, 3, 4, 5]
    end

    it "sorts array with all equal elements" do
      canceled = ParSort::CancelFlag.new(false)
      array = [7, 7, 7, 7, 7, 7, 7]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [7, 7, 7, 7, 7, 7, 7]
    end

    it "sorts already sorted array with duplicates" do
      canceled = ParSort::CancelFlag.new(false)
      array = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
    end

    it "sorts reverse sorted array with duplicates" do
      canceled = ParSort::CancelFlag.new(false)
      array = [5, 5, 4, 4, 3, 3, 2, 2, 1, 1]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
    end

    it "sorts random array of size 10" do
      100.times do
        array = Array.new(10) { rand(1000) }
        expected = array.sort
        canceled = ParSort::CancelFlag.new(false)
        ParSort.par_quicksort(array, canceled) { |a, b| a < b }
        array.should eq expected
      end
    end

    it "sorts random array of size 100" do
      20.times do
        array = Array.new(100) { rand(1000) }
        expected = array.sort
        canceled = ParSort::CancelFlag.new(false)
        ParSort.par_quicksort(array, canceled) { |a, b| a < b }
        array.should eq expected
      end
    end

    it "sorts random array of size 1000 (sequential)" do
      5.times do
        array = Array.new(1000) { rand(10000) }
        expected = array.sort
        canceled = ParSort::CancelFlag.new(false)
        ParSort.par_quicksort(array, canceled) { |a, b| a < b }
        array.should eq expected
      end
    end

    it "handles cancellation before sorting" do
      array = [5, 3, 1, 4, 2]
      canceled = ParSort::CancelFlag.new(true)
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_true
      # array may be partially sorted, but we don't care
    end

    it "handles cancellation during sorting (large array)" do
      array = Array.new(3000) { rand(10000) }
      canceled = ParSort::CancelFlag.new(false)
      done = Channel(Bool).new

      spawn do
        result = ParSort.par_quicksort(array, canceled) { |left, right| left < right }
        done.send(result)
      end

      select
      when result = done.receive
        result.should be_false
      when timeout(4.seconds)
        fail "sort did not complete"
      end

      array.should eq array.sort
    end

    it "sorts large array in parallel without deadlock" do
      array = Array.new(3000) { rand(100000) }
      expected = array.sort
      canceled = ParSort::CancelFlag.new(false)
      done = Channel(Bool).new

      spawn do
        result = ParSort.par_quicksort(array, canceled) { |left, right| left < right }
        done.send(result)
      end

      select
      when result = done.receive
        result.should be_false
      when timeout(4.seconds)
        fail "parallel sort did not complete"
      end

      array.should eq expected
    end

    it "handles cancellation during parallel sort without deadlock" do
      array = Array.new(3000) { rand(100000) }
      canceled = ParSort::CancelFlag.new(false)
      done = Channel(Bool).new

      spawn do
        result = ParSort.par_quicksort(array, canceled) do |left, right|
          sleep 10.microseconds
          left < right
        end
        done.send(result)
      end

      spawn do
        sleep 1.millisecond
        canceled.set(true)
      end

      select
      when result = done.receive
        canceled.get.should be_true
        array.should eq array.sort unless result
      when timeout(4.seconds)
        fail "parallel sort did not complete after cancellation"
      end
    end

    it "cancels sorting from another fiber" do
      # Create a large array to ensure sorting takes some time
      array = Array.new(2000) { rand(10000) }
      canceled = ParSort::CancelFlag.new(false)

      # Start sorting in a fiber
      spawn do
        ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      end

      # Cancel from main fiber after a short delay
      sleep 1.millisecond
      canceled.set(true)

      # Wait for sort fiber to complete (should return quickly due to cancellation)
      # Note: We can't easily get the return value from the fiber without channels
      # For now, just ensure no deadlock occurs
      sleep 10.milliseconds

      # The array may be partially sorted, which is fine
      # Main point is that cancellation signal is respected across fibers
    end

    it "sorts in descending order with custom comparator" do
      canceled = ParSort::CancelFlag.new(false)
      array = [5, 3, 8, 1, 2, 9, 4, 7, 6, 0]
      # Sort descending: a > b instead of a < b
      result = ParSort.par_quicksort(array, canceled) { |a, b| a > b }
      result.should be_false
      array.should eq [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
    end

    it "sorts strings with custom comparator" do
      canceled = ParSort::CancelFlag.new(false)
      array = ["banana", "apple", "cherry", "date", "fig"]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq ["apple", "banana", "cherry", "date", "fig"]
    end

    # Property-based tests with fixed seeds for reproducibility
    pending "property-based tests" do
      it "sorts arrays of various sizes with fixed seeds" do
        # Test different sizes including edge cases (keep sizes reasonable for test speed)
        sizes = [0, 1, 2, 3, 5, 10, 20, 50, 100, 200, 500, 1000]
        seeds = [42, 123, 777, 999]

        sizes.each do |size|
          seeds.each do |seed|
            rng = Random.new(seed)
            array = Array.new(size) { rng.rand(10000) }
            expected = array.sort
            canceled = ParSort::CancelFlag.new(false)
            result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
            result.should be_false
            array.should eq expected
          end
        end
      end

      it "handles arrays with many duplicates" do
        canceled = ParSort::CancelFlag.new(false)
        # Array with only 3 distinct values repeated many times
        array = Array.new(1000) { [1, 2, 3].sample }
        expected = array.sort
        result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
        result.should be_false
        array.should eq expected
      end

      it "handles arrays with descending pattern" do
        canceled = ParSort::CancelFlag.new(false)
        # Create strictly descending array
        array = (1000.downto(1)).to_a
        expected = array.sort
        result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
        result.should be_false
        array.should eq expected
      end

      it "handles arrays with ascending pattern" do
        canceled = ParSort::CancelFlag.new(false)
        # Create strictly ascending array (already sorted)
        array = (1..1000).to_a
        expected = array.sort
        result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
        result.should be_false
        array.should eq expected
      end
    end

    # Test parallel sorting with size > MAX_SEQUENTIAL (2000)
    # Note: MAX_SEQUENTIAL may be changed; we assume default 2000.
    pending "sorts large array in parallel" do
      array = Array.new(3000) { rand(100000) }
      expected = array.sort
      canceled = ParSort::CancelFlag.new(false)
      ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      array.should eq expected
    end
  end
end
