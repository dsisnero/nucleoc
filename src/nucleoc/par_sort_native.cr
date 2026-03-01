module Nucleoc
  module ParSort
    # Flag that can be checked to cancel a parallel sort.
    alias CancelFlag = Atomic(Bool)

    # Error raised when a parallel sort is canceled.
    class CancellationError < Exception
    end

    # Sorts `array` in parallel using a hybrid algorithm.
    #
    # The algorithm is a parallel quicksort that switches to insertion sort for small
    # partitions and uses a work-stealing approach for load balancing.
    #
    # * `is_less` should return `true` if its first argument is strictly less than its second.
    # * `canceled` is an atomic flag that can be set to `true` to cancel the sort.
    #   If canceled, a `CancellationError` is raised in worker fibers.
    #
    # Returns `true` if the sort was canceled, `false` otherwise.
    def self.sort(
      array : Array(T),
      is_less : T, T -> Bool = ->(a : T, b : T) { a < b },
      canceled : CancelFlag? = nil,
    ) : Bool forall T
      return false if array.size <= 1

      cancel_flag = canceled || Atomic(Bool).new(false)
      limit = depth_limit(array.size)

      begin
        recurse(array, 0, array.size - 1, is_less, array[0], limit, cancel_flag)
      rescue CancellationError
        true
      end
    end

    # Maximum recursion depth before switching to sequential sort.
    private def self.depth_limit(n : Int) : Int32
      # 2 * log2(n) as a reasonable limit
      return 0 if n <= 1
      (Math.log2(n.to_f64) * 2).to_i32
    end

    # Recursive parallel quicksort implementation.
    private def self.recurse(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      is_less : T, T -> Bool,
      pred : T,
      limit : Int32,
      canceled : CancelFlag,
    ) : Bool forall T
      raise CancellationError.new if canceled.get
      return false if start >= end_idx

      # Switch to insertion sort for small partitions.
      if end_idx - start < 16
        insertion_sort(array, start, end_idx, is_less, canceled)
        return false
      end

      # Switch to sequential sort if recursion depth limit reached.
      if limit <= 0
        sequential_sort(array, start, end_idx, is_less, canceled)
        return false
      end

      # Choose pivot using median-of-three.
      mid = start + (end_idx - start) // 2
      pivot_idx = median_of_three(array, start, mid, end_idx, is_less, canceled)
      raise CancellationError.new if canceled.get

      # Partition around pivot.
      pivot_value = array[pivot_idx]
      left_end = partition(array, start, end_idx, pivot_idx, is_less, canceled)
      raise CancellationError.new if canceled.get

      left_start = start
      right_start = left_end + 1
      right_end = end_idx

      # Check if partitions are balanced enough for parallel sort.
      left_size = left_end - left_start + 1
      right_size = right_end - right_start + 1
      total_size = end_idx - start + 1

      # If one partition is too small, sort it sequentially and continue with the other.
      if left_size < total_size // 8 || right_size < total_size // 8
        if left_size > 0
          result = recurse(array, left_start, left_end, is_less, pred, limit - 1, canceled)
          return true if result
        end
        # Sort right partition recursively
        recurse(array, right_start, right_end, is_less, pivot_value, limit - 1, canceled)
      else
        # Sort left and right halves in parallel using native Crystal spawn.
        left_done = Channel(Bool).new
        right_done = Channel(Bool).new

        # Spawn left partition fiber.
        spawn do
          result = begin
            recurse(array, left_start, left_end, is_less, pred, limit - 1, canceled)
          rescue CancellationError
            true
          end
          left_done.send(result)
        end

        # Spawn right partition fiber.
        spawn do
          result = begin
            recurse(array, right_start, right_end, is_less, pivot_value, limit - 1, canceled)
          rescue CancellationError
            true
          end
          right_done.send(result)
        end

        # Wait for both fibers to complete (or exit early if canceled).
        left_result = left_done.receive
        right_result = right_done.receive

        left_result || right_result
      end
    end

    # Sequential quicksort implementation.
    private def self.sequential_sort(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      is_less : T, T -> Bool,
      canceled : CancelFlag,
    ) : Nil forall T
      raise CancellationError.new if canceled.get
      return if start >= end_idx

      # Use stack to avoid recursion.
      stack = [] of Tuple(Int32, Int32)
      stack.push({start, end_idx})

      while !stack.empty?
        raise CancellationError.new if canceled.get

        lo, hi = stack.pop
        next if lo >= hi

        # Switch to insertion sort for small partitions.
        if hi - lo < 16
          insertion_sort(array, lo, hi, is_less, canceled)
          next
        end

        # Choose pivot using median-of-three.
        mid = lo + (hi - lo) // 2
        pivot_idx = median_of_three(array, lo, mid, hi, is_less, canceled)
        raise CancellationError.new if canceled.get

        # Partition.
        pivot_value = array[pivot_idx]
        left_end = partition(array, lo, hi, pivot_idx, is_less, canceled)
        raise CancellationError.new if canceled.get

        left_start = lo
        right_start = left_end + 1
        right_end = hi

        # Push larger partition first to limit stack depth.
        left_size = left_end - left_start + 1
        right_size = right_end - right_start + 1

        if left_size > right_size
          stack.push({left_start, left_end})
          stack.push({right_start, right_end})
        else
          stack.push({right_start, right_end})
          stack.push({left_start, left_end})
        end
      end
    end

    # Insertion sort for small partitions.
    private def self.insertion_sort(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      is_less : T, T -> Bool,
      canceled : CancelFlag,
    ) : Nil forall T
      raise CancellationError.new if canceled.get

      (start + 1..end_idx).each do |i|
        raise CancellationError.new if canceled.get

        key = array[i]
        j = i - 1

        while j >= start && is_less.call(key, array[j])
          raise CancellationError.new if canceled.get
          array[j + 1] = array[j]
          j -= 1
        end

        array[j + 1] = key
      end
    end

    # Chooses median of three elements as pivot.
    private def self.median_of_three(
      array : Array(T),
      a : Int32,
      b : Int32,
      c : Int32,
      is_less : T, T -> Bool,
      canceled : CancelFlag,
    ) : Int32 forall T
      raise CancellationError.new if canceled.get

      x = array[a]
      y = array[b]
      z = array[c]

      # Sort the three elements.
      if is_less.call(x, y)
        if is_less.call(y, z)
          b # x < y < z
        elsif is_less.call(x, z)
          c # x < z <= y
        else
          a # z <= x < y
        end
      else
        if is_less.call(x, z)
          a # y <= x < z
        elsif is_less.call(y, z)
          c # y < z <= x
        else
          b # z <= y <= x
        end
      end
    end

    # Partitions array around pivot.
    private def self.partition(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      pivot_idx : Int32,
      is_less : T, T -> Bool,
      canceled : CancelFlag,
    ) : Int32 forall T
      return start if canceled.get

      array.swap(start, pivot_idx)
      pivot = array[start]

      left = start + 1
      right = end_idx

      while left <= right
        return start if canceled.get

        while left <= right && is_less.call(array[left], pivot)
          left += 1
          return start if canceled.get
        end

        while left <= right && !is_less.call(array[right], pivot)
          right -= 1
          return start if canceled.get
        end

        if left < right
          array.swap(left, right)
          left += 1
          right -= 1
        end
      end

      # Place pivot in final position.
      array.swap(start, right)
      right
    end

    # Partition into elements equal to pivot followed by elements greater than pivot.
    # Assumes there are no elements smaller than the pivot in the slice.
    private def self.partition_equal(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      pivot_idx : Int32,
      is_less : T, T -> Bool,
      canceled : CancelFlag,
    ) : Int32 forall T
      raise CancellationError.new if canceled.get

      array.swap(start, pivot_idx)
      pivot = array[start]

      left = start + 1
      right = end_idx

      while left <= right
        raise CancellationError.new if canceled.get

        if is_less.call(array[left], pivot)
          # Should not happen - all elements should be >= pivot.
          left += 1
        elsif !is_less.call(pivot, array[left])
          # Equal to pivot.
          left += 1
        else
          # Greater than pivot.
          array.swap(left, right)
          right -= 1
        end
      end

      # Place pivot in final position.
      array.swap(start, right)
      right
    end
  end
end
