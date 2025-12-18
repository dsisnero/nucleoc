require "./spec_helper"
require "../src/nucleoc"

describe Nucleoc::Utf32Str do
  describe "ASCII detection" do
    it "correctly identifies ASCII strings" do
      # Port of test_utf32str_ascii from Rust

      # ASCII strings
      Nucleoc::Utf32Str.new("").ascii?.should be_true
      Nucleoc::Utf32Str.new("a").ascii?.should be_true
      Nucleoc::Utf32Str.new("a\nb").ascii?.should be_true
      Nucleoc::Utf32Str.new("\n\r").ascii?.should be_true

      # Non-ASCII strings
      Nucleoc::Utf32Str.new("aü").ascii?.should be_false
      Nucleoc::Utf32Str.new("au\u{0308}").ascii?.should be_false

      # Windows-style newline (CRLF) is not ASCII in this context
      Nucleoc::Utf32Str.new("a\r\nb").ascii?.should be_false
      Nucleoc::Utf32Str.new("ü\r\n").ascii?.should be_false
      Nucleoc::Utf32Str.new("\r\n").ascii?.should be_false
    end

    it "works with Utf32String as well" do
      # Test with Utf32String
      Nucleoc::Utf32String.from("").slice.ascii?.should be_true
      Nucleoc::Utf32String.from("a").slice.ascii?.should be_true
      Nucleoc::Utf32String.from("aü").slice.ascii?.should be_false
    end
  end

  describe "Grapheme truncation" do
    it "preserves ASCII characters" do
      # Port of test_grapheme_truncation from Rust

      s = Nucleoc::Utf32String.from("ab")
      s.slice.get(0).should eq('a')
      s.slice.get(1).should eq('b')
    end

    it "truncates Windows-style newline to LF" do
      s = Nucleoc::Utf32String.from("\r\n")
      s.slice.get(0).should eq('\n')
    end

    it "truncates normal graphemes to first character" do
      s = Nucleoc::Utf32String.from("u\u{0308}\r\n")
      s.slice.get(0).should eq('u')
      s.slice.get(1).should eq('\n')
    end
  end

  describe "Character access" do
    it "accesses characters by index" do
      str = Nucleoc::Utf32Str.new("hello")
      str.get(0).should eq('h')
      str.get(1).should eq('e')
      str.get(2).should eq('l')
      str.get(3).should eq('l')
      str.get(4).should eq('o')
    end

    it "handles unicode characters correctly" do
      str = Nucleoc::Utf32Str.new("café")
      str.get(0).should eq('c')
      str.get(1).should eq('a')
      str.get(2).should eq('f')
      str.get(3).should eq('é')
    end

    it "returns nil for out of bounds indices" do
      str = Nucleoc::Utf32Str.new("hello")
      str.get(5).should be_nil
      str.get(-1).should be_nil
    end
  end

  describe "Length and iteration" do
    it "returns correct length" do
      Nucleoc::Utf32Str.new("").len.should eq(0)
      Nucleoc::Utf32Str.new("hello").len.should eq(5)
      Nucleoc::Utf32Str.new("café").len.should eq(4)
    end

    it "iterates over characters" do
      str = Nucleoc::Utf32Str.new("hello")
      chars = [] of Char
      str.each { |c| chars << c }
      chars.should eq(['h', 'e', 'l', 'l', 'o'])
    end

    it "converts to array of characters" do
      str = Nucleoc::Utf32Str.new("hello")
      str.chars.should eq(['h', 'e', 'l', 'l', 'o'])
    end
  end

  describe "Encoding and decoding" do
    it "encodes strings to UTF-32" do
      encoded = Nucleoc::Utf32Str.encode("hello")
      encoded.should be_a(Nucleoc::Utf32Str)
      encoded.len.should eq(5)
    end

    it "decodes UTF-32 to string" do
      str = "hello"
      encoded = Nucleoc::Utf32Str.encode(str)
      decoded = encoded.to_s
      decoded.should eq(str)
    end

    it "handles unicode round trip" do
      str = "café world"
      encoded = Nucleoc::Utf32Str.encode(str)
      decoded = encoded.to_s
      decoded.should eq(str)
    end
  end

  describe "Comparison" do
    it "compares strings correctly" do
      str1 = Nucleoc::Utf32Str.new("hello")
      str2 = Nucleoc::Utf32Str.new("hello")
      str3 = Nucleoc::Utf32Str.new("world")

      (str1 == str2).should be_true
      (str1 == str3).should be_false
    end

    it "compares with regular strings" do
      utf32_str = Nucleoc::Utf32Str.new("hello")
      (utf32_str == "hello").should be_true
      (utf32_str == "world").should be_false
    end
  end
end
