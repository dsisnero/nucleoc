# UTF-32 encoded string types for nucleoc fuzzy matching. These mirror the Rust Utf32Str/Utf32String
# types closely so that scoring and normalization behave the same way.
module Nucleoc
  def self.has_ascii_graphemes(string : String) : Bool
    return false unless string.ascii_only?
    !string.includes?("\r\n")
  end

  # Immutable UTF-32 view used by the matcher
  struct Utf32Str
    enum Kind
      Ascii
      Unicode
    end

    @kind : Kind
    @bytes : Slice(UInt8)?
    @chars : Slice(Char)?
    @owned_string : String?
    @owned_chars : Array(Char)?

    def initialize(bytes : Slice(UInt8))
      @kind = Kind::Ascii
      @bytes = bytes
      @chars = nil
      @owned_string = nil
      @owned_chars = nil
    end

    def initialize(chars : Slice(Char))
      @kind = Kind::Unicode
      @chars = chars
      @bytes = nil
      @owned_string = nil
      @owned_chars = nil
    end

    def initialize(str : String)
      if Nucleoc.has_ascii_graphemes(str)
        @kind = Kind::Ascii
        @bytes = str.to_slice
        @chars = nil
        @owned_string = str
        @owned_chars = nil
      else
        arr = Chars.graphemes(str)
        @kind = Kind::Unicode
        @chars = arr.to_unsafe.to_slice(arr.size)
        @bytes = nil
        @owned_chars = arr
        @owned_string = nil
      end
    end

    def self.encode(str : String) : Utf32Str
      Utf32Str.new(str)
    end

    # Keep an owned buffer alive when constructed from Unicode string
    @owned_chars : Array(Char)?

    def self.new(str : String, buf : Array(Char)) : Utf32Str
      if has_ascii_graphemes(str)
        Utf32Str.new(str.to_slice)
      else
        buf.clear
        buf.concat(Nucleoc::Chars.graphemes(str))
        Utf32Str.new(buf.to_unsafe.to_slice(buf.size))
      end
    end

    def len : Int32
      case @kind
      when Kind::Ascii
        @bytes.not_nil!.size
      else
        @chars.not_nil!.size
      end
    end

    def size : Int32
      len
    end

    def empty? : Bool
      len == 0
    end

    def ascii? : Bool
      @kind == Kind::Ascii
    end

    def ascii? : Bool
      @kind.ascii?
    end

    def slice(range : Range(Int32, Int32)) : Utf32Str
      case @kind
      when Kind::Ascii
        Utf32Str.new(@bytes.not_nil![range])
      else
        Utf32Str.new(@chars.not_nil![range])
      end
    end

    def slice_u32(range : Range(UInt32, UInt32)) : Utf32Str
      slice(range.begin.to_i32...range.end.to_i32)
    end

    def first : Char
      case @kind
      when Kind::Ascii
        @bytes.not_nil![0].chr
      else
        @chars.not_nil![0]
      end
    end

    def last : Char
      case @kind
      when Kind::Ascii
        bytes = @bytes.not_nil!
        bytes[bytes.size - 1].chr
      else
        chars = @chars.not_nil!
        chars[chars.size - 1]
      end
    end

    def get(n : Int32) : Char?
      return if n < 0 || n >= len
      case @kind
      when Kind::Ascii
        @bytes.not_nil![n].chr
      else
        @chars.not_nil![n]
      end
    end

    def leading_white_space : Int32
      case @kind
      when Kind::Ascii
        bytes = @bytes.not_nil!
        bytes.index { |b| !b.ascii_whitespace? }.try(&.to_i) || 0
      else
        chars = @chars.not_nil!
        chars.index { |c| !c.whitespace? }.try(&.to_i) || 0
      end
    end

    def trailing_white_space : Int32
      case @kind
      when Kind::Ascii
        bytes = @bytes.not_nil!
        idx = bytes.rindex { |b| !b.ascii_whitespace? }
        idx ? (bytes.size - 1 - idx) : 0
      else
        chars = @chars.not_nil!
        idx = chars.rindex { |c| !c.whitespace? }
        idx ? (chars.size - 1 - idx) : 0
      end
    end

    def each_char(& : Char ->)
      case @kind
      when Kind::Ascii
        @bytes.not_nil!.each { |b| yield b.chr }
      else
        @chars.not_nil!.each { |c| yield c }
      end
    end

    def each(& : Char ->)
      each_char { |c| yield c }
    end

    def chars : Array(Char)
      arr = [] of Char
      each_char { |c| arr << c }
      arr
    end

    def ==(other : Utf32Str) : Bool
      return false unless len == other.len
      i = 0
      while i < len
        return false unless get(i) == other.get(i)
        i += 1
      end
      true
    end

    def ==(other : String) : Bool
      to_s == other
    end

    def to_s(io : IO) : Nil
      each_char { |c| io << c }
    end

    def to_s : String
      String.build { |io| to_s(io) }
    end
  end

  # Owned UTF-32 string
  struct Utf32String
    enum Kind
      Ascii
      Unicode
    end

    @kind : Kind
    @bytes : String?
    @chars : Array(Char)?

    def initialize(str : String, ascii : Bool)
      if ascii
        @kind = Kind::Ascii
        @bytes = str
        @chars = nil
      else
        @kind = Kind::Unicode
        @chars = Chars.graphemes(str)
        @bytes = nil
      end
    end

    def self.from(str : String) : Utf32String
      Utf32String.new(str, Nucleoc.has_ascii_graphemes(str))
    end

    def len : Int32
      case @kind
      when Kind::Ascii
        @bytes.not_nil!.size
      else
        @chars.not_nil!.size
      end
    end

    def empty? : Bool
      len == 0
    end

    def slice(range : Range(Int32, Int32)) : Utf32Str
      case @kind
      when Kind::Ascii
        Utf32Str.new(@bytes.not_nil![range].to_slice)
      else
        Utf32Str.new(@chars.not_nil!.to_unsafe.to_slice(len)[range])
      end
    end

    def slice : Utf32Str
      slice(0...len)
    end

    def slice_u32(range : Range(UInt32, UInt32)) : Utf32Str
      slice(range.begin.to_i32...range.end.to_i32)
    end

    def to_s(io : IO) : Nil
      case @kind
      when Kind::Ascii
        io << @bytes.not_nil!
      else
        @chars.not_nil!.each { |c| io << c }
      end
    end

    def to_s : String
      String.build { |io| to_s(io) }
    end
  end
end
