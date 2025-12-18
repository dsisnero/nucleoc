# Character utilities for nucleoc fuzzy matching
module Nucleoc
  enum CharClass
    Whitespace
    NonWord
    Delimiter
    Lower
    Upper
    Letter
    Number
  end

  module Chars
    def self.is_upper_case(c : Char) : Bool
      c.uppercase?
    end

    def self.to_lower_case(c : Char) : Char
      c.downcase
    end

    private def self.ascii_char_class(c : UInt8, config : Config) : CharClass
      if c >= 'a'.ord && c <= 'z'.ord
        CharClass::Lower
      elsif c >= 'A'.ord && c <= 'Z'.ord
        CharClass::Upper
      elsif c >= '0'.ord && c <= '9'.ord
        CharClass::Number
      elsif c.chr.ascii_whitespace?
        CharClass::Whitespace
      elsif config.delimiter_chars.includes?(c.chr)
        CharClass::Delimiter
      else
        CharClass::NonWord
      end
    end

    private def self.non_ascii_char_class(c : Char) : CharClass
      if c.lowercase?
        CharClass::Lower
      elsif is_upper_case(c)
        CharClass::Upper
      elsif c.number?
        CharClass::Number
      elsif c.letter?
        CharClass::Letter
      elsif c.whitespace?
        CharClass::Whitespace
      else
        CharClass::NonWord
      end
    end

    def self.char_class(c : Char, config : Config) : CharClass
      if c.ascii?
        ascii_char_class(c.ord.to_u8, config)
      else
        non_ascii_char_class(c)
      end
    end

    def self.char_class_and_normalize(c : Char, config : Config) : Tuple(Char, CharClass)
      char_class = char_class(c, config)
      {normalize(c, config), char_class}
    end

    def self.normalize(c : Char, config : Config) : Char
      result = c
      result = to_lower_case(result) if config.ignore_case
      result
    end

    # Return the first codepoint of each grapheme (special casing CRLF like rust)
    def self.graphemes(text : String) : Array(Char)
      chars = text.chars
      res = [] of Char
      i = 0
      while i < chars.size
        if chars[i] == '\r' && i + 1 < chars.size && chars[i + 1] == '\n'
          res << '\n'
          i += 2
          next
        end
        c = chars[i]
        # Skip basic combining marks (attach to previous grapheme)
        if (0x0300..0x036F).includes?(c.ord) && !res.empty?
          i += 1
          next
        end
        res << c
        i += 1
      end
      res
    end
  end
end
