# MultiPattern for matching across multiple columns with incremental updates
require "./pattern"

module Nucleoc
  # Multi-pattern matching across multiple columns with status tracking.
  class MultiPattern
    @cols : Array(Tuple(Pattern, PatternStatus))

    # Creates a multi pattern with `columns` empty column patterns.
    def initialize(columns : Int32)
      @cols = Array.new(columns) { {Pattern.new([] of Atom), PatternStatus::Rescore} }
    end

    # Number of columns in this multi pattern.
    def columns : Int32
      @cols.size
    end

    # Returns true if all column patterns are empty.
    def empty? : Bool
      @cols.all? { |pattern, _| pattern.atoms.empty? }
    end

    # Returns the overall status (maximum status across all columns).
    def status : PatternStatus
      @cols.max_of? { |_, s| s } || PatternStatus::Unchanged
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
    def reparse(column : Int32, new_text : String,
                case_matching : CaseMatching = CaseMatching::Smart,
                normalization : Normalization = Normalization::Smart,
                append : Bool = false) : Nil
      old_pattern, old_status = @cols[column]

      # Determine new status
      new_status = if append && old_status != PatternStatus::Rescore &&
                      (old_pattern.atoms.empty? || !old_pattern.atoms.last.negative?)
                     PatternStatus::Update
                   else
                     PatternStatus::Rescore
                   end

      # Actually reparse the pattern
      new_pattern = Pattern.parse(new_text, case_matching, normalization)
      @cols[column] = {new_pattern, new_status}
    end

    # Scores a multi-column haystack against all column patterns.
    # Returns the total score if all columns match, nil otherwise.
    def score(haystacks : Array(Utf32String), matcher : Matcher) : UInt16?
      total = 0_u16
      @cols.each_with_index do |(pattern, _), i|
        return if i >= haystacks.size
        column_score = pattern.match(matcher, haystacks[i].to_s)
        return unless column_score
        total += column_score
      end
      total
    end

    # Returns true if any column needs to be rescored.
    def needs_rescore? : Bool
      @cols.any? { |_, status| status == PatternStatus::Rescore }
    end

    # Returns true if any column needs to be updated.
    def needs_update? : Bool
      @cols.any? { |_, status| status == PatternStatus::Update }
    end

    # Marks all columns as unchanged.
    def mark_unchanged : Nil
      @cols.each_with_index do |(pattern, _), i|
        @cols[i] = {pattern, PatternStatus::Unchanged}
      end
    end

    # Resets all column statuses to Unchanged.
    def reset_status : Nil
      @cols.each_with_index do |(pattern, _), i|
        @cols[i] = {pattern, PatternStatus::Unchanged}
      end
    end

    # Resets all column patterns to empty.
    def clear : Nil
      @cols.each_with_index do |_, i|
        @cols[i] = {Pattern.new([] of Atom), PatternStatus::Rescore}
      end
    end
  end
end
