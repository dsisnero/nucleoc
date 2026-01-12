require "cml"
require "atomic"

module Nucleoc
  # Parallel quicksort with cancellation support using CML.spawn.
  # Port of Rust's pattern-defeating quicksort algorithm.
  module ParSort
    class CancellationError < Exception
    end

    class CancelFlag
      def initialize(initial : Bool = false)
        @flag = Atomic(Bool).new(initial)
      end

      def get : Bool
        @flag.get
      end

      def set(value : Bool) : Nil
        @flag.set(value)
      end
    end
    # Debug logging
    DEBUG = false

    private def self.debug_puts(msg)
      puts msg if DEBUG
    end

    # Maximum size for insertion sort
    private MAX_INSERTION = 20

    # If both partitions are up to this length, we continue sequentially.
    private MAX_SEQUENTIAL = 2000

    # Minimum length to choose the median-of-medians method.
    private SHORTEST_MEDIAN_OF_MEDIANS = 50

    # Maximum number of swaps in pivot selection.
    private MAX_SWAPS = 4 * 3

    # Limit the number of imbalanced partitions before switching to heapsort.
    private def self.limit_for_len(len : Int32) : UInt32
      len.bit_length.to_u32
    end

    # Sorts `array` using parallel quicksort.
    # Returns `true` if sorting was canceled.
    def self.par_quicksort(array : Array(T), &is_less : T, T -> Bool) : Bool forall T
      canceled = CancelFlag.new(false)
      par_quicksort(array, canceled, &is_less)
    end

    # Sorts `array` using parallel quicksort with external cancellation flag.
    # Returns `true` if sorting was canceled.
    def self.par_quicksort(array : Array(T), canceled : CancelFlag, &is_less : T, T -> Bool) : Bool forall T
      return true if canceled.get
      return false if array.size <= 1
      limit = limit_for_len(array.size)
      guarded_is_less = ->(left : T, right : T) do
        raise CancellationError.new if canceled.get
        is_less.call(left, right)
      end

      begin
        recurse(array, 0, array.size, guarded_is_less, nil, limit, canceled)
      rescue CancellationError
        true
      end
    end

    # Recursive sorting function.
    private def self.recurse(
      array : Array(T),
      start : Int32,
      end_idx : Int32, # exclusive
      is_less : T, T -> Bool,
      pred : T?,
      limit : UInt32,
      canceled : CancelFlag,
    ) : Bool forall T
      # Rust uses loop with tail recursion optimization
      cur_start = start
      cur_end = end_idx
      cur_pred = pred
      cur_limit = limit
      was_balanced = true
      was_partitioned = true

      loop do
        len = cur_end - cur_start
        debug_puts "recurse loop start=#{cur_start} end=#{cur_end} len=#{len} pred=#{cur_pred.inspect} limit=#{cur_limit}"

        # Check for cancellation.
        return true if canceled.get

        # Very short slices get sorted using insertion sort.
        if len <= MAX_INSERTION
          return insertion_sort(array, cur_start, cur_end, is_less, canceled)
        end

        # If too many bad pivot choices were made, fall back to heapsort.
        if cur_limit == 0
          return heapsort(array, cur_start, cur_end, is_less, canceled)
        end

        # If the last partitioning was imbalanced, try breaking patterns.
        if !was_balanced
          break_patterns(array, cur_start, cur_end)
          cur_limit -= 1
        end

        # Choose a pivot and guess if slice is already sorted.
        pivot_idx, likely_sorted = choose_pivot(array, cur_start, cur_end, is_less)

        # If slice was already partitioned and likely sorted, try partial insertion sort.
        if was_balanced && was_partitioned && likely_sorted && false
          if partial_insertion_sort(array, cur_start, cur_end, is_less)
            return false
          end
        end

        # Handle equal elements case (pred predecessor).
        if cur_pred && !is_less.call(cur_pred.as(T), array[pivot_idx])
          # All elements equal to pivot; skip sorting them.
          mid = partition_equal(array, cur_start, cur_end, pivot_idx, is_less, canceled)
          return true if canceled.get
          cur_start = mid
          was_balanced = true
          was_partitioned = true
          next
        end

        # Partition the slice.
        mid, was_partitioned = partition(array, cur_start, cur_end, pivot_idx, is_less, canceled)
        return true if canceled.get
        debug_puts "  pivot_idx=#{pivot_idx} mid=#{mid} was_partitioned=#{was_partitioned}"
        was_balanced = Math.min(mid - cur_start, cur_end - mid) >= len // 8

        # Split into left and right partitions.
        left_start = cur_start
        left_end = mid
        right_start = mid + 1
        right_end = cur_end
        pivot_value = array[mid]?

        left_len = left_end - left_start
        right_len = right_end - right_start

        # Determine if we should sort sequentially or in parallel.
        if Math.max(left_len, right_len) <= MAX_SEQUENTIAL
          # Recurse into the shorter side first (tail recursion optimization).
          if left_len < right_len
            # Sort left partition recursively
            if recurse(array, left_start, left_end, is_less, cur_pred, cur_limit, canceled)
              return true
            end
            # Continue with right partition in next loop iteration
            cur_start = right_start
            cur_end = right_end
            cur_pred = pivot_value
            was_balanced = true
            was_partitioned = true
            next
          else
            # Sort right partition recursively
            if recurse(array, right_start, right_end, is_less, pivot_value, cur_limit, canceled)
              return true
            end
            # Continue with left partition in next loop iteration
            cur_start = left_start
            cur_end = left_end
            # cur_pred stays the same for left partition
            was_balanced = true
            was_partitioned = true
            next
          end
        else
          # Sort left and right halves in parallel using CML.spawn.
          left_channel = CML::Mailbox(Bool).new
          right_channel = CML::Mailbox(Bool).new

          # Spawn left partition fiber.
          CML.spawn do
            result = begin
              recurse(array, left_start, left_end, is_less, cur_pred, cur_limit, canceled)
            rescue CancellationError
              true
            end
            left_channel.send(result)
          end

          # Spawn right partition fiber.
          CML.spawn do
            result = begin
              recurse(array, right_start, right_end, is_less, pivot_value, cur_limit, canceled)
            rescue CancellationError
              true
            end
            right_channel.send(result)
          end

          # Wait for both fibers to complete (or exit early if canceled).
          left_done = false
          right_done = false
          left_result = false
          right_result = false

          until left_done && right_done
            return true if canceled.get

            events = [] of CML::Event(Tuple(Symbol, Bool) | Symbol)
            unless left_done
              left_evt = CML.wrap(left_channel.recv_evt) do |value|
                {:left, value}.as(Tuple(Symbol, Bool) | Symbol)
              end
              events << left_evt
            end
            unless right_done
              right_evt = CML.wrap(right_channel.recv_evt) do |value|
                {:right, value}.as(Tuple(Symbol, Bool) | Symbol)
              end
              events << right_evt
            end

            timeout_evt = CML.wrap(CML.timeout(20.milliseconds)) do
              :timeout.as(Tuple(Symbol, Bool) | Symbol)
            end
            events << timeout_evt

            result = CML.sync(CML.choose(events))

            case result
            when Tuple(Symbol, Bool)
              case result[0]
              when :left
                left_result = result[1]
                left_done = true
              when :right
                right_result = result[1]
                right_done = true
              end
            when :timeout
              next
            else
              return true
            end
          end

          return left_result || right_result
        end
      end
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
      return start if canceled.get

      array.swap(start, pivot_idx)
      pivot = array[start]

      left = start + 1
      right = end_idx

      loop do
        return left if canceled.get

        while left < right && !is_less.call(pivot, array[left])
          left += 1
        end

        while left < right && is_less.call(pivot, array[right - 1])
          right -= 1
        end

        break if left >= right

        right -= 1
        array.swap(left, right)
        left += 1
      end

      left
    end

    # Simple insertion sort for small slices.
    private def self.insertion_sort(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      is_less : T, T -> Bool,
      canceled : CancelFlag,
    ) : Bool forall T
      ((start + 1)...end_idx).each do |i|
        return true if canceled.get
        j = i
        while j > start && is_less.call(array[j], array[j - 1])
          array.swap(j, j - 1)
          j -= 1
        end
      end
      false
    end

    # Chooses a pivot and returns (pivot_index, likely_sorted).
    def self.choose_pivot(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      is_less : T, T -> Bool,
    ) : {Int32, Bool} forall T
      len = end_idx - start
      debug_puts "choose_pivot start=#{start} end=#{end_idx} len=#{len}"

      # Three indices near which we choose a pivot (local indices).
      a = len // 4
      b = len // 2
      c = len * 3 // 4

      swaps = 0

      if len >= 8
        # Swaps indices so that array[start + a] <= array[start + b]
        sort2 = ->(i : Int32, j : Int32) do
          if is_less.call(array[start + j], array[start + i])
            swaps += 1
            {j, i}
          else
            {i, j}
          end
        end

        # Swaps indices so that array[start + a] <= array[start + b] <= array[start + c]
        sort3 = ->(i : Int32, j : Int32, k : Int32) do
          i, j = sort2.call(i, j)
          j, k = sort2.call(j, k)
          i, j = sort2.call(i, j)
          {i, j, k}
        end

        if len >= SHORTEST_MEDIAN_OF_MEDIANS
          # Find medians in neighborhoods of a, b, c
          sort_adjacent = ->(idx : Int32) do
            # idx is local index; neighborhood indices are valid because len >= 50
            _, median, _ = sort3.call(idx - 1, idx, idx + 1)
            median
          end
          a = sort_adjacent.call(a)
          b = sort_adjacent.call(b)
          c = sort_adjacent.call(c)
        end

        # Find median among a, b, c
        a, b, c = sort3.call(a, b, c)
        debug_puts "  after sort3: a=#{a} b=#{b} c=#{c} values: #{array[start + a]}, #{array[start + b]}, #{array[start + c]}"
      end

      if swaps < MAX_SWAPS
        pivot_local = b
        pivot_global = start + pivot_local
        debug_puts "  chosen pivot index #{pivot_global} value #{array[pivot_global]} swaps=#{swaps}"
        {pivot_global, swaps == 0}
      else
        # Too many swaps indicates slice is descending; reverse it.
        debug_puts "  too many swaps (#{swaps}), reversing slice"
        (0...len).each do |i|
          break if i >= len - 1 - i
          array.swap(start + i, start + len - 1 - i)
        end
        pivot_local = len - 1 - b
        pivot_global = start + pivot_local
        debug_puts "  chosen pivot after reverse index #{pivot_global} value #{array[pivot_global]}"
        {pivot_global, true}
      end
    end

    # Partition scheme (Lomuto variant).
    def self.partition(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      pivot_idx : Int32,
      is_less : T, T -> Bool,
      canceled : CancelFlag,
    ) : {Int32, Bool} forall T
      debug_puts "  partition start=#{start} end=#{end_idx} pivot_idx=#{pivot_idx} pivot_value=#{array[pivot_idx]}"
      debug_puts "  slice before: #{array[start...end_idx]}"
      return {start, false} if canceled.get
      # Move pivot to the start
      array.swap(start, pivot_idx)
      pivot = array[start]
      debug_puts "  after pivot swap: #{array[start...end_idx]}"

      # Index where elements < pivot end
      store_idx = start + 1
      was_partitioned = true

      (start + 1...end_idx).each do |i|
        break if canceled.get
        if is_less.call(array[i], pivot)
          debug_puts "    i=#{i} value=#{array[i]} < pivot #{pivot}, swapping with store_idx=#{store_idx}"
          array.swap(i, store_idx)
          store_idx += 1
          debug_puts "    after swap: #{array[start...end_idx]}"
        else
          debug_puts "    i=#{i} value=#{array[i]} >= pivot #{pivot}, no swap"
          was_partitioned = false
        end
      end

      # Move pivot to its final place
      pivot_pos = store_idx - 1
      array.swap(start, pivot_pos)
      debug_puts "  partition result: pivot_pos=#{pivot_pos} was_partitioned=#{was_partitioned}"
      debug_puts "  slice after: #{array[start...end_idx]}"

      {pivot_pos, was_partitioned}
    end

    # Heapsort for worst-case guarantee.
    private def self.heapsort(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      is_less : T, T -> Bool,
      canceled : CancelFlag,
    ) : Bool forall T
      len = end_idx - start
      return false if len <= 1

      # Build max heap
      (len // 2 - 1).downto(0) do |i|
        return true if canceled.get
        return true if sift_down(array, start, end_idx, i, is_less, canceled)
      end

      # Extract elements from heap
      (len - 1).downto(1) do |i|
        return true if canceled.get
        array.swap(start, start + i)
        return true if sift_down(array, start, start + i, 0, is_less, canceled)
      end
      false
    end

    private def self.sift_down(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      root : Int32,
      is_less : T, T -> Bool,
      canceled : CancelFlag,
    ) : Bool forall T
      len = end_idx - start
      while (child = 2 * root + 1) < len
        return true if canceled.get
        # Find larger child
        if child + 1 < len && is_less.call(array[start + child], array[start + child + 1])
          child += 1
        end

        # Stop if heap property satisfied
        break unless is_less.call(array[start + root], array[start + child])

        array.swap(start + root, start + child)
        root = child
      end
      false
    end

    # Break patterns to avoid worst-case behavior.
    private def self.break_patterns(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
    ) forall T
      len = end_idx - start
      return if len < 8

      debug_puts "  break_patterns start=#{start} end=#{end_idx} len=#{len}"

      # Simple pseudo-random shuffling of three elements
      seed = len
      gen = -> { seed = (seed ^ (seed << 13)) ^ (seed >> 17) ^ (seed << 5); seed }

      pos = start + len // 2
      3.times do |i|
        other = gen.call.abs % len
        debug_puts "    swapping #{pos - 1 + i} with #{start + other} (values #{array[pos - 1 + i]} <-> #{array[start + other]})"
        array.swap(pos - 1 + i, start + other)
      end
    end

    # Partial insertion sort for nearly sorted slices.
    private def self.partial_insertion_sort(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      is_less : T, T -> Bool,
    ) : Bool forall T
      len = end_idx - start
      max_steps = 5
      shortest_shifting = 50

      i = 1
      max_steps.times do
        # Find next adjacent out-of-order pair
        while i < len && !is_less.call(array[start + i], array[start + i - 1])
          i += 1
        end

        return true if i == len

        if len < shortest_shifting
          return false
        end

        array.swap(start + i - 1, start + i)
        # Simple shift (could be optimized)
        shift_tail(array, start, start + i, is_less)
        shift_head(array, start + i, end_idx, is_less)
      end

      false
    end

    private def self.shift_tail(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      is_less : T, T -> Bool,
    ) forall T
      len = end_idx - start
      return if len < 2

      i = len - 1
      while i > 0 && is_less.call(array[start + i], array[start + i - 1])
        array.swap(start + i, start + i - 1)
        i -= 1
      end
    end

    private def self.shift_head(
      array : Array(T),
      start : Int32,
      end_idx : Int32,
      is_less : T, T -> Bool,
    ) forall T
      len = end_idx - start
      return if len < 2

      i = 0
      while i < len - 1 && is_less.call(array[start + i + 1], array[start + i])
        array.swap(start + i, start + i + 1)
        i += 1
      end
    end
  end
end
