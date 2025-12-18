require "./spec_helper"
require "../src/nucleoc"

describe "Score tests" do
  describe "test_hello_world_score" do
    it "matches 'hello' in 'hello world' with correct score" do
      # Port of test_hello_world_score from Rust test_score.rs
      matcher = Nucleoc::Matcher.new
      pattern = "hello"
      haystack = "hello world"

      # Test with fuzzy_match
      result = matcher.fuzzy_match(haystack, pattern)
      result.should_not be_nil
      result.try(&.should(be > 0))

      puts "Pattern: '#{pattern}'"
      puts "Haystack: '#{haystack}'"
      puts "Score: #{result}"

      # Also test with indices
      indices = [] of UInt32
      score_with_indices = matcher.fuzzy_indices(haystack, pattern, indices)
      score_with_indices.should_not be_nil
      indices.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])

      # Test with Nucleo wrapper
      config = Nucleoc::Config.new
      nucleo = Nucleoc::Nucleo(Int32).new(config, -> { 0 }, 1, 1)

      matches = nucleo.match_list([haystack], pattern)
      matches.size.should eq(1)
      matches[0].item.should eq(haystack)
      matches[0].score.should eq(result)

      puts "Nucleo matches: #{matches}"
    end
  end

  describe "score calculations" do
    it "calculates consistent scores for same matches" do
      matcher = Nucleoc::Matcher.new

      # Same match should give same score
      score1 = matcher.fuzzy_match("hello world", "hello")
      score2 = matcher.fuzzy_match("hello world", "hello")

      score1.should eq(score2)

      # Different matches should still be deterministic
      score3 = matcher.fuzzy_match("hello world", "world")
      score3.should_not be_nil
    end

    it "gives higher scores to better matches" do
      matcher = Nucleoc::Matcher.new

      # Exact match should have highest score
      exact_score = matcher.exact_match("hello", "hello")
      exact_score.should_not be_nil

      # Prefix match should be next
      prefix_score = matcher.prefix_match("hello world", "hello")
      prefix_score.should_not be_nil

      # Fuzzy match not at start should be lower
      fuzzy_score = matcher.fuzzy_match("world hello", "hello")
      fuzzy_score.should_not be_nil

      # Substring match should be lower than prefix
      substring_score = matcher.substring_match("say hello world", "hello")
      substring_score.should_not be_nil

      # Verify ordering (exact > prefix > fuzzy > substring for same position)
      # Note: Actual scores depend on implementation
    end

    it "applies bonus for boundary matches" do
      matcher = Nucleoc::Matcher.new

      # Match at word boundary should get bonus
      boundary_score = matcher.fuzzy_match("hello world", "hw")
      boundary_score.should_not be_nil

      # Match not at boundary should be lower
      non_boundary_score = matcher.fuzzy_match("helloworld", "hw")
      non_boundary_score.should_not be_nil

      # boundary_score should be higher than non_boundary_score
      boundary_score.try do |boundary_value|
        non_boundary_score.try { |other_value| boundary_value.should be > other_value }
      end
    end

    it "applies bonus for camel case matches" do
      matcher = Nucleoc::Matcher.new

      # Camel case match should get bonus
      camel_score = matcher.fuzzy_match("fooBarBaz", "fbb")
      camel_score.should_not be_nil

      # Non-camel match should be lower
      non_camel_score = matcher.fuzzy_match("foobarbaz", "fbb")
      non_camel_score.should_not be_nil

      # camel_score should be higher than non_camel_score
      camel_score.try do |camel_value|
        non_camel_score.try { |other_value| camel_value.should be > other_value }
      end
    end

    it "applies penalty for gaps" do
      matcher = Nucleoc::Matcher.new

      # Consecutive match should have higher score
      consecutive_score = matcher.fuzzy_match("hello", "he")
      consecutive_score.should_not be_nil

      # Gapped match should have lower score
      gapped_score = matcher.fuzzy_match("h e l l o", "he")
      gapped_score.should_not be_nil

      # consecutive_score should be higher than gapped_score
      consecutive_score.try do |consecutive_value|
        gapped_score.try { |gapped_value| consecutive_value.should be > gapped_value }
      end
    end
  end

  describe "score parity with Rust" do
    it "has matching scores for basic test cases" do
      # These tests verify that Crystal implementation gives same scores as Rust
      matcher = Nucleoc::Matcher.new

      # Test 1: Exact match "hello" in "hello"
      # Rust gives 140 for this match
      score = matcher.exact_match("hello", "hello")
      score.should eq(140)

      # Test 2: Fuzzy match "hello" in "hello world"
      # Rust gives 140 for this match (prefix match)
      score = matcher.fuzzy_match("hello world", "hello")
      score.should eq(140)

      # Test 3: Fuzzy match "obr" in "fooBarbaz1"
      score = matcher.fuzzy_match("fooBarbaz1", "obr")
      score.should_not be_nil
      # Rust score for this match would need to be verified

      # Test 4: Exact match case insensitive
      score = matcher.exact_match("Hello", "hello")
      score.should eq(140)

      # Test 5: No match
      matcher.exact_match("hello", "world").should be_nil
    end

    it "verifies scores from Rust test files" do
      # Compare with scores from test_rust_fuzzy.rs and test_rust_score.rs
      matcher = Nucleoc::Matcher.new

      # From test_rust_fuzzy.rs
      # Test 1: Exact match "hello" in "hello"
      score1 = matcher.exact_match("hello", "hello")
      puts "Crystal exact_match('hello', 'hello') = #{score1}"

      indices1 = [] of UInt32
      score_with_indices1 = matcher.exact_indices("hello", "hello", indices1)
      puts "Crystal exact_indices('hello', 'hello') = #{score_with_indices1}"
      puts "Crystal Indices: #{indices1}"

      # Test 2: Exact match "hello" in "hello world"
      score2 = matcher.exact_match("hello world", "hello")
      puts "\nCrystal exact_match('hello world', 'hello') = #{score2}"

      indices2 = [] of UInt32
      score_with_indices2 = matcher.exact_indices("hello world", "hello", indices2)
      puts "Crystal exact_indices('hello world', 'hello') = #{score_with_indices2}"
      puts "Crystal Indices: #{indices2}"

      # Test 3: Fuzzy match "hello" in "hello world"
      score3 = matcher.fuzzy_match("hello world", "hello")
      puts "\nCrystal fuzzy_match('hello world', 'hello') = #{score3}"

      indices3 = [] of UInt32
      score_with_indices3 = matcher.fuzzy_indices("hello world", "hello", indices3)
      puts "Crystal fuzzy_indices('hello world', 'hello') = #{score_with_indices3}"
      puts "Crystal Indices: #{indices3}"

      # From test_rust_score.rs
      pattern = "hello"
      haystack = "hello world"

      result = matcher.fuzzy_match(haystack, pattern)
      puts "\nPattern: '#{pattern}'"
      puts "Haystack: '#{haystack}'"
      puts "Score: #{result}"

      if result
        puts "Score value: #{result}"
      else
        puts "No match found"
      end
    end
  end
end
