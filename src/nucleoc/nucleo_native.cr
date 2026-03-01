require "atomic"
require "./utf32_str"
require "./boxcar_native"
require "./multi_pattern_native"
require "./par_sort_native"
require "./worker_pool_fiber"
require "./matcher"

module Nucleoc
  # A match candidate stored in a Nucleo worker.
  struct Item(T)
    getter data : T
    getter matcher_columns : Array(Utf32String)

    def initialize(@data : T, @matcher_columns : Array(Utf32String))
    end
  end

  # Metadata for a match (score and index).
  struct Match
    getter score : UInt16
    getter idx : UInt32

    def initialize(@score : UInt16, @idx : UInt32)
    end
  end

  # A read-only snapshot of match results.
  class Snapshot(T)
    getter items : Boxcar(T)
    getter matches : Array(Match)
    getter pattern : MultiPattern
    getter item_count : UInt32

    def initialize(@items : Boxcar(T), @matches : Array(Match), @pattern : MultiPattern, @item_count : UInt32)
    end

    # Returns the total number of items in the snapshot.
    def item_count : UInt32
      @item_count
    end

    # Returns the pattern which items were matched against.
    def pattern : MultiPattern
      @pattern
    end

    # Returns the number of items that matched the pattern.
    def matched_item_count : UInt32
      @matches.size.to_u32
    end

    # Returns an iterator over matched items in the given range.
    def matched_items(range : Range(Int32?, Int32?)) : Array(Item(T))
      start_idx = range.begin || 0
      end_idx = range.end || @matches.size - 1
      end_idx = @matches.size - 1 if end_idx >= @matches.size

      result = [] of Item(T)
      (start_idx..end_idx).each do |i|
        match = @matches[i]
        if entry = @items.get_entry(match.idx.to_i64)
          if entry.active? && entry.value && entry.matcher_columns
            result << Item(T).new(entry.value.not_nil!, entry.matcher_columns.not_nil!)
          end
        end
      end
      result
    end

    # Returns a reference to the item at the given index.
    def get_item(index : UInt32) : Item(T)?
      if entry = @items.get_entry(index.to_i64)
        if entry.active? && entry.value && entry.matcher_columns
          Item(T).new(entry.value.not_nil!, entry.matcher_columns.not_nil!)
        end
      end
    end

    # Returns the item corresponding to the nth match.

    # Returns the matches in this snapshot.
    def matches : Array(Match)
      @matches
    end

    # Returns the item corresponding to the nth match.
    def get_matched_item(n : UInt32) : Item(T)?
      return if n >= @matches.size
      match = @matches[n]
      get_item(match.idx)
    end
  end

  # Status returned by the tick method.
  struct Status
    getter changed : Bool
    getter running : Bool

    def initialize(@changed : Bool, @running : Bool)
    end

    def changed? : Bool
      @changed
    end

    def running? : Bool
      @running
    end
  end

  # A handle for adding items to a Nucleo worker.
  class Injector(T)
    @items : Boxcar(T)
    @notify : -> Nil
    @release_callback : -> Nil
    @generation : Int32

    def initialize(@items : Boxcar(T), @notify : -> Nil, @release_callback : -> Nil, @generation : Int32)
    end

    # Explicitly release this injector
    def release : Nil
      @release_callback.call
    end

    # Appends an element to the list of matched items.
    # This function is lock-free and wait-free.
    def push(value : T, &fill_columns : T, Array(Utf32String) -> Nil) : UInt32
      index = @items.push(value, &fill_columns)
      @notify.call
      index.to_u32
    end

    # Appends multiple elements to the list of matched items.
    # This function is lock-free and wait-free.
    def extend(values : Enumerable(T), &fill_columns : T, Array(Utf32String) -> Nil) : Nil
      @items.push_all(values, &fill_columns)
      @notify.call
    end

    # Returns the total number of items injected in the matcher.
    def injected_items : UInt32
      @items.size.to_u32
    end

    # Returns a reference to the item at the given index.
    def get(index : UInt32) : Item(T)?
      if entry = @items.get_entry(index.to_i64)
        if entry.active? && entry.value && entry.matcher_columns
          Item(T).new(entry.value.not_nil!, entry.matcher_columns.not_nil!)
        end
      end
    end

    # Clear all items.
    def clear : Nil
      @items.clear
      @notify.call
    end
  end

  # Commands sent to the worker fiber.
  struct Command(T)
    enum Kind
      Restart
      UpdateConfig
      SortResults
      ReverseItems
      Tick
      Reparse
    end

    getter kind : Kind
    getter config : Config?
    getter sort_results : Bool?
    getter reverse_items : Bool?
    getter clear_snapshot : Bool?
    getter reply : Channel(Status)?
    getter column : Int32?
    getter new_text : String?
    getter case_matching : CaseMatching?
    getter normalization : Normalization?
    getter append : Bool?

    def self.restart(clear_snapshot : Bool) : self
      new(Kind::Restart, nil, nil, nil, clear_snapshot, nil, nil, nil, nil, nil, nil)
    end

    def self.update_config(config : Config) : self
      new(Kind::UpdateConfig, config, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    end

    def self.sort_results(sort_results : Bool) : self
      new(Kind::SortResults, nil, sort_results, nil, nil, nil, nil, nil, nil, nil, nil)
    end

    def self.reverse_items(reverse_items : Bool) : self
      new(Kind::ReverseItems, nil, nil, reverse_items, nil, nil, nil, nil, nil, nil, nil)
    end

    def self.tick(reply : Channel(Status)) : self
      new(Kind::Tick, nil, nil, nil, nil, reply, nil, nil, nil, nil, nil)
    end

    def self.reparse(column : Int32, new_text : String, case_matching : CaseMatching = CaseMatching::Smart, normalization : Normalization = Normalization::Smart, append : Bool = false) : self
      new(Kind::Reparse, nil, nil, nil, nil, nil, column, new_text, case_matching, normalization, append)
    end

    private def initialize(@kind : Kind, @config : Config?, @sort_results : Bool?, @reverse_items : Bool?, @clear_snapshot : Bool?, @reply : Channel(Status)?, @column : Int32?, @new_text : String?, @case_matching : CaseMatching?, @normalization : Normalization?, @append : Bool?)
    end
  end

  # Internal worker state.
  class Worker(T)
    @matchers : Array(Matcher)
    @matches : Array(Match)
    @pattern : MultiPattern
    @sort_results : Bool = true
    @reverse_items : Bool = false
    @canceled : Atomic(Bool)
    @should_notify : Atomic(Bool)
    @was_canceled : Bool = false
    @last_snapshot : UInt32 = 0
    @notify : -> Nil
    @items : Boxcar(T)
    @in_flight : Array(UInt32) = [] of UInt32

    def initialize(config : Config, notify : -> Nil, @items : Boxcar(T))
      @matchers = [Matcher.new(config)]
      @matches = [] of Match
      @pattern = MultiPattern.new(1)
      @canceled = Atomic(Bool).new(false)
      @should_notify = Atomic(Bool).new(false)
      @notify = notify
    end

    def item_count : UInt32
      @last_snapshot - @in_flight.size.to_u32
    end

    def update_config(config : Config) : Nil
      @matchers.each(&.config=(config))
    end

    def sort_results(sort_results : Bool) : Nil
      @sort_results = sort_results
    end

    def reverse_items(reverse_items : Bool) : Nil
      @reverse_items = reverse_items
    end

    # Updates the pattern for a column.
    def reparse(column : Int32, new_text : String, case_matching : CaseMatching = CaseMatching::Smart, normalization : Normalization = Normalization::Smart, append : Bool = false) : Nil
      @pattern.reparse(column, new_text, case_matching, normalization, append)
      # Clear matches when pattern changes so items are re-matched
      @matches.clear
      @last_snapshot = 0
    end

    # Process matches for items in the given range.
    private def process_items(start_idx : UInt32, end_idx : UInt32) : Nil
      return if start_idx >= end_idx

      matcher = @matchers.first
      pattern = @pattern.column_pattern(0)

      (start_idx...end_idx).each do |idx|
        if entry = @items.get_entry(idx.to_i64)
          if entry.active? && entry.value && entry.matcher_columns
            # Match against each column and take the best score
            best_score : UInt16? = nil
            entry.matcher_columns.not_nil!.each do |column|
              score = pattern.match(matcher, column.to_s)
              if score && (best_score.nil? || score > best_score)
                best_score = score
              end
            end

            if best_score
              @matches << Match.new(best_score, idx)
            end
          end
        end
      end
    end

    # Run one iteration of the worker.
    def run(canceled : Atomic(Bool)) : Bool
      return false if canceled.get

      # Get current item count
      current_count = @items.size.to_u32
      return false if current_count == @last_snapshot

      # Process new items
      process_items(@last_snapshot, current_count)
      @last_snapshot = current_count

      # Sort matches if needed
      if @sort_results && !@matches.empty?
        canceled_flag = ParSort::CancelFlag.new(false)
        is_less = ->(a : Match, b : Match) do
          if @reverse_items
            a.score < b.score
          else
            a.score > b.score
          end
        end
        ParSort.sort(@matches, is_less, canceled_flag)
      end

      true
    end

    def snapshot : Snapshot(T)
      Snapshot(T).new(@items, @matches.dup, @pattern.dup, item_count)
    end
  end

  # A high-level matcher worker that computes matches in background fibers.
  class Nucleo(T)
    @worker : Worker(T)
    @command_channel : Channel(Command(T))
    @canceled : Atomic(Bool)
    @should_notify : Atomic(Bool)
    @state : Symbol = :init
    @items : Boxcar(T)
    @notify : -> Nil
    @snapshot : Snapshot(T)?
    @pattern : MultiPattern
    @injector_count : Atomic(Int32)
    @injector_generation : Atomic(Int32)

    # Constructs a new nucleo worker.
    #
    # * `config` - The matcher configuration
    # * `notify` - Called when new information is available and `tick` should be called
    # * `num_threads` - Number of worker threads (not used in Crystal fiber version)
    # * `columns` - Number of columns for multi-column matching
    def initialize(config : Config = Config.new, notify : -> Nil = -> { nil }, num_threads : Int32? = nil, columns : Int32 = 1)
      @items = Boxcar(T).new
      @notify = notify
      @worker = Worker(T).new(config, notify, @items)
      @command_channel = Channel(Command(T)).new
      @canceled = Atomic(Bool).new(false)
      @should_notify = Atomic(Bool).new(false)
      @pattern = MultiPattern.new(columns)
      @injector_count = Atomic(Int32).new(0)
      @injector_generation = Atomic(Int32).new(0)

      # Start worker fiber
      spawn worker_loop
    end

    # Returns the number of active injectors.
    def active_injectors : Int32
      @injector_count.get
    end

    # Returns a read-only snapshot of the current match state.
    def snapshot : Snapshot(T)
      @snapshot || @worker.snapshot
    end

    # Returns an injector for adding items to this matcher.
    def injector : Injector(T)
      @injector_count.add(1)
      generation = @injector_generation.get
      Injector(T).new(@items, @notify, -> {
        # Only decrement if we're still in the same generation
        if @injector_generation.get == generation
          @injector_count.sub(1)
        end
        nil
      }, generation)
    end

    # Restarts the matcher, optionally clearing the current snapshot.
    def restart(clear_snapshot : Bool = false) : Nil
      @command_channel.send(Command(T).restart(clear_snapshot))
      # Reset injector count and increment generation on restart
      @injector_count.set(0)
      @injector_generation.add(1)
    end

    # Updates the matcher configuration.
    def update_config(config : Config) : Nil
      @command_channel.send(Command(T).update_config(config))
    end

    # Enables or disables sorting of match results by score.
    def sort_results(sort_results : Bool) : Nil
      @command_channel.send(Command(T).sort_results(sort_results))
    end

    # Reverses the sort order of match results.
    def reverse_items(reverse_items : Bool) : Nil
      @command_channel.send(Command(T).reverse_items(reverse_items))
    end

    # The pattern matched by this matcher.
    def pattern : MultiPattern
      @pattern
    end

    # Updates the pattern for a column.
    def reparse(column : Int32, new_text : String, case_matching : CaseMatching = CaseMatching::Smart, normalization : Normalization = Normalization::Smart, append : Bool = false) : Nil
      @pattern.reparse(column, new_text, case_matching, normalization, append)
      @command_channel.send(Command(T).reparse(column, new_text, case_matching, normalization, append))
    end

    # Processes pending updates and returns the current status.
    #
    # * `timeout` - Maximum time to wait for updates (in milliseconds)
    def tick(timeout : UInt64 = 0) : Status
      reply = Channel(Status).new
      @command_channel.send(Command(T).tick(reply))

      if timeout > 0
        select
        when status = reply.receive
          status
        when timeout(timeout.milliseconds)
          Status.new(false, true)
        end
      else
        reply.receive
      end
    end

    private def worker_loop : Nil
      loop do
        select
        when command = @command_channel.receive
          process_command(command)
        end
      end
    end

    private def process_command(command : Command(T)) : Nil
      case command.kind
      when Command::Kind::Restart
        # TODO: Implement restart
        if command.clear_snapshot
          @snapshot = nil
        end
        command.reply.try &.send(Status.new(true, false))
      when Command::Kind::UpdateConfig
        @worker.update_config(command.config.not_nil!)
        command.reply.try &.send(Status.new(true, false))
      when Command::Kind::SortResults
        @worker.sort_results(command.sort_results.not_nil!)
        command.reply.try &.send(Status.new(true, false))
      when Command::Kind::ReverseItems
        @worker.reverse_items(command.reverse_items.not_nil!)
        command.reply.try &.send(Status.new(true, false))
      when Command::Kind::Reparse
        @worker.reparse(command.column.not_nil!, command.new_text.not_nil!, command.case_matching.not_nil!, command.normalization.not_nil!, command.append.not_nil!)
        command.reply.try &.send(Status.new(true, false))
      when Command::Kind::Tick
        changed = @worker.run(@canceled)
        @snapshot = @worker.snapshot if changed
        command.reply.try &.send(Status.new(changed, false))
      end
    end
  end
end
