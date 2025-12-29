require "cml"
require "./boxcar"
require "./error_handling"
require "./multi_pattern"

# Main API for nucleoc fuzzy matching
module Nucleoc
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
    @active_injectors : Int32 = 0
    @baseline_injectors : Int32 = 0
    @baseline_set : Bool = false
    @mtx = Mutex.new
    @mailbox : CML::Mailbox(Command(T))
    @notify : Proc(Nil)
    @generation : Int32 = 0

    def initialize(config : Config = Config.new, notify : -> _ = -> { nil }, num_threads : Int32? = 1, columns : Int32 = 1)
      @matcher = Matcher.new(config)
      @pattern = MultiPattern.new(columns)
      @items = [] of String
      @snapshot = nil
      @worker_count = num_threads || 1
      @mailbox = CML::Mailbox(Command(T)).new
      @notify = -> { notify.call; nil }
    end

    # Rust constructor parity
    def initialize(config : Config, notify : Proc(Nil), num_threads : Int32?, columns : Int32)
      initialize(config, -> { notify.call }, num_threads, columns)
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
      @matcher = Matcher.new(config)
      # force snapshot invalidation
      @snapshot = nil
    end

    def update_pattern(pattern_str : String, case_matching : CaseMatching, normalization : Normalization)
      # Reparse column 0 of the multi-pattern
      @pattern.reparse(0, pattern_str, case_matching, normalization, false)
      # Invalidate snapshot
      @snapshot = nil
    end

    def sort_results(_sort_results : Bool)
      # Sorting always performed in snapshot
    end

    def reverse_items(_reverse_items : Bool)
      # Not implemented
    end

    def tick(_timeout : Int) : Status
      refresh_snapshot
    end

    def match_list(items : Array(String), pattern : String) : Array(MatchResult)
      matcher = Matcher.new(@matcher.config)
      pat = Pattern.parse(pattern)
      vector = BoxcarVector(MatchResult).new
      items.each do |item|
        if score = pat.match(matcher, item)
          vector.push(MatchResult.new(item, score))
        end
      end
      vector.sort_snapshot { |a, b| a < b }
    end

    def pattern=(pattern_str : String)
      update_pattern(pattern_str, CaseMatching::Smart, Normalization::Smart)
    end

    def pattern : MultiPattern
      @pattern
    end

    def match : Snapshot
      refresh_snapshot
      @snapshot.not_nil!
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
        cmd.payload.try { |items| @items.concat(items) }
        @snapshot = nil
      when Command::Kind::Extend
        cmd.payload.try { |items| @items.concat(items) }
        @snapshot = nil
      when Command::Kind::Clear
        @items.clear
        @snapshot = nil
      when Command::Kind::Restart
        @items = [] of String
        @snapshot = nil if cmd.clear_snapshot?
      when Command::Kind::UpdatePattern
        @pattern = cmd.pattern.not_nil!
        @snapshot = nil
      when Command::Kind::Tick
        status = refresh_snapshot
        @notify.call
        return status
      end
      nil
    end

    private def refresh_snapshot : Status
      changed = false
      if @snapshot.nil?
        vector = BoxcarVector(MatchResult).new
        @items.each do |item|
          if score = @pattern.score([item], @matcher)
            vector.push(MatchResult.new(item, score))
          end
        end
        sorted = vector.sort_snapshot { |a, b| a < b }
        @snapshot = Snapshot.new(sorted, @pattern)
        changed = true
      end
      Status.new(changed: changed, running: false)
    end
  end

  def self.new_matcher(config : Config = Config.new) : Nucleo(String)
    Nucleo(String).new(config)
  end

  def self.new_matcher(type : T.class, config : Config = Config.new) : Nucleo(T) forall T
    Nucleo(T).new(config)
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
  # Uses CML-based worker pool for proper concurrent processing.
  def self.parallel_fuzzy_match(
    haystacks : Array(String),
    needle : String,
    config : Config = Config.new,
    workers : Int32? = nil,
    timeout : Time::Span? = nil,
    error_handler : Proc(ErrorHandling::WorkerError, Nil)? = nil
  ) : Array(UInt16?)
    pool = CMLWorkerPool.new(workers || CMLWorkerPool.default_size, config, error_handler)
    pool.match_many(haystacks, needle, false, timeout).first
  end

  # Parallel fuzzy match with indices across many haystacks using a shared needle.
  # Returns an array of optional tuples {score, indices} in the same order as the input.
  # Uses CML-based worker pool for proper concurrent processing.
  def self.parallel_fuzzy_indices(
    haystacks : Array(String),
    needle : String,
    config : Config = Config.new,
    workers : Int32? = nil,
    timeout : Time::Span? = nil,
    error_handler : Proc(ErrorHandling::WorkerError, Nil)? = nil
  ) : Array(Tuple(UInt16, Array(UInt32))?)
    pool = CMLWorkerPool.new(workers || CMLWorkerPool.default_size, config, error_handler)
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
