require "./spec_helper"
require "../src/nucleoc"

describe Nucleoc::Pattern do
  describe "Pattern parsing" do
    it "parses simple patterns" do
      pattern = Nucleoc::Pattern.parse("hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pattern.should_not be_nil
      pattern.atoms.size.should eq(1)
      pattern.atoms[0].kind.should eq(Nucleoc::AtomKind::Fuzzy)
      pattern.atoms[0].negative?.should be_false
    end

    it "parses exact patterns" do
      pattern = Nucleoc::Pattern.parse("^hello$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pattern.should_not be_nil
      pattern.atoms.size.should eq(1)
      pattern.atoms[0].kind.should eq(Nucleoc::AtomKind::Exact)
      pattern.atoms[0].negative?.should be_false
    end

    it "parses prefix patterns" do
      pattern = Nucleoc::Pattern.parse("^hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pattern.should_not be_nil
      pattern.atoms.size.should eq(1)
      pattern.atoms[0].kind.should eq(Nucleoc::AtomKind::Prefix)
      pattern.atoms[0].negative?.should be_false
    end

    it "parses postfix patterns" do
      pattern = Nucleoc::Pattern.parse("hello$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pattern.should_not be_nil
      pattern.atoms.size.should eq(1)
      pattern.atoms[0].kind.should eq(Nucleoc::AtomKind::Postfix)
      pattern.atoms[0].negative?.should be_false
    end

    it "parses substring patterns" do
      pattern = Nucleoc::Pattern.parse("'hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pattern.should_not be_nil
      pattern.atoms.size.should eq(1)
      pattern.atoms[0].kind.should eq(Nucleoc::AtomKind::Substring)
      pattern.atoms[0].negative?.should be_false
    end

    it "parses negative patterns" do
      pattern = Nucleoc::Pattern.parse("!hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pattern.should_not be_nil
      pattern.atoms.size.should eq(1)
      pattern.atoms[0].negative?.should be_true
      pattern.atoms[0].kind.should eq(Nucleoc::AtomKind::Substring)
    end

    it "parses multi-atom patterns" do
      pattern = Nucleoc::Pattern.parse("hello world", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pattern.should_not be_nil
      pattern.atoms.size.should eq(2)
      pattern.atoms[0].kind.should eq(Nucleoc::AtomKind::Fuzzy)
      pattern.atoms[1].kind.should eq(Nucleoc::AtomKind::Fuzzy)
    end

    it "parses mixed pattern types" do
      pattern = Nucleoc::Pattern.parse("^hello !world", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pattern.should_not be_nil
      pattern.atoms.size.should eq(2)
      pattern.atoms[0].kind.should eq(Nucleoc::AtomKind::Prefix)
      pattern.atoms[1].kind.should eq(Nucleoc::AtomKind::Substring)
    end
  end

  describe "Pattern matching" do
    it "matches simple patterns" do
      pattern = Nucleoc::Pattern.parse("hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      matcher = Nucleoc::Matcher.new

      score = pattern.match(matcher, "hello world")
      score.should_not be_nil
      score.not_nil!.should be > 0
    end

    it "matches exact patterns" do
      pattern = Nucleoc::Pattern.parse("^hello$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      matcher = Nucleoc::Matcher.new

      # Exact match should work
      score = pattern.match(matcher, "hello")
      score.should_not be_nil

      # Not exact match should fail
      score = pattern.match(matcher, "hello world")
      score.should be_nil
    end

    it "matches prefix patterns" do
      pattern = Nucleoc::Pattern.parse("^hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      matcher = Nucleoc::Matcher.new

      # Prefix match should work
      score = pattern.match(matcher, "hello world")
      score.should_not be_nil

      # Not at prefix should fail
      score = pattern.match(matcher, "world hello")
      score.should be_nil
    end

    it "matches postfix patterns" do
      pattern = Nucleoc::Pattern.parse("hello$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      matcher = Nucleoc::Matcher.new

      # Postfix match should work
      score = pattern.match(matcher, "world hello")
      score.should_not be_nil

      # Not at postfix should fail
      score = pattern.match(matcher, "hello world")
      score.should be_nil
    end

    it "matches substring patterns" do
      pattern = Nucleoc::Pattern.parse("'hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      matcher = Nucleoc::Matcher.new

      # Substring match should work anywhere
      score = pattern.match(matcher, "world hello")
      score.should_not be_nil

      score = pattern.match(matcher, "hello world")
      score.should_not be_nil

      score = pattern.match(matcher, "say hello world")
      score.should_not be_nil
    end

    it "matches multi-atom patterns" do
      pattern = Nucleoc::Pattern.parse("hello world", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      matcher = Nucleoc::Matcher.new

      # Both atoms must match
      score = pattern.match(matcher, "hello beautiful world")
      score.should_not be_nil

      # Missing one atom should fail
      score = pattern.match(matcher, "hello universe")
      score.should be_nil
    end

    it "returns indices when requested" do
      pattern = Nucleoc::Pattern.parse("hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      matcher = Nucleoc::Matcher.new

      indices = [] of Array(UInt32)
      score = pattern.match(matcher, "hello world", indices)
      score.should_not be_nil
      indices.size.should eq(1)
      indices[0].should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32])
    end
  end

  describe "Atom parsing" do
    it "parses atom strings correctly" do
      # Test Atom.parse directly
      atom = Nucleoc::Atom.parse("hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.kind.should eq(Nucleoc::AtomKind::Fuzzy)
      atom.negative?.should be_false

      atom = Nucleoc::Atom.parse("!hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.kind.should eq(Nucleoc::AtomKind::Substring)
      atom.negative?.should be_true

      atom = Nucleoc::Atom.parse("^hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.kind.should eq(Nucleoc::AtomKind::Prefix)
      atom.negative?.should be_false

      atom = Nucleoc::Atom.parse("hello$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.kind.should eq(Nucleoc::AtomKind::Postfix)
      atom.negative?.should be_false

      atom = Nucleoc::Atom.parse("'hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.kind.should eq(Nucleoc::AtomKind::Substring)
      atom.negative?.should be_false
    end

    it "handles case matching in atoms" do
      # Smart case (lowercase pattern = case insensitive)
      atom1 = Nucleoc::Atom.parse("hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom1.ignore_case?.should be_true

      # Smart case (uppercase in pattern = case sensitive)
      atom2 = Nucleoc::Atom.parse("Hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom2.ignore_case?.should be_false

      # Always case sensitive
      atom3 = Nucleoc::Atom.parse("hello", Nucleoc::CaseMatching::Respect, Nucleoc::Normalization::Smart)
      atom3.ignore_case?.should be_false

      # Always case insensitive
      atom4 = Nucleoc::Atom.parse("Hello", Nucleoc::CaseMatching::Ignore, Nucleoc::Normalization::Smart)
      atom4.ignore_case?.should be_true
    end

    it "handles normalization in atoms" do
      # With normalization
      atom1 = Nucleoc::Atom.parse("café", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom1.normalize?.should be_true

      # Without normalization
      atom2 = Nucleoc::Atom.parse("café", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Never)
      atom2.normalize?.should be_false
    end

    it "handles escape sequences correctly" do
      # Port of escape() test from Rust pattern/tests.rs

      # Test 1: "foo\\ bar" -> "foo bar"
      atom = Nucleoc::Atom.parse("foo\\ bar", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.needle.to_s.should eq("foo bar")

      # Test 2: "\\!foo" -> "!foo" (AtomKind::Fuzzy)
      atom = Nucleoc::Atom.parse("\\!foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.needle.to_s.should eq("!foo")
      atom.kind.should eq(Nucleoc::AtomKind::Fuzzy)

      # Test 3: "\\'foo" -> "'foo" (AtomKind::Fuzzy)
      atom = Nucleoc::Atom.parse("\\'foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.needle.to_s.should eq("'foo")
      atom.kind.should eq(Nucleoc::AtomKind::Fuzzy)

      # Test 4: "\\^foo" -> "^foo" (AtomKind::Fuzzy)
      atom = Nucleoc::Atom.parse("\\^foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.needle.to_s.should eq("^foo")
      atom.kind.should eq(Nucleoc::AtomKind::Fuzzy)

      # Test 5: "foo\\$" -> "foo$" (AtomKind::Fuzzy)
      atom = Nucleoc::Atom.parse("foo\\$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.needle.to_s.should eq("foo$")
      atom.kind.should eq(Nucleoc::AtomKind::Fuzzy)

      # Test 6: "^foo\\$" -> "foo$" (AtomKind::Prefix)
      atom = Nucleoc::Atom.parse("^foo\\$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.needle.to_s.should eq("foo$")
      atom.kind.should eq(Nucleoc::AtomKind::Prefix)

      # Test 7: "\\^foo\\$" -> "^foo$" (AtomKind::Fuzzy)
      atom = Nucleoc::Atom.parse("\\^foo\\$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.needle.to_s.should eq("^foo$")
      atom.kind.should eq(Nucleoc::AtomKind::Fuzzy)

      # Test 8: "\\!^foo\\$" -> "!^foo$" (AtomKind::Fuzzy)
      atom = Nucleoc::Atom.parse("\\!^foo\\$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.needle.to_s.should eq("!^foo$")
      atom.kind.should eq(Nucleoc::AtomKind::Fuzzy)

      # Test 9: "!\\^foo\\$" -> "^foo$" (AtomKind::Substring)
      atom = Nucleoc::Atom.parse("!\\^foo\\$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      atom.needle.to_s.should eq("^foo$")
      atom.kind.should eq(Nucleoc::AtomKind::Substring)
      atom.negative?.should be_true
    end
  end

  describe "Comprehensive pattern tests (from Rust)" do
    it "negative() test from Rust" do
      # Test 1: "!foo" -> negative substring
      pat = Nucleoc::Atom.parse("!foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.negative?.should be_true
      pat.kind.should eq(Nucleoc::AtomKind::Substring)
      pat.needle.to_s.should eq("foo")

      # Test 2: "!^foo" -> negative prefix
      pat = Nucleoc::Atom.parse("!^foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.negative?.should be_true
      pat.kind.should eq(Nucleoc::AtomKind::Prefix)
      pat.needle.to_s.should eq("foo")

      # Test 3: "!foo$" -> negative postfix
      pat = Nucleoc::Atom.parse("!foo$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.negative?.should be_true
      pat.kind.should eq(Nucleoc::AtomKind::Postfix)
      pat.needle.to_s.should eq("foo")

      # Test 4: "!^foo$" -> negative exact
      pat = Nucleoc::Atom.parse("!^foo$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.negative?.should be_true
      pat.kind.should eq(Nucleoc::AtomKind::Exact)
      pat.needle.to_s.should eq("foo")
    end

    it "pattern_kinds() test from Rust" do
      # Test fuzzy
      pat = Nucleoc::Atom.parse("foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.negative?.should be_false
      pat.kind.should eq(Nucleoc::AtomKind::Fuzzy)
      pat.needle.to_s.should eq("foo")

      # Test substring
      pat = Nucleoc::Atom.parse("'foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.negative?.should be_false
      pat.kind.should eq(Nucleoc::AtomKind::Substring)
      pat.needle.to_s.should eq("foo")

      # Test prefix
      pat = Nucleoc::Atom.parse("^foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.negative?.should be_false
      pat.kind.should eq(Nucleoc::AtomKind::Prefix)
      pat.needle.to_s.should eq("foo")

      # Test postfix
      pat = Nucleoc::Atom.parse("foo$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.negative?.should be_false
      pat.kind.should eq(Nucleoc::AtomKind::Postfix)
      pat.needle.to_s.should eq("foo")

      # Test exact
      pat = Nucleoc::Atom.parse("^foo$", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.negative?.should be_false
      pat.kind.should eq(Nucleoc::AtomKind::Exact)
      pat.needle.to_s.should eq("foo")
    end

    it "case_matching() test from Rust" do
      # Smart case: lowercase pattern -> case insensitive
      pat = Nucleoc::Atom.parse("foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_true
      pat.needle.to_s.should eq("foo")

      # Smart case: uppercase in pattern -> case sensitive
      pat = Nucleoc::Atom.parse("Foo", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_false
      pat.needle.to_s.should eq("Foo")

      # Ignore mode: always case insensitive
      pat = Nucleoc::Atom.parse("Foo", Nucleoc::CaseMatching::Ignore, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_true
      pat.needle.to_s.should eq("foo")

      # Respect mode: always case sensitive
      pat = Nucleoc::Atom.parse("Foo", Nucleoc::CaseMatching::Respect, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_false
      pat.needle.to_s.should eq("Foo")

      # Unicode: Äxx with Ignore -> lowercased to äxx
      pat = Nucleoc::Atom.parse("Äxx", Nucleoc::CaseMatching::Ignore, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_true
      pat.needle.to_s.should eq("äxx")

      # Unicode: Äxx with Respect -> case sensitive, preserves Äxx
      pat = Nucleoc::Atom.parse("Äxx", Nucleoc::CaseMatching::Respect, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_false

      # Smart case with ASCII uppercase A -> case sensitive
      pat = Nucleoc::Atom.parse("Axx", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_false
      pat.needle.to_s.should eq("Axx")

      # Chinese character "你" (no case) -> Smart treats as lowercase (case insensitive)
      pat = Nucleoc::Atom.parse("你xx", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_true
      pat.needle.to_s.should eq("你xx")

      # Chinese character with Ignore -> case insensitive (same)
      pat = Nucleoc::Atom.parse("你xx", Nucleoc::CaseMatching::Ignore, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_true
      pat.needle.to_s.should eq("你xx")

      # Coptic capital letter Ⲽ -> Smart sees uppercase -> case sensitive
      pat = Nucleoc::Atom.parse("Ⲽxx", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_false
      pat.needle.to_s.should eq("Ⲽxx")

      # Coptic with Ignore -> lowercased to ⲽxx
      pat = Nucleoc::Atom.parse("Ⲽxx", Nucleoc::CaseMatching::Ignore, Nucleoc::Normalization::Smart)
      pat.ignore_case?.should be_true
      pat.needle.to_s.should eq("ⲽxx")
    end

    it "pattern_atoms() test from Rust" do
      # Simple whitespace separation
      pattern = Nucleoc::Pattern.parse("a b", Nucleoc::CaseMatching::Ignore, Nucleoc::Normalization::Smart)
      pattern.atoms.size.should eq(2)
      pattern.atoms[0].needle.to_s.should eq("a")
      pattern.atoms[1].needle.to_s.should eq("b")

      # Newline separation
      pattern = Nucleoc::Pattern.parse("a\n b", Nucleoc::CaseMatching::Ignore, Nucleoc::Normalization::Smart)
      pattern.atoms.size.should eq(2)
      pattern.atoms[0].needle.to_s.should eq("a")
      pattern.atoms[1].needle.to_s.should eq("b")

      # Whitespace trimming and carriage return
      pattern = Nucleoc::Pattern.parse("  a b\r\n", Nucleoc::CaseMatching::Ignore, Nucleoc::Normalization::Smart)
      pattern.atoms.size.should eq(2)
      pattern.atoms[0].needle.to_s.should eq("a")
      pattern.atoms[1].needle.to_s.should eq("b")

      # Japanese full-width space (U+3000) separation
      pattern = Nucleoc::Pattern.parse("ほ　げ", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      pattern.atoms.size.should eq(2)
      pattern.atoms[0].needle.to_s.should eq("ほ")
      pattern.atoms[1].needle.to_s.should eq("げ")
    end
  end
end
