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

    # Scores a multi-column haystack using parallel matching across columns.
    # Spawns a fiber per column using CML.spawn and aggregates results.
    # Returns the total score if all columns match, nil otherwise.
    def score_parallel(haystacks : Array(String), matcher_config : Config) : UInt16?
      return score(haystacks, Matcher.new(matcher_config)) if columns <= 1

      channels = Array(CML::Chan(Tuple(Int32, UInt16?))).new(columns)
      columns.times { channels << CML::Chan(Tuple(Int32, UInt16?)).new }

      # Spawn a fiber for each column
      columns.times do |col|
        spawn do
          matcher = Matcher.new(matcher_config)
          pattern = @cols[col][0]
          haystack = haystacks[col]? || ""
          column_score = pattern.match(matcher, haystack)
          channels[col].send({col, column_score})
        end
      end

      # Collect results
      total = 0_u16
      columns.times do |col|
        col_idx, column_score = channels[col].recv
        return unless column_score
        total += column_score
      end
      total
    end

    # Parallel matching with cancellation support using CML events.
    # Returns the total score if all columns match before timeout, nil otherwise.
    # TODO: Implement proper timeout with CML.choose
    def score_with_timeout(haystacks : Array(String), matcher_config : Config,
                           timeout : Time::Span) : UInt16?
      # For now, just use parallel scoring without timeout
      score_parallel(haystacks, matcher_config)
    end
  end
end
