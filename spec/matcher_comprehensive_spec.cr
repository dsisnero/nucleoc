require "./spec_helper"
require "../src/nucleoc"

describe Nucleoc::Matcher do
  # Port of test_fuzzy from Rust tests.rs
  describe "test_fuzzy" do
    it "matches fuzzy patterns with correct scores" do
      matcher = Nucleoc::Matcher.new

      # Test cases from Rust test_fuzzy
      # Note: We need to verify the exact scores match Rust implementation

      # Test 1: "obr" in "fooBarbaz1"
      indices = [] of UInt32
      score = matcher.fuzzy_indices("fooBarbaz1", "obr", indices)
      score.should_not be_nil
      indices.should eq([2_u32, 3_u32, 5_u32])

      # Test 2: "changelog" in "/usr/share/doc/at/ChangeLog"
      indices.clear
      score = matcher.fuzzy_indices("/usr/share/doc/at/ChangeLog", "changelog", indices)
      score.should_not be_nil
      indices.should eq([18_u32, 19_u32, 20_u32, 21_u32, 22_u32, 23_u32, 24_u32, 25_u32, 26_u32])

      # Test 3: "br" in "fooBarbaz1"
      indices.clear
      score = matcher.fuzzy_indices("fooBarbaz1", "br", indices)
      score.should_not be_nil
      indices.should eq([3_u32, 5_u32])

      # Test 4: "fbb" in "foo bar baz"
      indices.clear
      score = matcher.fuzzy_indices("foo bar baz", "fbb", indices)
      score.should_not be_nil
      indices.should eq([0_u32, 4_u32, 8_u32])

      # Test 5: "rdoc" in "/AutomatorDocument.icns"
      indices.clear
      score = matcher.fuzzy_indices("/AutomatorDocument.icns", "rdoc", indices)
      score.should_not be_nil
      indices.should eq([9_u32, 10_u32, 11_u32, 12_u32])

      # Test 6: "zshc" in "/man1/zshcompctl.1"
      indices.clear
      score = matcher.fuzzy_indices("/man1/zshcompctl.1", "zshc", indices)
      score.should_not be_nil
      indices.should eq([6_u32, 7_u32, 8_u32, 9_u32])

      # Test 7: "zshc" in "/.oh-my-zsh/cache"
      indices.clear
      score = matcher.fuzzy_indices("/.oh-my-zsh/cache", "zshc", indices)
      score.should_not be_nil
      indices.should eq([8_u32, 9_u32, 10_u32, 12_u32])

      # Test 8: "12356" in "ab0123 456"
      indices.clear
      score = matcher.fuzzy_indices("ab0123 456", "12356", indices)
      score.should_not be_nil
      indices.should eq([3_u32, 4_u32, 5_u32, 8_u32, 9_u32])

      # Test 9: "12356" in "abc123 456"
      indices.clear
      score = matcher.fuzzy_indices("abc123 456", "12356", indices)
      score.should_not be_nil
      indices.should eq([3_u32, 4_u32, 5_u32, 8_u32, 9_u32])
    end
  end

  # Port of test_fuzzy_unicode from Rust tests.rs
  describe "test_fuzzy_unicode" do
    it "handles unicode characters correctly" do
      matcher = Nucleoc::Matcher.new

      # Test with unicode characters
      indices = [] of UInt32
      score = matcher.fuzzy_indices("aü", "a", indices)
      score.should_not be_nil
      indices.should eq([0_u32])

      indices.clear
      score = matcher.fuzzy_indices("aü", "ü", indices)
      score.should_not be_nil
      indices.should eq([1_u32])
    end
  end

  # Port of test_fuzzy_case from Rust tests.rs
  describe "test_fuzzy_case" do
    it "handles case sensitivity correctly" do
      # Case insensitive by default
      matcher = Nucleoc::Matcher.new

      indices = [] of UInt32
      score = matcher.fuzzy_indices("FooBar", "fb", indices)
      score.should_not be_nil
      indices.should eq([0_u32, 3_u32])

      # Case sensitive
      config = Nucleoc::Config.new(ignore_case: false)
      matcher2 = Nucleoc::Matcher.new(config)

      indices.clear
      score = matcher2.fuzzy_indices("FooBar", "FB", indices)
      score.should_not be_nil
      indices.should eq([0_u32, 3_u32])
    end
  end

  # Port of test_fuzzy_normalize from Rust tests.rs
  describe "test_fuzzy_normalize" do
    it "handles normalization correctly" do
      # With normalization enabled (default)
      matcher = Nucleoc::Matcher.new

      # Test with decomposed unicode
      indices = [] of UInt32
      score = matcher.fuzzy_indices("cafe\u{0301}", "café", indices)
      score.should_not be_nil
      # Should match despite different normalization forms
    end
  end

  # Port of test_fuzzy_greedy from Rust tests.rs
  describe "test_fuzzy_greedy" do
    it "matches with greedy algorithm" do
      matcher = Nucleoc::Matcher.new

      # Test greedy matching
      indices = [] of UInt32
      score = matcher.fuzzy_indices_greedy("fooBarbaz1", "obr", indices)
      score.should_not be_nil
      indices.should eq([2_u32, 3_u32, 5_u32])
    end
  end

  # Port of test_substring from Rust tests.rs
  describe "test_substring" do
    it "matches substrings correctly" do
      matcher = Nucleoc::Matcher.new

      indices = [] of UInt32
      score = matcher.substring_indices("hello world", "world", indices)
      score.should_not be_nil
      indices.should eq([6_u32, 7_u32, 8_u32, 9_u32, 10_u32])

      indices.clear
      score = matcher.substring_indices("foo bar baz", "bar", indices)
      score.should_not be_nil
      indices.should eq([4_u32, 5_u32, 6_u32])
    end
  end

  # Port of test_prefix from Rust tests.rs
  describe "test_prefix" do
    it "matches prefixes correctly" do
      matcher = Nucleoc::Matcher.new

      indices = [] of UInt32
      score = matcher.prefix_indices("hello world", "hello", indices)
      score.should_not be_nil
      indices.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])

      # Should not match if not at start
      indices.clear
      score = matcher.prefix_indices("hello world", "world", indices)
      score.should be_nil
    end
  end

  # Port of test_postfix from Rust tests.rs
  describe "test_postfix" do
    it "matches postfixes correctly" do
      matcher = Nucleoc::Matcher.new

      indices = [] of UInt32
      score = matcher.postfix_indices("hello world", "world", indices)
      score.should_not be_nil
      indices.should eq([6_u32, 7_u32, 8_u32, 9_u32, 10_u32])

      # Should not match if not at end
      indices.clear
      score = matcher.postfix_indices("hello world", "hello", indices)
      score.should be_nil
    end
  end

  # Port of test_exact from Rust tests.rs
  describe "test_exact" do
    it "matches exact strings correctly" do
      matcher = Nucleoc::Matcher.new

      indices = [] of UInt32
      score = matcher.exact_indices("hello", "hello", indices)
      score.should eq(140)
      indices.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])

      # Case insensitive by default
      indices.clear
      score = matcher.exact_indices("Hello", "hello", indices)
      score.should eq(140)
      indices.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])
    end
  end

  # Port of test_not_matches from Rust tests.rs
  describe "test_not_matches" do
    it "correctly identifies non-matches" do
      matcher = Nucleoc::Matcher.new

      # Should not match
      matcher.fuzzy_match("hello", "xyz").should be_nil
      matcher.substring_match("hello", "xyz").should be_nil
      matcher.prefix_match("hello", "xyz").should be_nil
      matcher.postfix_match("hello", "xyz").should be_nil
      matcher.exact_match("hello", "xyz").should be_nil
    end
  end

  # Port of test_prefer_prefix from Rust tests.rs
  describe "test_prefer_prefix" do
    it "prefers prefix matches when configured" do
      config = Nucleoc::Config.new(prefer_prefix: true)
      matcher = Nucleoc::Matcher.new(config)

      # With prefer_prefix, matches at the beginning should get bonus
      indices = [] of UInt32
      score1 = matcher.fuzzy_indices("foo bar baz", "fbb", indices)
      score1.should_not be_nil

      indices.clear
      score2 = matcher.fuzzy_indices("xfoo bar baz", "fbb", indices)
      score2.should_not be_nil

      # score1 should be higher than score2 because it starts at the beginning
      score1.try do |score1_value|
        score2.try { |score2_value| score1_value.should be > score2_value }
      end
    end
  end

  # Port of test_path from Rust tests.rs
  describe "test_path" do
    it "handles path matching correctly" do
      config = Nucleoc::Config.new.match_paths
      matcher = Nucleoc::Matcher.new(config)

      # Path matching should give bonus to matches after path separators
      indices = [] of UInt32
      score = matcher.fuzzy_indices("/usr/bin/bash", "bash", indices)
      score.should_not be_nil
      # Should match at the end of the path
    end
  end

  # Port of test_empty from Rust tests.rs
  describe "test_empty" do
    it "handles empty needle correctly" do
      matcher = Nucleoc::Matcher.new

      # Empty needle should match with score 0
      score = matcher.fuzzy_match("hello world", "")
      score.should eq(0)

      indices = [] of UInt32
      score_with_indices = matcher.fuzzy_indices("hello world", "", indices)
      score_with_indices.should eq(0)
      indices.should be_empty
    end
  end

  # Port of test_long_needle from Rust tests.rs
  describe "test_long_needle" do
    it "handles needle longer than haystack correctly" do
      matcher = Nucleoc::Matcher.new

      # Needle longer than haystack should not match
      matcher.fuzzy_match("hello", "hello world").should be_nil
      matcher.exact_match("hello", "hello world").should be_nil
      matcher.substring_match("hello", "hello world").should be_nil
      matcher.prefix_match("hello", "hello world").should be_nil
      matcher.postfix_match("hello", "hello world").should be_nil
    end
  end

  # Tests covering example files from nucleo_rust/examples/
  # Port of: nucleo_rust/examples/simple_rust_test.rs
  describe "example file tests" do
    it "covers simple_rust_test.rs example cases" do
      matcher = Nucleoc::Matcher.new

      # Test 1: Exact match "hello" in "hello"
      score1 = matcher.exact_match("hello", "hello")
      score1.should eq(140)

      # Test 2: Exact match "hello" in "hello world"
      score2 = matcher.exact_match("hello world", "hello")
      score2.should be_nil # Not an exact match since "hello" != "hello world"

      # Test 3: Fuzzy match "hello" in "hello world"
      score3 = matcher.fuzzy_match("hello world", "hello")
      score3.should_not be_nil
      score3.try(&.should(be > 0))
    end

    # Port of: nucleo_rust/examples/test_rust_exact_whitespace.rs
    it "covers test_rust_exact_whitespace.rs example cases" do
      matcher = Nucleoc::Matcher.new

      # Test cases from the example
      test_cases = [
        {"hello", "hello"},
        {"  hello  ", "hello"},
        {"hello world", "hello"},
        {"  hello world  ", "hello"},
      ]

      test_cases.each do |haystack, needle|
        score = matcher.exact_match(haystack, needle)
        # Only the first case should match exactly
        if haystack == "hello" && needle == "hello"
          score.should eq(140)
        else
          score.should be_nil # Not exact matches due to whitespace or extra text
        end
      end
    end

    # Port of: nucleo_rust/examples/test_hello.rs
    it "covers test_hello.rs example cases" do
      matcher = Nucleoc::Matcher.new

      # Exact match tests from example
      exact1 = matcher.exact_match("hello", "hello")
      exact1.should eq(140)

      exact2 = matcher.exact_match("hello world", "hello world")
      exact2.should eq(296)

      # Fuzzy match tests from example
      fuzzy1 = matcher.fuzzy_match("hello", "hello")
      fuzzy1.should eq(140)

      fuzzy2 = matcher.fuzzy_match("hello world", "hello")
      fuzzy2.should_not be_nil
      fuzzy2.try(&.should(be > 0))

      fuzzy3 = matcher.fuzzy_match("hello there world", "hello")
      fuzzy3.should_not be_nil
      fuzzy3.try(&.should(be > 0))

      # Test with pattern "hell"
      fuzzy_hell1 = matcher.fuzzy_match("hello", "hell")
      fuzzy_hell1.should_not be_nil
      fuzzy_hell1.try(&.should(be > 0))

      fuzzy_hell2 = matcher.fuzzy_match("hello world", "hell")
      fuzzy_hell2.should_not be_nil
      fuzzy_hell2.try(&.should(be > 0))

      fuzzy_hell3 = matcher.fuzzy_match("hell", "hell")
      fuzzy_hell3.should_not be_nil # Should match, exact score depends on bonuses

      fuzzy_hell4 = matcher.fuzzy_match("shell", "hell")
      fuzzy_hell4.should_not be_nil
      fuzzy_hell4.try(&.should(be > 0))

      # Test with pattern "world"
      fuzzy_world1 = matcher.fuzzy_match("hello world", "world")
      fuzzy_world1.should_not be_nil
      fuzzy_world1.try(&.should(be > 0))

      fuzzy_world2 = matcher.fuzzy_match("world", "world")
      fuzzy_world2.should eq(140) # 5 chars * 28 = 140

      fuzzy_world3 = matcher.fuzzy_match("world hello", "world")
      fuzzy_world3.should_not be_nil
      fuzzy_world3.try(&.should(be > 0))

      fuzzy_world4 = matcher.fuzzy_match("wor ld", "world")
      fuzzy_world4.should_not be_nil # Fuzzy match can skip spaces
      fuzzy_world4.try(&.should(be > 0))

      # Test with pattern "he"
      fuzzy_he1 = matcher.fuzzy_match("hello", "he")
      fuzzy_he1.should eq(62) # 2 chars with bonus

      fuzzy_he2 = matcher.fuzzy_match("hello world", "he")
      fuzzy_he2.should eq(62)

      fuzzy_he4 = matcher.fuzzy_match("he", "he")
      fuzzy_he4.should eq(62)
    end
  end
end
