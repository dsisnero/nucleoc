require "cml"
require "./boxcar"
require "./error_handling"
require "./multi_pattern"

# Main API for nucleoc fuzzy matching
module Nucleoc
  @@pool_mutex = Mutex.new
  @@cml_pools = Hash({Config, Int32}, CMLWorkerPool).new
  @@fiber_pools = Hash({Config, Int32}, FiberWorkerPool).new

  struct MatchResult
    include Comparable(MatchResult)

    getter item : String
    getter data : String
    getter score : UInt16

    def initialize(@item : String, @score : UInt16)
      @data = @item
    end

    def <=>(other : self) : Int32
      other.score <=> score # descending by score
    end
  end

  class Snapshot
    getter items : Array(MatchResult)
    getter pattern : MultiPattern

    def initialize(@items : Array(MatchResult), @pattern : MultiPattern)
    end

    def size : Int32
      @items.size
    end

    def empty? : Bool
      @items.empty?
    end
  end

  class Injector(T)
    def initialize(@owner : Nucleo(T), @generation : Int32)
      @owner.register_injector(@generation)
      GC.add_finalizer(self)
    end

    def finalize
      @owner.unregister_injector(@generation)
    end

    def inject(_idx : Int32, value : String)
      @owner.enqueue(Command(T).add(value))
    end

    def extend(values : Enumerable(String))
      @owner.enqueue(Command(T).extend(values.to_a))
    end

    def clear
      @owner.enqueue(Command(T).clear)
    end
  end

  # Commands sent to worker fiber
  struct Command(T)
    enum Kind
      Add
      Extend
      Clear
      UpdatePattern
      Tick
      Restart
    end

    getter kind : Kind
    getter payload : Array(String)?
    getter pattern : MultiPattern?
    getter? clear_snapshot : Bool
    getter reply : CML::Chan(Status)?

    def self.add(item : String) : self
      new(Kind::Add, [item], nil, false, nil)
    end

    def self.extend(items : Array(String)) : self
      new(Kind::Extend, items, nil, false, nil)
    end

    def self.clear : self
      new(Kind::Clear, nil, nil, false, nil)
    end

    def self.update_pattern(pattern : MultiPattern) : self
      new(Kind::UpdatePattern, nil, pattern, false, nil)
    end

    def self.tick(reply : CML::Chan(Status)) : self
      new(Kind::Tick, nil, nil, false, reply)
    end

    def self.restart(clear_snapshot : Bool) : self
      new(Kind::Restart, nil, nil, clear_snapshot, nil)
    end

    private def initialize(@kind, @payload, @pattern, @clear_snapshot, @reply)
    end
  end

  struct Status
    getter? changed : Bool
    getter? running : Bool

    def initialize(@changed : Bool, @running : Bool)
    end
  end

  class Nucleo(T)
    getter worker_count : Int32

    @matcher : Matcher
    @pattern : MultiPattern
    @items : Array(String)
    @snapshot : Snapshot?
    @max_results : Int32?
    @active_injectors : Int32 = 0
    @baseline_injectors : Int32 = 0
    @baseline_set : Bool = false
    @mtx = Mutex.new
    @data_mtx = Mutex.new
    @mailbox : CML::Mailbox(Command(T))
    @notify : Proc(Nil)
    @generation : Int32 = 0
    @running = Atomic(Bool).new(false)
    @dirty = Atomic(Bool).new(false)
    @needs_run = Atomic(Bool).new(true)

    def initialize(config : Config = Config.new, notify : -> _ = -> { nil }, num_threads : Int32? = 1, columns : Int32 = 1, max_results : Int32? = nil)
      @matcher = Matcher.new(config)
      @pattern = MultiPattern.new(columns)
      @items = [] of String
      @snapshot = nil
      @max_results = max_results
      @worker_count = num_threads || 1
      @mailbox = CML::Mailbox(Command(T)).new
      @notify = -> { notify.call; nil }
    end

    # Rust constructor parity
    def initialize(config : Config, notify : Proc(Nil), num_threads : Int32?, columns : Int32, max_results : Int32? = nil)
      initialize(config, -> { notify.call }, num_threads, columns, max_results)
    end

    def register_injector(gen : Int32)
      @mtx.synchronize { @active_injectors += 1 }
    end

    def unregister_injector(gen : Int32)
      return unless gen == @generation
      @mtx.synchronize do
        @active_injectors = Math.max(@baseline_injectors, @active_injectors - 1)
      end
    end

    def active_injectors : Int32
      unless @baseline_set
        @baseline_injectors = @active_injectors
        @baseline_set = true
        return 0
      end
      val = @active_injectors - @baseline_injectors
      val < 0 ? 0 : val
    end

    def injector : Injector(T)
      Injector(T).new(self, @generation)
    end

    def restart(clear_snapshot : Bool)
      enqueue(Command(T).restart(clear_snapshot))
      @generation += 1
      @active_injectors = 0
      @baseline_injectors = 0
      @baseline_set = true
    end

    def add(item : String)
      enqueue(Command(T).add(item))
    end

    def add_all(items : Enumerable(String))
      enqueue(Command(T).extend(items.to_a))
    end

    def clear
      enqueue(Command(T).clear)
    end

    def update_config(config : Config)
      @data_mtx.synchronize do
        @matcher = Matcher.new(config)
        @snapshot = nil
        @needs_run.set(true)
      end
    end

    def max_results=(value : Int32?)
      @data_mtx.synchronize do
        @max_results = value
        @snapshot = nil
        @needs_run.set(true)
      end
    end

    def update_pattern(pattern_str : String, case_matching : CaseMatching, normalization : Normalization)
      @data_mtx.synchronize do
        @pattern.reparse(0, pattern_str, case_matching, normalization, false)
        @snapshot = nil
        @needs_run.set(true)
      end
    end

    def sort_results(_sort_results : Bool)
      # Sorting always performed in snapshot
    end

    def reverse_items(_reverse_items : Bool)
      # Not implemented
    end

    def tick(_timeout : Int) : Status
      changed = @dirty.swap(false)

      if @running.get
        return Status.new(changed: changed, running: true)
      end

      if @snapshot.nil? || @needs_run.get
        start_async_match
        return Status.new(changed: changed, running: true)
      end

      Status.new(changed: changed, running: false)
    end

    def match_list(items : Array(String), pattern : String) : Array(MatchResult)
      matcher = Matcher.new(@matcher.config)
      pattern_stripped = pattern.strip
      max_results = @max_results
      if pattern_stripped.empty?
        limit = max_results && max_results > 0 ? max_results : items.size
        results = Array(MatchResult).new(limit)
        items.first(limit).each do |item|
          results << MatchResult.new(item, 0_u16)
        end
        return results
      end

      pat = Pattern.parse(pattern)
      vector = BoxcarVector(MatchResult).new(items.size)
      items.each do |item|
        if score = pat.match(matcher, item)
          vector.push(MatchResult.new(item, score))
        end
      end

      if max_results && max_results > 0
        vector.top_k_snapshot(max_results) { |a, b| a < b }
      else
        vector.sort_snapshot { |a, b| a < b }
      end
    end

    def pattern=(pattern_str : String)
      update_pattern(pattern_str, CaseMatching::Smart, Normalization::Smart)
    end

    def pattern : MultiPattern
      @pattern
    end

    def match : Snapshot
      @data_mtx.synchronize do
        if @snapshot.nil?
          @snapshot = Snapshot.new([] of MatchResult, @pattern.snapshot_copy)
        end
        @snapshot.not_nil!
      end
    end

    def size : Int32
      @items.size
    end

    def empty? : Bool
      @items.empty?
    end

    protected def enqueue(cmd : Command(T))
      process_command(cmd)
    end

    private def process_command(cmd : Command(T)) : Status?
      case cmd.kind
      when Command::Kind::Add
        @data_mtx.synchronize do
          cmd.payload.try { |items| @items.concat(items) }
          @snapshot = nil
          @needs_run.set(true)
        end
      when Command::Kind::Extend
        @data_mtx.synchronize do
          cmd.payload.try { |items| @items.concat(items) }
          @snapshot = nil
          @needs_run.set(true)
        end
      when Command::Kind::Clear
        @data_mtx.synchronize do
          @items.clear
          @snapshot = nil
          @needs_run.set(true)
        end
      when Command::Kind::Restart
        @data_mtx.synchronize do
          @items = [] of String
          @snapshot = nil if cmd.clear_snapshot?
          @needs_run.set(true)
        end
      when Command::Kind::UpdatePattern
        @data_mtx.synchronize do
          @pattern = cmd.pattern.not_nil!
          @snapshot = nil
          @needs_run.set(true)
        end
      when Command::Kind::Tick
        status = tick(0)
        @notify.call
        return status
      end
      nil
    end

    private def start_async_match
      return if @running.swap(true)
      @needs_run.set(false)

      items_snapshot = nil.as(Array(String)?)
      pattern_snapshot = nil.as(MultiPattern?)
      matcher_config = nil.as(Config?)

      @data_mtx.synchronize do
        items_snapshot = @items.dup
        pattern_snapshot = @pattern.snapshot_copy
        matcher_config = @matcher.config
      end

      spawn do
        snapshot = build_snapshot(
          items_snapshot.not_nil!,
          pattern_snapshot.not_nil!,
          matcher_config.not_nil!
        )

        @data_mtx.synchronize do
          @snapshot = snapshot
        end
        @dirty.set(true)
        @running.set(false)

        if @needs_run.get
          start_async_match
        end
      end
    end

    private def build_snapshot(items : Array(String), pattern : MultiPattern, config : Config) : Snapshot
      if pattern.columns == 1 && should_parallelize_snapshot?(items.size)
        return build_snapshot_parallel(items, pattern, config)
      end

      matcher = Matcher.new(config)
      vector = BoxcarVector(MatchResult).new(items.size)
      items.each do |item|
        score = if pattern.columns == 1
                  pattern.score_single(item, matcher)
                else
                  nil
                end
        vector.push(MatchResult.new(item, score)) if score
      end
      max_results = @max_results
      sorted = if vector.size <= 1
                 vector.snapshot.to_a
               elsif max_results && max_results > 0
                 vector.top_k_snapshot(max_results) { |a, b| a < b }
               else
                 vector.sort_snapshot { |a, b| a < b }
               end
      Snapshot.new(sorted, pattern)
    end

    private def build_snapshot_parallel(items : Array(String), pattern : MultiPattern, config : Config) : Snapshot
      worker_count = parallel_worker_count
      chunk_size = (items.size + worker_count - 1) // worker_count
      chunks = (items.size + chunk_size - 1) // chunk_size

      results = Array(Array(MatchResult)?).new(chunks, nil)
      channels = Array(Channel(Nil)).new(chunks) { Channel(Nil).new }

      items.each_slice(chunk_size).with_index do |slice, chunk_idx|
        channel = channels[chunk_idx]
        spawn do
          matcher = Matcher.new(config)
          local = Array(MatchResult).new(slice.size)
          slice.each do |item|
            if score = pattern.score_single(item, matcher)
              local << MatchResult.new(item, score)
            end
          end
          results[chunk_idx] = local
          channel.send(nil)
        end
      end

      channels.each(&.receive)

      merged = Array(MatchResult).new(items.size)
      results.each do |chunk|
        next unless chunk
        merged.concat(chunk)
      end

      max_results = @max_results
      sorted = if merged.size <= 1
                 merged
               elsif max_results && max_results > 0
                 select_top_k(merged, max_results)
               else
                 sort_results(merged)
               end
      Snapshot.new(sorted, pattern)
    end

    private def sort_results(items : Array(MatchResult)) : Array(MatchResult)
      items.sort! do |a, b|
        if a < b
          -1
        elsif b < a
          1
        else
          0
        end
      end
      items
    end

    private def select_top_k(items : Array(MatchResult), k : Int32) : Array(MatchResult)
      return [] of MatchResult if k <= 0
      return sort_results(items) if items.size <= k

      heap = [] of MatchResult
      items.each do |item|
        if heap.size < k
          heap << item
          sift_up(heap, heap.size - 1)
        else
          if item < heap[0]
            heap[0] = item
            sift_down(heap, 0)
          end
        end
      end

      sort_results(heap)
    end

    private def sift_up(heap : Array(MatchResult), idx : Int32) : Nil
      current = idx
      while current > 0
        parent = (current - 1) // 2
        if heap[parent] < heap[current]
          heap[parent], heap[current] = heap[current], heap[parent]
          current = parent
        else
          break
        end
      end
    end

    private def sift_down(heap : Array(MatchResult), idx : Int32) : Nil
      size = heap.size
      current = idx
      loop do
        left = current * 2 + 1
        right = left + 1
        break if left >= size

        worst = left
        if right < size && heap[left] < heap[right]
          worst = right
        end

        if heap[current] < heap[worst]
          heap[current], heap[worst] = heap[worst], heap[current]
          current = worst
        else
          break
        end
      end
    end

    private def should_parallelize_snapshot?(items_size : Int32) : Bool
      return false if items_size < 5000
      return false if @worker_count <= 1
      return false if ENV["CRYSTAL_WORKERS"]?.try(&.to_i?) == 1
      true
    end

    private def parallel_worker_count : Int32
      cpu_count = System.cpu_count
      cpu = cpu_count.is_a?(Int32) ? cpu_count : cpu_count.to_i32
      Math.min(@worker_count, cpu).clamp(1, 16)
    end
  end

  def self.new_matcher(config : Config = Config.new, max_results : Int32? = nil) : Nucleo(String)
    Nucleo(String).new(config, max_results: max_results)
  end

  def self.new_matcher(type : T.class, config : Config = Config.new, max_results : Int32? = nil) : Nucleo(T) forall T
    Nucleo(T).new(config, max_results: max_results)
  end

  def self.fuzzy_match(haystack : String, needle : String, config : Config = Config.new) : UInt16?
    matcher = Matcher.new(config)
    matcher.fuzzy_match(haystack, needle)
  end

  def self.fuzzy_match_indices(haystack : String, needle : String, config : Config = Config.new) : Tuple(UInt16, Array(UInt32))?
    matcher = Matcher.new(config)
    indices = [] of UInt32
    score = matcher.fuzzy_indices(haystack, needle, indices)
    score ? {score, indices} : nil
  end

  # Parallel fuzzy match across many haystacks using a shared needle.
  # Returns an array of scores in the same order as the input.
  # Uses worker pools for proper concurrent processing.
  def self.parallel_fuzzy_match(
    haystacks : Array(String),
    needle : String,
    config : Config = Config.new,
    workers : Int32? = nil,
    timeout : Time::Span? = nil,
    error_handler : Proc(ErrorHandling::WorkerError, Nil)? = nil,
    strategy : Symbol = :auto,
  ) : Array(UInt16?)
    return [] of UInt16? if haystacks.empty?

    case choose_parallel_strategy(haystacks.size, strategy)
    when :sequential
      matcher = Matcher.new(config)
      normalized_needle = matcher.normalize_needle(needle)
      scores = Array(UInt16?).new(haystacks.size, nil)
      haystacks.each_with_index do |haystack, idx|
        scores[idx] = matcher.fuzzy_match_normalized(haystack, normalized_needle)
      end
      scores
    when :fiber
      matcher = Matcher.new(config)
      matcher.parallel_fuzzy_match_fiber(haystacks, needle)
    when :spawn
      matcher = Matcher.new(config)
      matcher.parallel_fuzzy_match(haystacks, needle)
    when :fiber_pool
      pool = fiber_pool(config, workers)
      pool.match_many(haystacks, needle, false).first
    when :cml_pool, :pool
      pool = cml_pool(config, workers, error_handler)
      pool.match_many(haystacks, needle, false, timeout).first
    else
      pool = cml_pool(config, workers, error_handler)
      pool.match_many(haystacks, needle, false, timeout).first
    end
  end

  # Parallel fuzzy match with indices across many haystacks using a shared needle.
  # Returns an array of optional tuples {score, indices} in the same order as the input.
  # Uses worker pools for proper concurrent processing.
  def self.parallel_fuzzy_indices(
    haystacks : Array(String),
    needle : String,
    config : Config = Config.new,
    workers : Int32? = nil,
    timeout : Time::Span? = nil,
    error_handler : Proc(ErrorHandling::WorkerError, Nil)? = nil,
    strategy : Symbol = :auto,
  ) : Array(Tuple(UInt16, Array(UInt32))?)
    return [] of Tuple(UInt16, Array(UInt32))? if haystacks.empty?

    case choose_parallel_strategy(haystacks.size, strategy)
    when :sequential
      matcher = Matcher.new(config)
      normalized_needle = matcher.normalize_needle(needle)
      results = Array(Tuple(UInt16, Array(UInt32))?).new(haystacks.size, nil)
      haystacks.each_with_index do |haystack, idx|
        indices = [] of UInt32
        score = matcher.fuzzy_indices_normalized(haystack, normalized_needle, indices)
        results[idx] = score ? {score, indices} : nil
      end
      results
    when :fiber
      matcher = Matcher.new(config)
      matcher.parallel_fuzzy_indices_fiber(haystacks, needle)
    when :spawn
      matcher = Matcher.new(config)
      matcher.parallel_fuzzy_indices(haystacks, needle)
    when :fiber_pool
      pool = fiber_pool(config, workers)
      scores, indices = pool.match_many(haystacks, needle, true)
      result = Array(Tuple(UInt16, Array(UInt32))?).new(haystacks.size, nil)
      scores.each_with_index do |score, idx|
        next unless score && indices
        idx_list = indices[idx]
        result[idx] = {score, idx_list.not_nil!} if idx_list
      end
      result
    when :cml_pool, :pool
      pool = cml_pool(config, workers, error_handler)
      scores, indices = pool.match_many(haystacks, needle, true, timeout)
      result = Array(Tuple(UInt16, Array(UInt32))?).new(haystacks.size, nil)
      scores.each_with_index do |score, idx|
        if score && indices
          idx_list = indices[idx]
          result[idx] = {score, idx_list.not_nil!} if idx_list
        end
      end
      result
    else
      pool = cml_pool(config, workers, error_handler)
      scores, indices = pool.match_many(haystacks, needle, true, timeout)
      result = Array(Tuple(UInt16, Array(UInt32))?).new(haystacks.size, nil)
      scores.each_with_index do |score, idx|
        if score && indices
          idx_list = indices[idx]
          result[idx] = {score, idx_list.not_nil!} if idx_list
        end
      end
      result
    end
  end

  # Parallel fuzzy match using CML.spawn for lightweight parallelism
  def self.parallel_fuzzy_match_spawn(haystacks : Array(String), needle : String, config : Config = Config.new, chunk_size : Int32? = nil) : Array(UInt16?)
    matcher = Matcher.new(config)
    matcher.parallel_fuzzy_match(haystacks, needle, chunk_size)
  end

  # Parallel fuzzy match with indices using CML.spawn
  def self.parallel_fuzzy_indices_spawn(haystacks : Array(String), needle : String, config : Config = Config.new, chunk_size : Int32? = nil) : Array(Tuple(UInt16, Array(UInt32))?)
    matcher = Matcher.new(config)
    matcher.parallel_fuzzy_indices(haystacks, needle, chunk_size)
  end

  private def self.choose_parallel_strategy(count : Int32, strategy : Symbol) : Symbol
    return strategy unless strategy == :auto

    # Keep small workloads sequential, use stdlib fibers for mid-size,
    # CML.spawn for larger batches, and a pool for very large.
    cpu_count = System.cpu_count
    cpu = cpu_count.is_a?(Int32) ? cpu_count : cpu_count.to_i32
    return :sequential if count < 256
    return :fiber if count < cpu * 512
    return :spawn if count < cpu * 2048
    return :fiber_pool if count < cpu * 8192
    :cml_pool
  end

  private def self.cml_pool(config : Config, workers : Int32?, error_handler : Proc(ErrorHandling::WorkerError, Nil)?) : CMLWorkerPool
    pool_size = workers || CMLWorkerPool.default_size
    return CMLWorkerPool.new(pool_size, config, error_handler) if error_handler

    key = {config, pool_size}
    @@pool_mutex.synchronize do
      @@cml_pools[key] ||= CMLWorkerPool.new(pool_size, config, nil)
    end
  end

  private def self.fiber_pool(config : Config, workers : Int32?) : FiberWorkerPool
    pool_size = workers || FiberWorkerPool.default_size
    key = {config, pool_size}
    @@pool_mutex.synchronize do
      @@fiber_pools[key] ||= FiberWorkerPool.new(pool_size, config)
    end
  end

  def self.substring_match(haystack : String, needle : String, config : Config = Config.new) : UInt16?
    matcher = Matcher.new(config)
    matcher.substring_match(haystack, needle)
  end

  def self.prefix_match(haystack : String, needle : String, config : Config = Config.new) : UInt16?
    matcher = Matcher.new(config)
    matcher.prefix_match(haystack, needle)
  end

  def self.postfix_match(haystack : String, needle : String, config : Config = Config.new) : UInt16?
    matcher = Matcher.new(config)
    matcher.postfix_match(haystack, needle)
  end
end
