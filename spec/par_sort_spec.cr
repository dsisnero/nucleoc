require "./spec_helper"
require "../src/nucleoc/par_sort"

module Nucleoc
  describe ParSort do
    it "sorts empty array" do
      canceled = Atomic(Bool).new(false)
      array = [] of Int32
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [] of Int32
    end

    it "sorts single element array" do
      canceled = Atomic(Bool).new(false)
      array = [42]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [42]
    end

    it "sorts small sorted array" do
      canceled = Atomic(Bool).new(false)
      array = [1, 2, 3, 4, 5]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [1, 2, 3, 4, 5]
    end

    it "sorts small reverse array" do
      canceled = Atomic(Bool).new(false)
      array = [5, 4, 3, 2, 1]
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq [1, 2, 3, 4, 5]
    end

    it "sorts random array of size 10" do
      100.times do
        array = Array.new(10) { rand(1000) }
        expected = array.sort
        canceled = Atomic(Bool).new(false)
        ParSort.par_quicksort(array, canceled) { |a, b| a < b }
        array.should eq expected
      end
    end

    it "sorts random array of size 100" do
      20.times do
        array = Array.new(100) { rand(1000) }
        expected = array.sort
        canceled = Atomic(Bool).new(false)
        ParSort.par_quicksort(array, canceled) { |a, b| a < b }
        array.should eq expected
      end
    end

    it "sorts random array of size 1000 (sequential)" do
      5.times do
        array = Array.new(1000) { rand(10000) }
        expected = array.sort
        canceled = Atomic(Bool).new(false)
        ParSort.par_quicksort(array, canceled) { |a, b| a < b }
        array.should eq expected
      end
    end

    it "handles cancellation before sorting" do
      array = [5, 3, 1, 4, 2]
      canceled = Atomic(Bool).new(true)
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_true
      # array may be partially sorted, but we don't care
    end

    it "handles cancellation during sorting (large array)" do
      array = Array.new(5000) { rand(10000) }
      canceled = Atomic(Bool).new(false)
      # We can't easily test cancellation mid-sort without injecting a hook.
      # For now, just ensure it doesn't crash.
      result = ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      result.should be_false
      array.should eq array.sort
    end

    # Test parallel sorting with size > MAX_SEQUENTIAL (2000)
    # Note: MAX_SEQUENTIAL may be changed; we assume default 2000.
    it "sorts large array in parallel" do
      array = Array.new(10000) { rand(100000) }
      expected = array.sort
      canceled = Atomic(Bool).new(false)
      ParSort.par_quicksort(array, canceled) { |a, b| a < b }
      array.should eq expected
    end
  end
end
