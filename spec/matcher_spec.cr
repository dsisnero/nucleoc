require "./spec_helper"
require "../src/nucleoc"

describe Nucleoc::Matcher do
  # Port of all tests from Rust matcher/tests.rs

  describe "fuzzy matching" do
    it "matches basic fuzzy patterns" do
      matcher = Nucleoc::Matcher.new

      # Test 1: "obr" in "fooBarbaz1"
      score = matcher.fuzzy_match("fooBarbaz1", "obr")
      score.should_not be_nil

      indices = [] of UInt32
      score_with_indices = matcher.fuzzy_indices("fooBarbaz1", "obr", indices)
      score_with_indices.should_not be_nil
      indices.should eq([2_u32, 3_u32, 5_u32])

      # Test 2: "changelog" in "/usr/share/doc/at/ChangeLog"
      score = matcher.fuzzy_match("/usr/share/doc/at/ChangeLog", "changelog")
      score.should_not be_nil

      indices.clear
      score_with_indices = matcher.fuzzy_indices("/usr/share/doc/at/ChangeLog", "changelog", indices)
      score_with_indices.should_not be_nil
      indices.should eq([18_u32, 19_u32, 20_u32, 21_u32, 22_u32, 23_u32, 24_u32, 25_u32, 26_u32])

      # Test 3: "br" in "fooBarbaz1"
      score = matcher.fuzzy_match("fooBarbaz1", "br")
      score.should_not be_nil

      indices.clear
      score_with_indices = matcher.fuzzy_indices("fooBarbaz1", "br", indices)
      score_with_indices.should_not be_nil
      indices.should eq([3_u32, 5_u32])

      # Test 4: "fbb" in "foo bar baz"
      score = matcher.fuzzy_match("foo bar baz", "fbb")
      score.should_not be_nil

      indices.clear
      score_with_indices = matcher.fuzzy_indices("foo bar baz", "fbb", indices)
      score_with_indices.should_not be_nil
      indices.should eq([0_u32, 4_u32, 8_u32])
    end

    it "matches camel case patterns" do
      matcher = Nucleoc::Matcher.new

      # Test: "rdoc" in "/AutomatorDocument.icns"
      score = matcher.fuzzy_match("/AutomatorDocument.icns", "rdoc")
      score.should_not be_nil

      indices = [] of UInt32
      score_with_indices = matcher.fuzzy_indices("/AutomatorDocument.icns", "rdoc", indices)
      score_with_indices.should_not be_nil
      indices.should eq([9_u32, 10_u32, 11_u32, 12_u32])
    end

    it "matches with delimiter boundaries" do
      matcher = Nucleoc::Matcher.new

      # Test: "zshc" in "/man1/zshcompctl.1"
      score = matcher.fuzzy_match("/man1/zshcompctl.1", "zshc")
      score.should_not be_nil

      indices = [] of UInt32
      score_with_indices = matcher.fuzzy_indices("/man1/zshcompctl.1", "zshc", indices)
      score_with_indices.should_not be_nil
      indices.should eq([6_u32, 7_u32, 8_u32, 9_u32])
    end

    it "handles consecutive matches" do
      matcher = Nucleoc::Matcher.new

      # Test: "12356" in "ab0123 456"
      score = matcher.fuzzy_match("ab0123 456", "12356")
      score.should_not be_nil

      indices = [] of UInt32
      score_with_indices = matcher.fuzzy_indices("ab0123 456", "12356", indices)
      score_with_indices.should_not be_nil
      indices.should eq([3_u32, 4_u32, 5_u32, 8_u32, 9_u32])
    end

    it "matches with mixed boundaries" do
      matcher = Nucleoc::Matcher.new

      # Test: "fbb" in "foo/bar/baz"
      score = matcher.fuzzy_match("foo/bar/baz", "fbb")
      score.should_not be_nil

      indices = [] of UInt32
      score_with_indices = matcher.fuzzy_indices("foo/bar/baz", "fbb", indices)
      score_with_indices.should_not be_nil
      indices.should eq([0_u32, 4_u32, 8_u32])
    end
  end

  describe "exact matching" do
    it "matches exact strings" do
      matcher = Nucleoc::Matcher.new

      # Exact match
      score = matcher.exact_match("hello", "hello")
      score.should eq(140)

      indices = [] of UInt32
      score_with_indices = matcher.exact_indices("hello", "hello", indices)
      score_with_indices.should eq(140)
      indices.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])

      # Non-match
      matcher.exact_match("hello", "world").should be_nil

      indices.clear
      matcher.exact_indices("hello", "world", indices).should be_nil
      indices.should be_empty
    end

    it "respects case sensitivity" do
      # Case insensitive by default
      matcher = Nucleoc::Matcher.new
      matcher.exact_match("Hello", "hello").should eq(140)

      # Case sensitive
      config = Nucleoc::Config.new(ignore_case: false)
      matcher2 = Nucleoc::Matcher.new(config)
      matcher2.exact_match("Hello", "hello").should be_nil
      matcher2.exact_match("Hello", "Hello").should eq(140)
    end
  end

  describe "substring matching" do
    it "matches substrings" do
      matcher = Nucleoc::Matcher.new

      # Substring match
      score = matcher.substring_match("hello world", "world")
      score.should_not be_nil
      score.try(&.should(be > 0))

      indices = [] of UInt32
      score_with_indices = matcher.substring_indices("hello world", "world", indices)
      score_with_indices.should_not be_nil
      indices.should eq([6_u32, 7_u32, 8_u32, 9_u32, 10_u32])

      # No match
      matcher.substring_match("hello world", "xyz").should be_nil
    end
  end

  describe "prefix matching" do
    it "matches prefixes" do
      matcher = Nucleoc::Matcher.new

      # Prefix match
      score = matcher.prefix_match("hello world", "hello")
      score.should_not be_nil
      score.try(&.should(be > 0))

      indices = [] of UInt32
      score_with_indices = matcher.prefix_indices("hello world", "hello", indices)
      score_with_indices.should_not be_nil
      indices.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])

      # No match (not at start)
      matcher.prefix_match("hello world", "world").should be_nil
    end
  end

  describe "postfix matching" do
    it "matches postfixes" do
      matcher = Nucleoc::Matcher.new

      # Postfix match
      score = matcher.postfix_match("hello world", "world")
      score.should_not be_nil
      score.try(&.should(be > 0))

      indices = [] of UInt32
      score_with_indices = matcher.postfix_indices("hello world", "world", indices)
      score_with_indices.should_not be_nil
      indices.should eq([6_u32, 7_u32, 8_u32, 9_u32, 10_u32])

      # No match (not at end)
      matcher.postfix_match("hello world", "hello").should be_nil
    end
  end

  describe "edge cases" do
    it "handles empty needle" do
      matcher = Nucleoc::Matcher.new

      # Empty needle should match with score 0
      score = matcher.fuzzy_match("hello world", "")
      score.should eq(0)

      indices = [] of UInt32
      score_with_indices = matcher.fuzzy_indices("hello world", "", indices)
      score_with_indices.should eq(0)
      indices.should be_empty
    end

    it "handles needle longer than haystack" do
      matcher = Nucleoc::Matcher.new

      # Needle longer than haystack should not match
      matcher.fuzzy_match("hello", "hello world").should be_nil
      matcher.exact_match("hello", "hello world").should be_nil
      matcher.substring_match("hello", "hello world").should be_nil
      matcher.prefix_match("hello", "hello world").should be_nil
      matcher.postfix_match("hello", "hello world").should be_nil
    end

    it "handles unicode characters" do
      matcher = Nucleoc::Matcher.new

      # Unicode exact match
      score = matcher.exact_match("café", "café")
      score.should_not be_nil
      score.try(&.should(be > 0))

      # Unicode fuzzy match
      score = matcher.fuzzy_match("café au lait", "café")
      score.should_not be_nil
      score.try(&.should(be > 0))
    end
  end

  describe "scoring parity with Rust" do
    it "has matching scores for basic cases" do
      matcher = Nucleoc::Matcher.new

      # Test 1: Exact match "hello" in "hello" = 140
      score = matcher.exact_match("hello", "hello")
      score.should eq(140)

      # Test 2: Exact match "hello" in "hello world" = nil (not exact match)
      matcher.exact_match("hello world", "hello").should be_nil

      # Test 3: Fuzzy match "hello" in "hello world" = 140
      score = matcher.fuzzy_match("hello world", "hello")
      score.should eq(140)

      # Test 4: Prefix match "^hello" in "hello world" = 140
      score = matcher.prefix_match("hello world", "hello")
      score.should eq(140)
    end
  end

  # Additional tests ported from Rust matcher/tests.rs
  describe "additional Rust tests" do
    it "tests exact match with indices" do
      matcher = Nucleoc::Matcher.new

      # Test exact_match with indices
      indices = [] of UInt32
      score = matcher.exact_indices("hello", "hello", indices)
      score.should eq(140)
      indices.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])
    end

    it "tests fuzzy match with indices" do
      matcher = Nucleoc::Matcher.new

      # Test fuzzy_match with indices
      indices = [] of UInt32
      score = matcher.fuzzy_indices("hello world", "hello", indices)
      score.should eq(140)
      indices.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])
    end

    it "tests prefix match with indices" do
      matcher = Nucleoc::Matcher.new

      # Test prefix_match with indices
      indices = [] of UInt32
      score = matcher.prefix_indices("hello world", "hello", indices)
      score.should eq(140)
      indices.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])
    end

    it "tests substring match with indices" do
      matcher = Nucleoc::Matcher.new

      # Test substring_match with indices
      indices = [] of UInt32
      score = matcher.substring_indices("hello world", "world", indices)
      score.should_not be_nil
      indices.should eq([6_u32, 7_u32, 8_u32, 9_u32, 10_u32])
    end

    it "tests postfix match with indices" do
      matcher = Nucleoc::Matcher.new

      # Test postfix_match with indices
      indices = [] of UInt32
      score = matcher.postfix_indices("hello world", "world", indices)
      score.should_not be_nil
      indices.should eq([6_u32, 7_u32, 8_u32, 9_u32, 10_u32])
    end

    it "tests case sensitivity" do
      # Case insensitive by default
      matcher = Nucleoc::Matcher.new
      matcher.exact_match("Hello", "hello").should eq(140)
      matcher.fuzzy_match("Hello World", "hello").should eq(140)

      # Case sensitive
      config = Nucleoc::Config.new(ignore_case: false)
      matcher2 = Nucleoc::Matcher.new(config)
      matcher2.exact_match("Hello", "hello").should be_nil
      matcher2.exact_match("Hello", "Hello").should eq(140)
    end

    it "tests normalization" do
      matcher = Nucleoc::Matcher.new

      # With normalization (default)
      score1 = matcher.exact_match("café", "cafe\u{0301}")
      score1.should_not be_nil # Should match with normalization

      # Without normalization
      config = Nucleoc::Config.new(normalize: false)
      matcher2 = Nucleoc::Matcher.new(config)
      score2 = matcher2.exact_match("café", "cafe\u{0301}")
      score2.should be_nil # Should not match without normalization
    end

    it "tests boundary bonuses" do
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

    it "tests camel case bonuses" do
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

    it "tests gap penalties" do
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

    it "tests empty needle" do
      matcher = Nucleoc::Matcher.new

      # Empty needle should match with score 0
      matcher.fuzzy_match("hello world", "").should eq(0)
      matcher.exact_match("hello world", "").should eq(0)
      matcher.substring_match("hello world", "").should eq(0)
      matcher.prefix_match("hello world", "").should eq(0)
      matcher.postfix_match("hello world", "").should eq(0)
    end

    it "tests needle longer than haystack" do
      matcher = Nucleoc::Matcher.new

      # Needle longer than haystack should not match
      matcher.fuzzy_match("hello", "hello world").should be_nil
      matcher.exact_match("hello", "hello world").should be_nil
      matcher.substring_match("hello", "hello world").should be_nil
      matcher.prefix_match("hello", "hello world").should be_nil
      matcher.postfix_match("hello", "hello world").should be_nil
    end
  end

  describe "parallel fuzzy matching" do
    it "matches basic fuzzy patterns in parallel" do
      matcher = Nucleoc::Matcher.new
      haystacks = ["fooBarbaz1", "/usr/share/doc/at/ChangeLog", "foo bar baz", "hello world"]
      needle = "obr"

      parallel_scores = matcher.parallel_fuzzy_match(haystacks, needle)
      sequential_scores = haystacks.map { |haystack| matcher.fuzzy_match(haystack, needle) }

      parallel_scores.should eq(sequential_scores)
    end

    it "handles empty array" do
      matcher = Nucleoc::Matcher.new
      matcher.parallel_fuzzy_match([] of String, "needle").should eq([] of UInt16?)
      matcher.parallel_fuzzy_indices([] of String, "needle").should eq([] of Tuple(UInt16, Array(UInt32))?)
    end

    it "handles single item array" do
      matcher = Nucleoc::Matcher.new
      haystacks = ["fooBarbaz1"]
      needle = "obr"

      parallel_scores = matcher.parallel_fuzzy_match(haystacks, needle)
      sequential_score = matcher.fuzzy_match(haystacks[0], needle)
      parallel_scores.should eq([sequential_score])
    end

    it "matches with indices in parallel" do
      matcher = Nucleoc::Matcher.new
      haystacks = ["fooBarbaz1", "/usr/share/doc/at/ChangeLog", "foo bar baz", "hello world"]
      needle = "obr"

      parallel_results = matcher.parallel_fuzzy_indices(haystacks, needle)
      sequential_results = haystacks.map do |haystack|
        indices = [] of UInt32
        score = matcher.fuzzy_indices(haystack, needle, indices)
        score ? {score, indices} : nil
      end

      parallel_results.should eq(sequential_results)
    end

    it "respects chunk size parameter" do
      matcher = Nucleoc::Matcher.new
      haystacks = ["fooBarbaz1", "/usr/share/doc/at/ChangeLog", "foo bar baz", "hello world", "test", "another"]
      needle = "obr"

      # Use chunk size 2 (should create 3 chunks)
      parallel_scores = matcher.parallel_fuzzy_match(haystacks, needle, chunk_size: 2)
      sequential_scores = haystacks.map { |haystack| matcher.fuzzy_match(haystack, needle) }

      parallel_scores.should eq(sequential_scores)
    end

    it "scales with many items" do
      matcher = Nucleoc::Matcher.new
      # Create 1000 haystacks with predictable pattern
      haystacks = Array.new(1000) { |i| "haystack#{i}" }
      needle = "hay"

      parallel_scores = matcher.parallel_fuzzy_match(haystacks, needle)
      # Don't test all, just ensure we got correct number of results
      parallel_scores.size.should eq(1000)
      parallel_scores.each do |score|
        score.should_not be_nil
      end
    end
  end
end
