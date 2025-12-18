# Pattern parsing and matching logic
module Nucleoc
  # How to treat a case mismatch between two characters.
  enum CaseMatching
    # Characters never match their case folded version (`a != A`).
    Respect
    # Characters always match their case folded version (`a == A`).
    Ignore
    # Acts like `Ignore` if all characters in a pattern atom are
    # lowercase and like `Respect` otherwise.
    Smart
  end

  # How to handle unicode normalization.
  enum Normalization
    # Characters never match their normalized version (`a != ä`).
    Never
    # Acts like `Never` if any character in a pattern atom
    # would need to be normalized. Otherwise normalization occurs (`a == ä` but `ä != a`).
    Smart
  end

  # The kind of matching algorithm to run for an atom.
  enum AtomKind
    # Fuzzy matching where the needle must match any haystack characters
    # (match can contain gaps). This atom kind is used by default if no
    # special syntax is used. There is no negated fuzzy matching (too
    # many false positives).
    Fuzzy
    # Substring matching where the needle must match a contiguous substring
    # of the haystack.
    Substring
    # Prefix matching where the needle must match the start of the haystack.
    Prefix
    # Postfix matching where the needle must match the end of the haystack.
    Postfix
    # Exact matching where the needle must match the haystack exactly.
    Exact
  end

  # A single pattern component that is matched with a single `Matcher` function.
  class Atom
    property negative : Bool
    property kind : AtomKind
    property needle : String
    property ignore_case : Bool
    property normalize : Bool

    def initialize(@needle : String, @kind : AtomKind = AtomKind::Fuzzy,
                   @ignore_case : Bool = true, @normalize : Bool = true,
                   @negative : Bool = false)
    end

    def self.parse(raw : String, case_matching : CaseMatching = CaseMatching::Smart,
                   normalization : Normalization = Normalization::Smart) : Atom
      atom = raw.dup
      invert = false

      if atom.starts_with?("!")
        invert = true
        atom = atom[1..]
      elsif atom.starts_with?("\\!")
        atom = atom[1..]
      end

      kind = AtomKind::Fuzzy

      if atom.starts_with?("^")
        atom = atom[1..]
        kind = AtomKind::Prefix
      elsif atom.starts_with?("\\^")
        atom = atom[1..]
      elsif atom.starts_with?("'")
        atom = atom[1..]
        kind = AtomKind::Substring
      elsif atom.starts_with?("\\'")
        atom = atom[1..]
      end

      append_dollar = false
      if atom.ends_with?("\\$")
        append_dollar = true
        atom = atom[0...-2]
      elsif atom.ends_with?("$")
        atom = atom[0...-1]
        kind = kind == AtomKind::Fuzzy ? AtomKind::Postfix : AtomKind::Exact
      end

      if invert && kind == AtomKind::Fuzzy
        kind = AtomKind::Substring
      end

      # Unescape whitespace and specials
      needle = String.build do |io|
        i = 0
        while i < atom.size
          ch = atom[i]
          if ch == '\\' && i + 1 < atom.size
            nxt = atom[i + 1]
            case nxt
            when ' ', '^', '\'', '!', '\\', '$'
              io << nxt
              i += 2
              next
            end
          end
          io << ch
          i += 1
        end
      end
      needle += "$" if append_dollar

      ignore_case = case case_matching
                    when CaseMatching::Ignore
                      true
                    when CaseMatching::Respect
                      false
                    when CaseMatching::Smart
                      !needle.chars.any?(&.uppercase?)
                    else
                      true
                    end

      normalize_flag = normalization != Normalization::Never
      needle = needle.downcase if ignore_case

      Atom.new(needle, kind, ignore_case, normalize_flag, invert)
    end

    def match(matcher : Matcher, haystack : String, indices : Array(UInt32)? = nil) : UInt16?
      matcher.config.ignore_case = @ignore_case
      matcher.config.normalize = @normalize

      score = case @kind
              when AtomKind::Fuzzy
                indices ? matcher.fuzzy_indices(haystack, @needle, indices) : matcher.fuzzy_match(haystack, @needle)
              when AtomKind::Substring
                indices ? matcher.substring_indices(haystack, @needle, indices) : matcher.substring_match(haystack, @needle)
              when AtomKind::Prefix
                indices ? matcher.prefix_indices(haystack, @needle, indices) : matcher.prefix_match(haystack, @needle)
              when AtomKind::Postfix
                indices ? matcher.postfix_indices(haystack, @needle, indices) : matcher.postfix_match(haystack, @needle)
              when AtomKind::Exact
                indices ? matcher.exact_indices(haystack, @needle, indices) : matcher.exact_match(haystack, @needle)
              end

      if @negative
        score ? nil : 0_u16
      else
        score
      end
    end

    def negative? : Bool
      @negative
    end
  end

  # A complete pattern consisting of multiple atoms.
  class Pattern
    property atoms : Array(Atom)

    def initialize(@atoms : Array(Atom))
    end

    def self.parse(pattern : String, case_matching : CaseMatching = CaseMatching::Smart,
                   normalization : Normalization = Normalization::Smart) : Pattern
      atoms = [] of Atom
      current = String.new
      escaped = false

      pattern.each_char do |c|
        if escaped
          current += "\\"
          current += c
          escaped = false
        elsif c == '\\'
          escaped = true
        elsif c.whitespace?
          unless current.empty?
            atoms << Atom.parse(current, case_matching, normalization)
            current = String.new
          end
        else
          current += c
        end
      end

      atoms << Atom.parse(current, case_matching, normalization) unless current.empty?
      Pattern.new(atoms)
    end

    # Match this pattern against a haystack.
    # Returns the total score if all atoms match, nil otherwise.
    def match(matcher : Matcher, haystack : String, indices : Array(Array(UInt32))? = nil) : UInt16?
      total_score = 0_u16
      atom_indices = [] of Array(UInt32) if indices

      @atoms.each_with_index do |atom, _|
        if atom.negative?
          # Negative atom - if it matches, the whole pattern fails
          if atom.match(matcher, haystack)
            return
          end
        else
          # Positive atom - must match
          atom_score = if indices
                         current_indices = [] of UInt32
                         score = atom.match(matcher, haystack, current_indices)
                         atom_indices.not_nil! << current_indices if score
                         score
                       else
                         atom.match(matcher, haystack)
                       end

          return unless atom_score
          total_score += atom_score
        end
      end

      # Copy indices if requested
      if indices && atom_indices
        indices.clear
        atom_indices.each do |atom_idx|
          indices << atom_idx
        end
      end

      total_score
    end
  end
end
