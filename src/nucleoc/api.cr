require "./boxcar_native"
require "./multi_pattern_native"
require "./nucleo_native"

# Main API for nucleoc fuzzy matching
module Nucleoc
  # Compile-time flag: is multithreading enabled?
  # Parallel optimizations only make sense with -Dpreview_mt
  # Without it, fibers run on single thread, so parallel has overhead but no benefit
  {% if flag?(:preview_mt) %}
    # Runtime constant set at compile time
    PARALLEL_ENABLED = true
  {% else %}
    PARALLEL_ENABLED = false
  {% end %}

  @@pool_mutex = Mutex.new
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

  def self.new_matcher(config : Config = Config.new, max_results : Int32? = nil) : Nucleoc::Nucleo(String)
    Nucleoc::Nucleo(String).new(config)
  end

  def self.new_matcher(type : T.class, config : Config = Config.new, max_results : Int32? = nil) : Nucleoc::Nucleo(T) forall T
    Nucleoc::Nucleo(T).new(config)
  end

  # Simple match_list implementation for compatibility with tests
  def self.match_list(items : Array(String), pattern : String, config : Config = Config.new, max_results : Int32? = nil) : Array(MatchResult)
    # Fast path: empty pattern matches everything with score 0
    if pattern.empty?
      limit = max_results || items.size
      # Most efficient: create array with initializer block
      return Array(MatchResult).new(limit) { |i| MatchResult.new(items[i], 0_u16) }
    end

    matcher = Matcher.new(config)
    pat = Pattern.parse(pattern)
    results = [] of MatchResult
    items.each do |item|
      if score = pat.match(matcher, item)
        results << MatchResult.new(item, score)
      end
    end
    results.sort! { |a, b| b.score <=> a.score } # descending by score
    max_results ? results[0, max_results] : results
  end

  # Parallel match_list implementation with top-k optimization
  def self.parallel_match_list(items : Array(String), pattern : String, config : Config = Config.new, max_results : Int32? = nil, workers : Int32? = nil, strategy : Symbol = :auto) : Array(MatchResult)
    return [] of MatchResult if items.empty?

    # Get scores in parallel
    scores = parallel_fuzzy_match(items, pattern, config, workers, strategy)

    # Collect results with scores
    results = [] of MatchResult
    items.each_with_index do |item, idx|
      if score = scores[idx]
        results << MatchResult.new(item, score)
      end
    end

    # Sort descending by score
    results.sort! { |a, b| b.score <=> a.score }

    # Apply max_results limit
    max_results ? results[0, max_results] : results
  end

  # Optimized parallel match with top-k selection
  # Each worker keeps top-k results, reducing data transfer and sorting
  def self.parallel_top_k_match(items : Array(String), pattern : String, k : Int32, config : Config = Config.new, workers : Int32? = nil) : Array(MatchResult)
    return [] of MatchResult if items.empty? || k <= 0

    # Without multithreading, use sequential version
    # Parallel overhead without -Dpreview_mt doesn't give benefit
    unless PARALLEL_ENABLED
      return match_list(items, pattern, config, k)
    end

    # For small datasets, use sequential
    if items.size <= 256 || k >= items.size
      return match_list(items, pattern, config, k)
    end

    # Normalize needle once (thread-safe)
    base_matcher = Matcher.new(config)
    normalized_needle = base_matcher.normalize_needle(pattern)

    # Determine chunk size
    cpu_count = System.cpu_count
    cpu_count = cpu_count.is_a?(Int32) ? cpu_count : cpu_count.to_i32
    target_chunks = cpu_count.clamp(1, 16)
    chunk_size = (items.size + target_chunks - 1) // target_chunks
    total_chunks = (items.size + chunk_size - 1) // chunk_size

    # Channel for worker results (each worker returns top k from its chunk)
    result_channel = Channel(Array(MatchResult)).new

    total_chunks.times do |chunk_idx|
      start_idx = chunk_idx * chunk_size
      end_idx = Math.min(start_idx + chunk_size, items.size)
      chunk_items = items[start_idx...end_idx]

      spawn do
        # Each worker gets its own matcher
        worker_matcher = Matcher.new(config)
        worker_results = [] of MatchResult

        chunk_items.each do |item|
          if score = worker_matcher.fuzzy_match_normalized(item, normalized_needle)
            match_result = MatchResult.new(item, score)

            # Insert into worker's top-k list
            insert_index = worker_results.bsearch_index { |result| result.score <= score } || worker_results.size
            worker_results.insert(insert_index, match_result)

            # Keep only top k
            worker_results = worker_results[0, k] if worker_results.size > k
          end
        end

        result_channel.send(worker_results)
      end
    end

    # Collect and merge results from all workers
    all_worker_results = [] of MatchResult
    total_chunks.times do
      worker_results = result_channel.receive
      all_worker_results.concat(worker_results)
    end

    # Sort merged results and take top k
    all_worker_results.sort! { |a, b| b.score <=> a.score }
    all_worker_results[0, k]
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
  # Returns an array of optional scores in the same order as the input.
  # Uses worker pools for proper concurrent processing.
  def self.parallel_fuzzy_match(
    haystacks : Array(String),
    needle : String,
    config : Config = Config.new,
    workers : Int32? = nil,
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
    when :fiber_pool, :pool
      pool = fiber_pool(config, workers)
      pool.match_many(haystacks, needle, false).first
    else
      pool = fiber_pool(config, workers)
      pool.match_many(haystacks, needle, false).first
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
    when :fiber_pool, :pool
      pool = fiber_pool(config, workers)
      scores, indices = pool.match_many(haystacks, needle, true)
      result = Array(Tuple(UInt16, Array(UInt32))?).new(haystacks.size, nil)
      scores.each_with_index do |score, idx|
        if score && indices
          idx_list = indices[idx]
          result[idx] = {score, idx_list} if idx_list
        end
      end
      result
    else
      pool = fiber_pool(config, workers)
      scores, indices = pool.match_many(haystacks, needle, true)
      result = Array(Tuple(UInt16, Array(UInt32))?).new(haystacks.size, nil)
      scores.each_with_index do |score, idx|
        if score && indices
          idx_list = indices[idx]
          result[idx] = {score, idx_list} if idx_list
        end
      end
      result
    end
  end

  private def self.choose_parallel_strategy(count : Int32, strategy : Symbol) : Symbol
    return strategy unless strategy == :auto

    # Runtime check: if single-core or no multithreading benefit, use sequential
    # Note: System.cpu_count might return 1 on single-core machines
    cpu_count = System.cpu_count
    cpu = cpu_count.is_a?(Int32) ? cpu_count : cpu_count.to_i32

    # Without multiple cores, parallel has no benefit
    # Also, without -Dpreview_mt, fibers run on single thread
    if cpu <= 1 || !PARALLEL_ENABLED
      return :sequential
    end

    # Keep small workloads sequential, use stdlib fibers for mid-size,
    # native spawn for larger batches, and a fiber pool for very large.
    return :sequential if count < 256
    return :fiber if count < cpu * 512
    return :spawn if count < cpu * 2048
    :fiber_pool
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
