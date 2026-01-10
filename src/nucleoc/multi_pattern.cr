# MultiPattern for matching across multiple columns with incremental updates
require "./pattern"
require "cml"

module Nucleoc
  # Multi-pattern matching across multiple columns with status tracking.
  class MultiPattern
    @cols : Array(Tuple(Pattern, PatternStatus))

    # Creates a multi pattern with `columns` empty column patterns.
    def initialize(columns : Int32)
      @cols = Array.new(columns) { {Pattern.new([] of Atom), PatternStatus::Unchanged} }
    end

    # Returns the number of columns.
    def columns : Int32
      @cols.size
    end

    # Returns the pattern for a column.
    def column_pattern(column : Int32) : Pattern
      @cols[column][0]
    end

    # Returns the status for a column.
    def column_status(column : Int32) : PatternStatus
      @cols[column][1]
    end

    # Updates the pattern for a column with new text.
    # If `append` is true, the caller promises that text passed
    # to the previous `reparse` invocation is a prefix of `new_text`.
    # This enables additional optimizations but can lead to missing matches
    # if an incorrect value is passed.
    def reparse(column : Int32, new_text : String,
                case_matching : CaseMatching = CaseMatching::Smart,
                normalization : Normalization = Normalization::Smart,
                append : Bool = false) : Nil
      old_pattern, old_status = @cols[column]

      if append && old_status != PatternStatus::Rescore &&
         (old_pattern.atoms.empty? || !old_pattern.atoms.last.negative?)
        @cols[column] = {old_pattern, PatternStatus::Update}
      else
        @cols[column] = {old_pattern, PatternStatus::Rescore}
      end

      # Actually reparse the pattern
      new_pattern = Pattern.parse(new_text, case_matching, normalization)
      @cols[column] = {new_pattern, @cols[column][1]}
    end

    # Returns the overall status of the multi-pattern.
    def status : PatternStatus
      @cols.max_of? { |_, s| s } || PatternStatus::Unchanged
    end

    # Resets all column statuses to Unchanged.
    def reset_status : Nil
      @cols.each_with_index do |(pattern, _), i|
        @cols[i] = {pattern, PatternStatus::Unchanged}
      end
    end

    # Return a copy that is safe to use without holding locks.
    def snapshot_copy : MultiPattern
      copy = MultiPattern.new(columns)
      @cols.each_with_index do |(pattern, status), idx|
        copy_cols = copy.@cols
        copy_cols[idx] = {pattern, status}
      end
      copy
    end

    # Checks if all column patterns are empty.
    def empty? : Bool
      @cols.all? { |pattern, _| pattern.atoms.empty? }
    end

    # Scores a multi-column haystack against this multi-pattern.
    # Returns the total score if all columns match, nil otherwise.
    # Uses sequential matching; for parallel matching, use `score_parallel`.
    def score(haystacks : Array(String), matcher : Matcher) : UInt16?
      total = 0_u16
      @cols.each_with_index do |(pattern, _), i|
        return if i >= haystacks.size
        column_score = pattern.match(matcher, haystacks[i])
        return unless column_score
        total += column_score
      end
      total
    end

    # Score a single-column haystack without allocating arrays.
    def score_single(haystack : String, matcher : Matcher) : UInt16?
      return if @cols.size != 1
      pattern, _ = @cols[0]
      pattern.match(matcher, haystack)
    end

    # Scores a multi-column haystack using parallel matching across columns.
    # Spawns a fiber per column using CML.spawn and aggregates results.
    # Returns the total score if all columns match, nil otherwise.
    def score_parallel(haystacks : Array(String), matcher_config : Config) : UInt16?
      return score(haystacks, Matcher.new(matcher_config)) if columns <= 1

      result_ch = CML::Chan(Tuple(Int32, UInt16?)).new

      # Spawn a fiber for each column
      columns.times do |col|
        CML.spawn do
          matcher = Matcher.new(matcher_config)
          pattern = @cols[col][0]
          haystack = haystacks[col]? || ""
          column_score = pattern.match(matcher, haystack)
          result_ch.send({col, column_score})
        end
      end

      # Collect results
      scores = Array(UInt16?).new(columns, nil)
      columns.times do
        col_idx, column_score = result_ch.recv
        scores[col_idx] = column_score
      end
      return if scores.any?(&.nil?)

      scores.reduce(0_u16) { |sum, score| sum + score.as(UInt16) }
    end

    # Parallel matching with cancellation support using CML events.
    # Returns the total score if all columns match before timeout, nil otherwise.
    def score_with_timeout(haystacks : Array(String), matcher_config : Config,
                           timeout : Time::Span) : UInt16?
      return if timeout <= 0.seconds

      result_ch = CML::Mailbox(Tuple(Int32, UInt16?)).new

      columns.times do |col|
        CML.spawn do
          matcher = Matcher.new(matcher_config)
          pattern = @cols[col][0]
          haystack = haystacks[col]? || ""
          column_score = pattern.match(matcher, haystack)
          result_ch.send({col, column_score})
        end
      end

      deadline = Time.monotonic + timeout
      scores = Array(UInt16?).new(columns, nil)
      received = 0

      while received < columns
        remaining = deadline - Time.monotonic
        return if remaining <= 0.seconds

        recv_evt = CML.wrap(result_ch.recv_evt) do |result|
          result.as(Tuple(Int32, UInt16?) | Symbol)
        end
        timeout_evt = CML.wrap(CML.timeout(remaining)) do
          :timeout.as(Tuple(Int32, UInt16?) | Symbol)
        end

        result = CML.sync(CML.choose([recv_evt, timeout_evt]))

        case result
        when Tuple(Int32, UInt16?)
          col_idx, column_score = result
          next unless scores[col_idx].nil?
          scores[col_idx] = column_score
          received += 1
        when :timeout
          return
        else
          return
        end
      end

      return if scores.any?(&.nil?)
      scores.reduce(0_u16) { |sum, score| sum + score.as(UInt16) }
    end
  end
end
