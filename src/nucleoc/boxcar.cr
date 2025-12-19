require "cml"

module Nucleoc
  # Lock-free, append-only vector for parallel processing.
  # Inspired by Rust's boxcar::Vec, adapted for Crystal CML.
  class BoxcarVector(T)
    # Bucket sizes grow exponentially: 32, 64, 128, ...
    private BUCKET_SIZES = [32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432, 67108864, 134217728, 268435456, 536870912, 1073741824]

    @inflight : Atomic(Int64)
    @buckets : Array(Array(T?)?)
    @bucket_mutexes : Array(Mutex)

    # Create a new BoxcarVector with initial capacity.
    def initialize(initial_capacity : Int32 = 32)
      @inflight = Atomic(Int64).new(0)
      @buckets = Array(Array(T?)?).new(BUCKET_SIZES.size, nil)
      @bucket_mutexes = Array(Mutex).new(BUCKET_SIZES.size) { Mutex.new }

      # Pre-allocate first bucket
      if initial_capacity > 0
        bucket_idx = find_bucket_for_capacity(initial_capacity)
        bucket_idx.times do |i|
          allocate_bucket(i)
        end
      end
    end

    # Append a value to the vector, returning its index.
    # This method is thread-safe and lock-free for the common case.
    def push(value : T) : Int64
      # Get unique index with atomic increment
      index = @inflight.add(1)

      # Find bucket and position
      bucket_idx, position = find_bucket_and_position(index)

      # Ensure bucket exists
      ensure_bucket_allocated(bucket_idx)

      # Store value (thread-safe due to unique index)
      bucket = @buckets[bucket_idx]
      if bucket.nil?
        raise "Bucket #{bucket_idx} not allocated for index #{index}"
      end
      bucket[position] = value

      index
    end

    # Append multiple values efficiently.
    # Uses CML.spawn for parallel appends if beneficial.
    def push_all(values : Enumerable(T)) : Nil
      # For small batches, append sequentially
      if values.size <= 32
        values.each { |v| push(v) }
        return
      end

      # For larger batches, use CML.spawn for parallel appends
      # Reserve a contiguous range of indices first
      start_index = @inflight.add(values.size)

      # Process in parallel chunks and wait for completion
      chunk_size = [values.size // System.cpu_count, 32].max
      chunks = (values.size + chunk_size - 1) // chunk_size
      completion_channels = Array(CML::Chan(Nil)).new(chunks) { CML::Chan(Nil).new }

      values.each_slice(chunk_size).with_index do |chunk, chunk_idx|
        CML.spawn do
          chunk_offset = start_index + chunk_idx.to_i64 * chunk_size
          chunk.each_with_index do |value, i|
            index = chunk_offset + i.to_i64
            bucket_idx, position = find_bucket_and_position(index)
            ensure_bucket_allocated(bucket_idx)
            @buckets[bucket_idx].as(Array(T?))[position] = value
          end
          completion_channels[chunk_idx].send(nil)
        end
      end

      # Wait for all chunks to complete
      completion_channels.each(&.recv)
    end

    # Get value at index, or nil if not yet initialized or out of bounds.
    def get(index : Int64) : T?
      return if index < 0 || index >= @inflight.get

      bucket_idx, position = find_bucket_and_position(index)
      bucket = @buckets[bucket_idx]?
      return unless bucket

      bucket[position]?
    end

    # Get value at index, raising if not found.
    def get!(index : Int64) : T
      get(index) || raise IndexError.new("No value at index #{index}")
    end

    # Current size (number of elements appended).
    def size : Int64
      @inflight.get
    end

    # Create an immutable snapshot iterator.
    # The iterator will not see new elements added after creation.
    def snapshot(start_index : Int64 = 0) : Snapshot(T)
      Snapshot(T).new(self, start_index)
    end

    # Create a parallel snapshot for concurrent processing.
    def par_snapshot(start_index : Int64 = 0) : ParSnapshot(T)
      ParSnapshot(T).new(self, start_index)
    end

    # Clear all elements (for reuse).
    # Note: This is not thread-safe during concurrent access.
    def clear
      @inflight.set(0)
      @buckets.each_with_index do |bucket, i|
        if bucket
          bucket.fill(nil)
          # Don't deallocate, just clear for reuse
        end
      end
    end

    # Debug method: check if bucket is allocated
    def bucket_allocated?(bucket_idx : Int32) : Bool
      !@buckets[bucket_idx]?.nil?
    end

    private def find_bucket_for_capacity(capacity : Int32) : Int32
      BUCKET_SIZES.each_with_index do |size, idx|
        return idx if capacity <= size
      end
      BUCKET_SIZES.size - 1
    end

    private def find_bucket_and_position(index : Int64) : {Int32, Int32}
      remaining = index
      BUCKET_SIZES.each_with_index do |size, idx|
        if remaining < size
          return {idx, remaining.to_i32}
        end
        remaining -= size
      end
      # Should never reach here if capacity is managed correctly
      raise "Index #{index} exceeds maximum capacity"
    end

    private def ensure_bucket_allocated(bucket_idx : Int32)
      # Fast path: bucket already allocated
      return if @buckets[bucket_idx]?

      # Slow path: allocate with mutex protection
      @bucket_mutexes[bucket_idx].synchronize do
        # Double-check after acquiring lock
        unless @buckets[bucket_idx]?
          @buckets[bucket_idx] = Array(T?).new(BUCKET_SIZES[bucket_idx], nil)
        end
      end
    end

    private def allocate_bucket(bucket_idx : Int32)
      @bucket_mutexes[bucket_idx].synchronize do
        unless @buckets[bucket_idx]?
          @buckets[bucket_idx] = Array(T?).new(BUCKET_SIZES[bucket_idx], nil)
        end
      end
    end

    # Immutable snapshot iterator
    class Snapshot(T)
      @vector : BoxcarVector(T)
      @start_index : Int64
      @current_index : Int64
      @end_index : Int64

      def initialize(@vector : BoxcarVector(T), start_index : Int64)
        @start_index = start_index.clamp(0, @vector.size).to_i64
        @current_index = @start_index
        @end_index = @vector.size
      end

      def each(& : T -> _) : Nil
        while @current_index < @end_index
          value = @vector.get(@current_index)
          if value
            yield value
          end
          @current_index += 1
        end
      end

      def to_a : Array(T)
        result = [] of T
        each { |v| result << v }
        result
      end

      def size : Int64
        @end_index - @start_index
      end
    end

    # Parallel snapshot for concurrent processing
    class ParSnapshot(T)
      @vector : BoxcarVector(T)
      @start_index : Int64
      @end_index : Int64

      def initialize(@vector : BoxcarVector(T), start_index : Int64)
        @start_index = start_index.clamp(0, @vector.size).to_i64
        @end_index = @vector.size
      end

      # Process elements in parallel using CML.spawn
      def each_parallel(&block : T -> _) : Nil
        chunk_size = [size // System.cpu_count, 32_i64].max
        chunks = (@end_index - @start_index + chunk_size - 1) // chunk_size

        channels = Array(CML::Chan(Nil)).new(chunks) { CML::Chan(Nil).new }

        chunks.times do |chunk_idx|
          chunk_start = @start_index + chunk_idx * chunk_size
          chunk_end = Math.min(chunk_start + chunk_size, @end_index)
          channel = channels[chunk_idx]

          CML.spawn do
            (chunk_start...chunk_end).each do |index|
              value = @vector.get(index)
              if value
                block.call(value)
              end
            end
            channel.send(nil)
          end
        end

        # Wait for all chunks to complete
        channels.each(&.recv)
      end

      def size : Int64
        @end_index - @start_index
      end
    end
  end
end
