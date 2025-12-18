# Prefilter optimizations for faster matching
module Nucleoc
  class Matcher
    # Prefilter for ASCII strings
    private def prefilter_ascii(haystack : String, needle : String, only_greedy : Bool) : Tuple(Int32, Int32, Int32)?
      return if needle.empty? || haystack.empty?
      return if needle.size > haystack.size

      haystack_bytes = haystack.bytes
      needle_bytes = needle.bytes

      if @config.ignore_case
        # Find first character (case insensitive)
        start = find_ascii_ignore_case(needle_bytes[0], haystack_bytes[0...(haystack_bytes.size - needle_bytes.size + 1)])
        return unless start

        greedy_end = start + 1
        current_haystack = haystack_bytes[greedy_end..]

        # Find subsequent characters greedily
        needle_bytes[1..].each do |c|
          idx = find_ascii_ignore_case(c, current_haystack)
          return unless idx
          greedy_end += idx + 1
          current_haystack = current_haystack[idx + 1..]
        end

        if only_greedy
          {start, greedy_end, greedy_end}
        else
          # Find last character from the end
          last_char = needle_bytes.last
          end_pos = greedy_end + find_ascii_ignore_case_rev(last_char, current_haystack).try(&.+ 1) || 0
          {start, greedy_end, end_pos}
        end
      else
        # Case sensitive search
        start = haystack_bytes.index(needle_bytes[0], 0, haystack_bytes.size - needle_bytes.size + 1)
        return unless start

        greedy_end = start + 1
        current_haystack = haystack_bytes[greedy_end..]

        # Find subsequent characters greedily
        needle_bytes[1..].each do |c|
          idx = current_haystack.index(c)
          return unless idx
          greedy_end += idx + 1
          current_haystack = current_haystack[idx + 1..]
        end

        if only_greedy
          {start, greedy_end, greedy_end}
        else
          # Find last character from the end
          last_char = needle_bytes.last
          end_pos = greedy_end + current_haystack.rindex(last_char).try(&.+ 1) || 0
          {start, greedy_end, end_pos}
        end
      end
    end

    # Prefilter for non-ASCII strings
    private def prefilter_non_ascii(haystack : String, needle : String, only_greedy : Bool) : Tuple(Int32, Int32)?
      return if needle.empty? || haystack.empty?
      return if needle.size > haystack.size

      haystack_chars = haystack.chars
      needle_chars = needle.chars

      # Find first character
      start = haystack_chars.index do |c|
        Chars.normalize(c, @config) == Chars.normalize(needle_chars[0], @config)
      end
      return unless start

      if only_greedy
        {start, start + 1}
      else
        # Find last character from the end
        last_char = needle_chars.last
        end_pos = haystack_chars.rindex do |c|
          Chars.normalize(c, @config) == Chars.normalize(last_char, @config)
        end
        return unless end_pos
        {start, end_pos + 1}
      end
    end

    # Find ASCII character case-insensitively
    private def find_ascii_ignore_case(c : UInt8, haystack : Slice(UInt8)) : Int32?
      if c >= 'a'.ord && c <= 'z'.ord
        # Search for both lowercase and uppercase
        upper_c = c - 32
        haystack.each_with_index do |b, i|
          return i if b == c || b == upper_c
        end
      else
        haystack.each_with_index do |b, i|
          return i if b == c
        end
      end
      nil
    end

    # Find ASCII character case-insensitively from the end
    private def find_ascii_ignore_case_rev(c : UInt8, haystack : Slice(UInt8)) : Int32?
      if c >= 'a'.ord && c <= 'z'.ord
        # Search for both lowercase and uppercase
        upper_c = c - 32
        (haystack.size - 1).downto(0) do |i|
          return i if haystack[i] == c || haystack[i] == upper_c
        end
      else
        (haystack.size - 1).downto(0) do |i|
          return i if haystack[i] == c
        end
      end
      nil
    end
  end
end
