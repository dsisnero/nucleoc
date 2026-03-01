require "atomic"
require "./utf32_str"

module Nucleoc
  # Inspired by Rust's boxcar::Vec, adapted for Crystal native concurrency.
  #
  # A concurrent, append-only vector that supports parallel appends and random access.
  # Uses atomic operations for thread-safe indexing and Crystal's native spawn for parallelism.
  class Boxcar(T)
    # Default bucket size (power of two for fast division).
    BUCKET_SIZE = 256

    # Maximum number of buckets before resizing.
    MAX_BUCKETS = 1 << 20

    # Internal entry that stores both value and column data
    private struct Entry(T)
      getter value : T?
      getter matcher_columns : Array(Utf32String)?
      getter active : Bool

      def initialize(@value : T? = nil, @matcher_columns : Array(Utf32String)? = nil, @active : Bool = false)
      end

      def active? : Bool
        @active
      end

      def set(value : T, matcher_columns : Array(Utf32String))
        @value = value
        @matcher_columns = matcher_columns
        @active = true
      end
    end

    @buckets : Array(Array(Entry(T)?)?)
    @inflight : Atomic(Int64)

    # Creates a new empty Boxcar.
    def initialize
      @buckets = Array(Array(Entry(T)?)?).new(4, nil)
      @inflight = Atomic(Int64).new(0)
    end

    # Current logical size (number of elements that have been allocated).
    def size : Int64
      @inflight.get
    end

    # Append a single value with column data.
    def push(value : T, &fill_columns : T, Array(Utf32String) -> Nil) : Int64
      index = @inflight.add(1) # add returns old value, which is the index to use
      bucket_idx, position = find_bucket_and_position(index)
      ensure_bucket_allocated(bucket_idx)

      matcher_columns = Array(Utf32String).new
      fill_columns.call(value, matcher_columns)

      entry = Entry(T).new(value, matcher_columns, true)
      @buckets[bucket_idx].as(Array(Entry(T)?))[position] = entry
      index
    end

    # Append a single value without column data (for testing).
    def push(value : T) : Int64
      push(value) { |value, columns| }
    end

    # Append multiple values efficiently with column data.
    # Uses native Crystal spawn for parallel appends if beneficial.
    def push_all(values : Enumerable(T), &fill_columns : T, Array(Utf32String) -> Nil) : Nil
      # For small batches, append sequentially
      if values.size <= 32
        values.each { |v| push(v, &fill_columns) }
        return
      end

      # For larger batches, use native Crystal spawn for parallel appends
      # Reserve a contiguous range of indices first
      start_index = @inflight.add(values.size) # add returns old value

      # Process in parallel chunks and wait for completion
      chunk_size = [values.size // System.cpu_count, 32].max
      chunks = (values.size + chunk_size - 1) // chunk_size
      completion_channels = Array(Channel(Nil)).new(chunks) { Channel(Nil).new }

      values.each_slice(chunk_size).with_index do |chunk, chunk_idx|
        spawn do
          chunk_offset = start_index + chunk_idx.to_i64 * chunk_size
          chunk.each_with_index do |value, i|
            index = chunk_offset + i.to_i64
            bucket_idx, position = find_bucket_and_position(index)
            ensure_bucket_allocated(bucket_idx)

            matcher_columns = Array(Utf32String).new
            fill_columns.call(value, matcher_columns)

            entry = Entry(T).new(value, matcher_columns, true)
            @buckets[bucket_idx].as(Array(Entry(T)?))[position] = entry
          end
          completion_channels[chunk_idx].send(nil)
        end
      end

      # Wait for all chunks to complete
      completion_channels.each(&.receive)
    end

    # Append multiple values without column data (for testing).
    def push_all(values : Enumerable(T)) : Nil
      push_all(values) { |value, columns| }
    end

    # Get value at index, or nil if not yet initialized or out of bounds.
    def get(index : Int64) : T?
      return if index < 0 || index >= @inflight.get

      bucket_idx, position = find_bucket_and_position(index)
      bucket = @buckets[bucket_idx]?
      return unless bucket

      entry = bucket[position]?
      return unless entry && entry.active?

      entry.value
    end

    # Get entry at index, or nil if not yet initialized or out of bounds.
    def get_entry(index : Int64) : Entry(T)?
      return if index < 0 || index >= @inflight.get

      bucket_idx, position = find_bucket_and_position(index)
      bucket = @buckets[bucket_idx]?
      return unless bucket

      bucket[position]?
    end

    # Get value at index, raising if not found.
    def get!(index : Int64) : T
      value = get(index)
      raise IndexError.new("No value at index #{index}") unless value
      value
    end

    # Iterate over all initialized values.
    def each(& : T -> _) : Nil
      size = @inflight.get
      (0_i64...size).each do |index|
        bucket_idx, position = find_bucket_and_position(index)
        bucket = @buckets[bucket_idx]?
        next unless bucket

        entry = bucket[position]?
        next unless entry && entry.active?

        yield entry.value.not_nil!
      end
    end

    # Convert to array (skips uninitialized slots).
    def to_a : Array(T)
      result = [] of T
      each { |value| result << value }
      result
    end

    # Create an immutable snapshot of current values.
    def snapshot(start_index : Int64 = 0) : Array(T)
      return [] of T if start_index >= @inflight.get

      size = @inflight.get
      result = [] of T
      (start_index...size).each do |index|
        value = get(index)
        result << value if value
      end
      result
    end

    # Create a parallel snapshot that can be processed in parallel.
    def par_snapshot : ParSnapshot(T)
      ParSnapshot(T).new(self)
    end

    # Sort snapshot with comparator.
    def sort_snapshot(start_index : Int64 = 0, &block : T, T -> Int32) : Array(T)
      snapshot(start_index).sort(&block)
    end

    # Get top K elements from snapshot using comparator.
    # More efficient than full sort when k << n.
    # The comparator should return:
    #   negative if a < b
    #   zero if a == b
    #   positive if a > b
    # For top-k largest elements, use standard <=> comparator.
    # For top-k smallest elements, use reversed comparator.
    def top_k_snapshot(k : Int32, start_index : Int64 = 0, &block : T, T -> Int32) : Array(T)
      elements = snapshot(start_index)
      return elements if k >= elements.size

      # Use a min-heap to keep track of top k LARGEST elements
      # heap[0] is the smallest element in the heap
      heap = [] of T

      elements.each do |element|
        if heap.size < k
          heap << element
          if heap.size == k
            # Build heap: sort in min-heap order (smallest at root)
            heap.sort! { |a, b| block.call(a, b) }
          end
        else
          # Compare with smallest element in heap
          # If new element is larger than smallest in heap, replace it
          if block.call(element, heap[0]) > 0
            heap[0] = element
            # Sift down to maintain min-heap property
            i = 0
            loop do
              left = 2 * i + 1
              right = 2 * i + 2
              smallest = i

              if left < k && block.call(heap[left], heap[smallest]) < 0
                smallest = left
              end

              if right < k && block.call(heap[right], heap[smallest]) < 0
                smallest = right
              end

              break if smallest == i

              heap[i], heap[smallest] = heap[smallest], heap[i]
              i = smallest
            end
          end
        end
      end

      # Sort result in descending order (largest first)
      heap.sort! { |a, b| block.call(b, a) }
      heap
    end

    # Clear all values (resets size to zero but keeps allocated buckets).
    def clear : Nil
      @inflight.set(0)
      @buckets.each_with_index do |bucket, idx|
        next unless bucket
        bucket.fill(nil)
      end
    end

    # Process elements in parallel, applying a block to each.
    # Returns an array of results in the same order as elements.
    def parallel_map(&block : T -> U) : Array(U) forall U
      size = @inflight.get
      return [] of U if size == 0

      # For small sizes, process sequentially
      if size <= 32
        result = Array(U).new(size.to_i32, nil.as(U?))
        (0_i64...size).each do |index|
          value = get!(index)
          result[index.to_i32] = block.call(value)
        end
        return result.compact
      end

      # For larger sizes, process in parallel
      chunk_size = [size // System.cpu_count, 32].max.to_i64
      chunks = (size + chunk_size - 1) // chunk_size
      result_channels = Array(Channel(Array(U?))).new(chunks) { Channel(Array(U?)).new }

      (0...chunks).each do |chunk_idx|
        spawn do
          chunk_start = chunk_idx.to_i64 * chunk_size
          chunk_end = Math.min(chunk_start + chunk_size, size) - 1
          chunk_result = Array(U?).new((chunk_end - chunk_start + 1).to_i32, nil)

          (chunk_start..chunk_end).each do |index|
            value = get!(index)
            chunk_result[(index - chunk_start).to_i32] = block.call(value)
          end

          result_channels[chunk_idx].send(chunk_result)
        end
      end

      # Collect results
      result = Array(U?).new(size.to_i32, nil)
      result_channels.each_with_index do |channel, chunk_idx|
        chunk_start = chunk_idx.to_i64 * chunk_size
        chunk_result = channel.receive
        chunk_result.each_with_index do |value, i|
          result[(chunk_start + i.to_i64).to_i32] = value
        end
      end

      result.compact
    end

    # Process elements in parallel, applying a block to each and collecting non-nil results.
    def parallel_select_map(&block : T -> U?) : Array(U) forall U
      size = @inflight.get
      return [] of U if size == 0

      # For small sizes, process sequentially
      if size <= 32
        result = [] of U
        (0_i64...size).each do |index|
          value = get!(index)
          mapped = block.call(value)
          result << mapped if mapped
        end
        return result
      end

      # For larger sizes, process in parallel
      chunk_size = [size // System.cpu_count, 32].max.to_i64
      chunks = (size + chunk_size - 1) // chunk_size
      result_channels = Array(Channel(Array(U))).new(chunks) { Channel(Array(U)).new }

      (0...chunks).each do |chunk_idx|
        spawn do
          chunk_start = chunk_idx.to_i64 * chunk_size
          chunk_end = Math.min(chunk_start + chunk_size, size) - 1
          chunk_result = [] of U

          (chunk_start..chunk_end).each do |index|
            value = get!(index)
            mapped = block.call(value)
            chunk_result << mapped if mapped
          end

          result_channels[chunk_idx].send(chunk_result)
        end
      end

      # Collect results
      result = [] of U
      result_channels.each do |channel|
        chunk_result = channel.receive
        result.concat(chunk_result)
      end

      result
    end

    private def find_bucket_and_position(index : Int64) : {Int32, Int32}
      bucket_idx = (index // BUCKET_SIZE).to_i32
      position = (index % BUCKET_SIZE).to_i32
      {bucket_idx, position}
    end

    private def ensure_bucket_allocated(bucket_idx : Int32) : Nil
      return if bucket_idx < @buckets.size && @buckets[bucket_idx]

      # Need to resize buckets array
      if bucket_idx >= @buckets.size
        new_size = Math.pw2ceil(bucket_idx + 1)
        new_size = Math.min(new_size, MAX_BUCKETS)
        new_buckets = Array(Array(Entry(T)?)?).new(new_size, nil)
        @buckets.each_with_index { |bucket, i| new_buckets[i] = bucket }
        @buckets = new_buckets
      end

      # Allocate the bucket if not already allocated
      unless @buckets[bucket_idx]
        @buckets[bucket_idx] = Array(Entry(T)?).new(BUCKET_SIZE, nil)
      end
    end
  end

  # Parallel snapshot for processing Boxcar elements in parallel.
  class ParSnapshot(T)
    @boxcar : Boxcar(T)
    @size : Int64

    def initialize(@boxcar : Boxcar(T))
      @size = @boxcar.size
    end

    # Number of elements in snapshot.
    def size : Int64
      @size
    end

    # Iterate over elements in parallel.
    def each_parallel(&block : T -> _) : Nil
      return if @size == 0

      # For small sizes, process sequentially
      if @size <= 32
        @boxcar.each(&block)
        return
      end

      # For larger sizes, process in parallel
      chunk_size = [@size // System.cpu_count, 32].max.to_i64
      chunks = (@size + chunk_size - 1) // chunk_size
      completion_channels = Array(Channel(Nil)).new(chunks) { Channel(Nil).new }

      (0...chunks).each do |chunk_idx|
        spawn do
          chunk_start = chunk_idx.to_i64 * chunk_size
          chunk_end = Math.min(chunk_start + chunk_size, @size) - 1

          (chunk_start..chunk_end).each do |index|
            value = @boxcar.get!(index)
            block.call(value)
          end

          completion_channels[chunk_idx].send(nil)
        end
      end

      # Wait for all chunks to complete
      completion_channels.each(&.receive)
    end

    # Convert to array.
    def to_a : Array(T)
      @boxcar.snapshot
    end
  end
end
