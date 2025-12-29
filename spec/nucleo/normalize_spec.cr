require "../spec_helper"
require "../../src/nucleoc"

describe Nucleoc::Chars do
  describe "normalize" do
    it "performs general conversions" do
      pairs = [
        {'ą', 'a'},
        {'À', 'A'},
        {'ć', 'c'},
        {'ę', 'e'},
        {'ł', 'l'},
        {'ń', 'n'},
        {'ó', 'o'},
        {'ś', 's'},
        {'ź', 'z'},
        {'ż', 'z'},
        {'Ą', 'A'},
        {'Ć', 'C'},
        {'Ę', 'E'},
        {'ł', 'l'},
        {'Ł', 'L'},
        {'Ń', 'N'},
        {'Ó', 'O'},
        {'Ś', 'S'},
        {'Ź', 'Z'},
        {'Ż', 'Z'},
        {'¡', '!'},
      ]
      pairs.each do |original, normalized|
        Nucleoc::Chars.normalize(original, Nucleoc::Config::DEFAULT).should eq(normalized), "normalize('#{original.inspect}') should equal '#{normalized.inspect}'"
      end
    end

    it "handles invisible characters" do
      pairs = [
        {'\u{a0}', '\u{a0}'},
        {'\u{ad}', '\u{ad}'},
      ]
      pairs.each do |original, normalized|
        Nucleoc::Chars.normalize(original, Nucleoc::Config::DEFAULT).should eq(normalized), "normalize('#{original.inspect}') should equal '#{normalized.inspect}'"
      end
    end

    it "handles boundary cases" do
      pairs = [
        {'\u{9f}', '\u{9f}'},
        {'\u{a0}', '\u{a0}'},
        {'¡', '!'},
        {'ʟ', 'L'},
        {'\u{2a0}', '\u{2a0}'},
        {'\u{1dff}', '\u{1dff}'},
        {'Ḁ', 'A'},
        {'ỹ', 'y'},
        {'\u{1eff}', '\u{1eff}'},
        {'\u{1f00}', '\u{1f00}'},
        {'⁰', '0'},
        {'\u{209c}', 't'},
        {'\u{209f}', '\u{209f}'},
        {'\u{20a0}', '\u{20a0}'},
      ]
      pairs.each do |original, normalized|
        Nucleoc::Chars.normalize(original, Nucleoc::Config::DEFAULT).should eq(normalized), "normalize('#{original.inspect}') should equal '#{normalized.inspect}'"
      end
    end

    it "leaves characters outside blocks unchanged" do
      pairs = [
        {'a', 'a'},
        {'⟁', '⟁'},
        {'┍', '┍'},
        {'ω', 'ω'},
        {'⁕', '⁕'},
        {'ה', 'ה'},
      ]
      pairs.each do |original, normalized|
        Nucleoc::Chars.normalize(original, Nucleoc::Config::DEFAULT).should eq(normalized), "normalize('#{original.inspect}') should equal '#{normalized.inspect}'"
      end
    end
  end
end
