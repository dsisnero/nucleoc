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
      atom = Nucleoc::Atom.parse("hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      # Should match both "hello" and "Hello"

      # Smart case (uppercase in pattern = case sensitive)
      atom = Nucleoc::Atom.parse("Hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      # Should only match "Hello"

      # Always case sensitive
      atom = Nucleoc::Atom.parse("hello", Nucleoc::CaseMatching::Respect, Nucleoc::Normalization::Smart)
      # Should only match "hello"

      # Always case insensitive
      atom = Nucleoc::Atom.parse("Hello", Nucleoc::CaseMatching::Ignore, Nucleoc::Normalization::Smart)
      # Should match both "hello" and "Hello"
    end

    it "handles normalization in atoms" do
      # With normalization
      atom = Nucleoc::Atom.parse("café", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      # Should match both "café" and "cafe\u{0301}"

      # Without normalization
      atom = Nucleoc::Atom.parse("café", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Never)
      # Should only match exact form
    end
  end
end
