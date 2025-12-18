# Configuration for the nucleoc matcher
module Nucleoc
  # Score constants
  SCORE_MATCH                 = 16_u16
  PENALTY_GAP_START           =  3_u16
  PENALTY_GAP_EXTENSION       =  1_u16
  PREFIX_BONUS_SCALE          =  2_u16
  BONUS_BOUNDARY              = SCORE_MATCH // 2
  MAX_PREFIX_BONUS            = BONUS_BOUNDARY
  BONUS_CAMEL123              = BONUS_BOUNDARY - PENALTY_GAP_START
  BONUS_NON_WORD              = BONUS_BOUNDARY
  BONUS_CONSECUTIVE           = PENALTY_GAP_START + PENALTY_GAP_EXTENSION
  BONUS_FIRST_CHAR_MULTIPLIER = 2_u16

  # Configuration data that controls how a matcher behaves
  struct Config
    # Characters that act as delimiters and provide bonus
    # for matching the following char
    property delimiter_chars : String

    # Extra bonus for word boundary after whitespace character or beginning of the string
    property bonus_boundary_white : UInt16

    # Extra bonus for word boundary after slash, colon, semi-colon, and comma
    property bonus_boundary_delimiter : UInt16

    # Initial character class (used for boundary detection)
    property initial_char_class : CharClass

    # Whether to normalize latin script characters to ASCII (enabled by default)
    property normalize : Bool

    # Whether to ignore casing
    property ignore_case : Bool

    # Whether to provide a bonus to matches by their distance from the start
    # of the haystack. The bonus is fairly small compared to the normal gap
    # penalty to avoid messing with the normal score heuristic. This setting
    # is not turned on by default and only recommended for autocompletion
    # usecases where the expectation is that the user is typing the entire
    # match. For a full fzf-like fuzzy matcher/picker word segmentation and
    # explicit prefix literals should be used instead.
    property prefer_prefix : Bool

    # Default configuration for nucleoc
    DEFAULT = new(
      delimiter_chars: "/,:;|",
      bonus_boundary_white: BONUS_BOUNDARY + 2_u16,
      bonus_boundary_delimiter: BONUS_BOUNDARY + 1_u16,
      initial_char_class: CharClass::Whitespace,
      normalize: true,
      ignore_case: true,
      prefer_prefix: false
    )

    def initialize(
      @delimiter_chars : String = "/,:;|",
      @bonus_boundary_white : UInt16 = BONUS_BOUNDARY + 2_u16,
      @bonus_boundary_delimiter : UInt16 = BONUS_BOUNDARY + 1_u16,
      @initial_char_class : CharClass = CharClass::Whitespace,
      @normalize : Bool = true,
      @ignore_case : Bool = true,
      @prefer_prefix : Bool = false,
    )
    end

    # Configures the matcher with bonuses appropriate for matching file paths.
    def match_paths : self
      config = dup
      {% if flag?(:win32) %}
        config.delimiter_chars = "/\\"
      {% else %}
        config.delimiter_chars = "/"
      {% end %}
      config.bonus_boundary_white = BONUS_BOUNDARY
      config.initial_char_class = CharClass::Delimiter
      config
    end

    # Calculate bonus for a character based on its position and previous character class
    # This matches the Rust Config.bonus_for method exactly
    def bonus_for(prev_class : CharClass, char_class : CharClass) : UInt16
      # Transition from non-word to word character
      if char_class > CharClass::Delimiter
        case prev_class
        when CharClass::Whitespace
          return @bonus_boundary_white
        when CharClass::Delimiter
          return @bonus_boundary_delimiter
        when CharClass::NonWord
          return BONUS_BOUNDARY
        else
          # Continue to check other cases
        end
      end

      # Camel case (lower to upper) or number boundary (non-number to number)
      if (prev_class == CharClass::Lower && char_class == CharClass::Upper) ||
         (prev_class != CharClass::Number && char_class == CharClass::Number)
        return BONUS_CAMEL123
      end

      # Whitespace or non-word characters
      if char_class == CharClass::Whitespace
        return @bonus_boundary_white
      end

      if char_class == CharClass::NonWord
        return BONUS_NON_WORD
      end

      0_u16
    end
  end
end
