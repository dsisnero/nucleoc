require "./boxcar_native"
require "./multi_pattern_native"
require "./nucleo_native"

# Main API for nucleoc fuzzy matching
module Nucleoc
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
  def self.match_list(items : Array(String), pattern : String, config : Config = Config.new) : Array(MatchResult)
    matcher = Matcher.new(config)
    pat = Pattern.parse(pattern)
    results = [] of MatchResult
    items.each do |item|
      if score = pat.match(matcher, item)
        results << MatchResult.new(item, score)
      end
    end
    results.sort! { |a, b| b.score <=> a.score } # descending by score
    results
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
          result[idx] = {score, idx_list.not_nil!} if idx_list
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
          result[idx] = {score, idx_list.not_nil!} if idx_list
        end
      end
      result
    end
  end

  private def self.choose_parallel_strategy(count : Int32, strategy : Symbol) : Symbol
    return strategy unless strategy == :auto

    # Keep small workloads sequential, use stdlib fibers for mid-size,
    # native spawn for larger batches, and a fiber pool for very large.
    cpu_count = System.cpu_count
    cpu = cpu_count.is_a?(Int32) ? cpu_count : cpu_count.to_i32
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
