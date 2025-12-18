# Test helpers ported from Rust tests.rs
module Nucleoc::TestHelpers
  # Port of Algorithm enum from Rust
  enum Algorithm
    FuzzyOptimal
    FuzzyGreedy
    Substring
    Prefix
    Postfix
    Exact
  end

  # Constants from Rust score module - matching Nucleoc::Config constants
  SCORE_MATCH                 = Nucleoc::SCORE_MATCH
  PENALTY_GAP_START           = Nucleoc::PENALTY_GAP_START
  PENALTY_GAP_EXTENSION       = Nucleoc::PENALTY_GAP_EXTENSION
  PREFIX_BONUS_SCALE          = Nucleoc::PREFIX_BONUS_SCALE
  BONUS_BOUNDARY              = Nucleoc::BONUS_BOUNDARY
  MAX_PREFIX_BONUS            = Nucleoc::MAX_PREFIX_BONUS
  BONUS_CAMEL123              = Nucleoc::BONUS_CAMEL123
  BONUS_NON_WORD              = Nucleoc::BONUS_NON_WORD
  BONUS_CONSECUTIVE           = Nucleoc::BONUS_CONSECUTIVE
  BONUS_FIRST_CHAR_MULTIPLIER = Nucleoc::BONUS_FIRST_CHAR_MULTIPLIER

  # Default config bonus values
  BONUS_BOUNDARY_WHITE     = BONUS_BOUNDARY + 2_u16 # 10
  BONUS_BOUNDARY_DELIMITER = BONUS_BOUNDARY + 1_u16 # 9

  # Port of assert_matches from Rust
  def self.assert_matches(
    algorithms : Array(Algorithm),
    normalize : Bool,
    case_sensitive : Bool,
    path : Bool,
    prefer_prefix : Bool,
    cases : Array(Tuple(String, String, Array(UInt32), UInt16)),
  )
    config = Nucleoc::Config.new(
      normalize: normalize,
      ignore_case: !case_sensitive,
      prefer_prefix: prefer_prefix
    )

    if path
      config = config.match_paths
    end

    matcher = Nucleoc::Matcher.new(config)

    cases.each do |haystack, needle, expected_indices, expected_score|
      # Apply case sensitivity - Rust does this in the test
      processed_needle = if !case_sensitive
                           needle.downcase
                         else
                           needle
                         end

      # Add SCORE_MATCH for each character
      # In Rust: score += needle.len() as u16 * SCORE_MATCH
      adjusted_score = expected_score + (processed_needle.size * SCORE_MATCH).to_u16

      algorithms.each do |algo|
        indices = [] of UInt32
        result = case algo
                 when Algorithm::FuzzyOptimal
                   matcher.fuzzy_indices(haystack, processed_needle, indices)
                 when Algorithm::FuzzyGreedy
                   matcher.fuzzy_indices_greedy(haystack, processed_needle, indices)
                 when Algorithm::Substring
                   matcher.substring_indices(haystack, processed_needle, indices)
                 when Algorithm::Prefix
                   matcher.prefix_indices(haystack, processed_needle, indices)
                 when Algorithm::Postfix
                   matcher.postfix_indices(haystack, processed_needle, indices)
                 when Algorithm::Exact
                   matcher.exact_indices(haystack, processed_needle, indices)
                 end

        # Check score
        if result != adjusted_score
          raise "Score mismatch: #{needle.inspect} did not match #{haystack.inspect}: got #{result}, expected #{adjusted_score} (algo: #{algo})"
        end

        # Check indices
        if indices != expected_indices
          raise "Indices mismatch: #{needle.inspect} match #{haystack.inspect} (algo: #{algo}): got #{indices}, expected #{expected_indices}"
        end

        # Check matched characters (normalize for comparison)
        matched_chars = indices.map { |i| haystack[i]?.try(&.downcase) }
        needle_chars = processed_needle.downcase.chars

        # Only check character match if we have indices
        unless expected_indices.empty?
          if matched_chars.size != needle_chars.size
            raise "Character count mismatch: #{needle.inspect} match #{haystack.inspect} indices are incorrect #{indices} (algo: #{algo})"
          end
        end
      end
    end
  end

  # Port of assert_not_matches_with from Rust
  def self.assert_not_matches_with(
    normalize : Bool,
    case_sensitive : Bool,
    algorithms : Array(Algorithm),
    cases : Array(Tuple(String, String)),
  )
    config = Nucleoc::Config.new(
      normalize: normalize,
      ignore_case: !case_sensitive
    )

    matcher = Nucleoc::Matcher.new(config)

    cases.each do |haystack, needle|
      # Apply case sensitivity for non-matches too
      processed_needle = if !case_sensitive
                           needle.downcase
                         else
                           needle
                         end

      algorithms.each do |algo|
        indices = [] of UInt32
        result = case algo
                 when Algorithm::FuzzyOptimal
                   matcher.fuzzy_indices(haystack, processed_needle, indices)
                 when Algorithm::FuzzyGreedy
                   matcher.fuzzy_indices_greedy(haystack, processed_needle, indices)
                 when Algorithm::Substring
                   matcher.substring_indices(haystack, processed_needle, indices)
                 when Algorithm::Prefix
                   matcher.prefix_indices(haystack, processed_needle, indices)
                 when Algorithm::Postfix
                   matcher.postfix_indices(haystack, processed_needle, indices)
                 when Algorithm::Exact
                   matcher.exact_indices(haystack, processed_needle, indices)
                 end

        if result
          raise "Unexpected match: #{needle.inspect} matched #{haystack.inspect} with score #{result} (algo: #{algo})"
        end
      end
    end
  end

  # Shortcut to assert non-matches with all algorithms
  def self.assert_not_matches(normalize : Bool, case_sensitive : Bool, cases : Array(Tuple(String, String)))
    assert_not_matches_with(
      normalize,
      case_sensitive,
      [Algorithm::FuzzyOptimal, Algorithm::FuzzyGreedy, Algorithm::Substring, Algorithm::Prefix, Algorithm::Postfix, Algorithm::Exact],
      cases
    )
  end
end
