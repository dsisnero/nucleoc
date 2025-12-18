# Script to calculate expected scores from Rust tests

# Rust constants
SCORE_MATCH = 16
PENALTY_GAP_START = 3
PENALTY_GAP_EXTENSION = 1
BONUS_BOUNDARY = SCORE_MATCH // 2  # 8
BONUS_CAMEL123 = BONUS_BOUNDARY - PENALTY_GAP_START  # 5
BONUS_CONSECUTIVE = PENALTY_GAP_START + PENALTY_GAP_EXTENSION  # 4
BONUS_FIRST_CHAR_MULTIPLIER = 2
BONUS_NON_WORD = BONUS_BOUNDARY  # 8
BONUS_BOUNDARY_WHITE = BONUS_BOUNDARY  # Assuming same
BONUS_BOUNDARY_DELIMITER = BONUS_BOUNDARY  # Assuming same

def calculate_score(base_score, needle_len)
  base_score + (needle_len * SCORE_MATCH)
end

puts "=== Scoring Constants ==="
puts "SCORE_MATCH: #{SCORE_MATCH}"
puts "BONUS_BOUNDARY: #{BONUS_BOUNDARY}"
puts "BONUS_CAMEL123: #{BONUS_CAMEL123}"
puts "BONUS_CONSECUTIVE: #{BONUS_CONSECUTIVE}"
puts "PENALTY_GAP_START: #{PENALTY_GAP_START}"
puts "PENALTY_GAP_EXTENSION: #{PENALTY_GAP_EXTENSION}"
puts

puts "=== Test Cases ==="

# Test 1: "oBr" matching "fooBarbaz1" (case sensitive fuzzy)
# Rust: BONUS_CAMEL123 - PENALTY_GAP_START = 5 - 3 = 2
# Needle length: 3
# Total: 2 + (3 * 16) = 2 + 48 = 50
puts "1. 'oBr' matching 'fooBarbaz1' (case sensitive fuzzy):"
puts "  Base: BONUS_CAMEL123 - PENALTY_GAP_START = #{BONUS_CAMEL123} - #{PENALTY_GAP_START} = #{BONUS_CAMEL123 - PENALTY_GAP_START}"
puts "  Needle length: 3"
puts "  Total: #{calculate_score(BONUS_CAMEL123 - PENALTY_GAP_START, 3)}"
puts

# Test 2: "Bar" matching "fooBarbaz1" (case sensitive substring)
# This should be a substring match with bonus
# Looking at Rust test_substring_case_sensitive, it expects indices [3, 4, 5] but no score given
# Let me check what substring scores look like
puts "2. 'Bar' matching 'fooBarbaz1' (case sensitive substring):"
puts "  Needle length: 3"
puts "  Base score for substring? Unknown"
puts "  Minimum: #{calculate_score(0, 3)} = 48"
puts "  Crystal returns: 68 (20 points higher)"
puts

# Test 3: "fbb" matching "fooBarbaz1" (case insensitive fuzzy)
# This is testing case-insensitive equality
puts "3. 'fbb' matching 'fooBarbaz1' (case insensitive fuzzy):"
puts "  Needle length: 3"
puts "  Minimum: #{calculate_score(0, 3)} = 48"
puts "  Crystal returns: 65 (17 points higher)"
puts

# Test 4: "你好" matching "你好世界" (Unicode)
# Needle length: 2 (Chinese characters)
puts "4. '你好' matching '你好世界' (Unicode):"
puts "  Needle length: 2"
puts "  Minimum: #{calculate_score(0, 2)} = 32"
puts "  Crystal returns: 62 (30 points higher!)"
puts

# Test 5: "md" matching "Moby Dick" (prefer prefix)
puts "5. 'md' matching 'Moby Dick' (prefer prefix):"
puts "  Needle length: 2"
puts "  Minimum: #{calculate_score(0, 2)} = 32"
puts "  Crystal returns: 64 (32 points higher - exactly double!)"
puts

# Let me check what the actual Crystal implementation returns for a simple match
require "./src/nucleoc"

matcher = Nucleoc::Matcher.new(Nucleoc::Config.new)
indices = [] of UInt32

puts "\n=== Actual Crystal Results ==="

# Test "oBr" case sensitive
matcher_cs = Nucleoc::Matcher.new(Nucleoc::Config.new(ignore_case: false))
score1 = matcher_cs.fuzzy_indices("fooBarbaz1", "oBr", indices)
puts "1. 'oBr' fuzzy (case sensitive): #{score1}"
indices.clear

# Test "Bar" substring case sensitive  
score2 = matcher_cs.substring_indices("fooBarbaz1", "Bar", indices)
puts "2. 'Bar' substring (case sensitive): #{score2}"
indices.clear

# Test "fbb" case insensitive
matcher_ci = Nucleoc::Matcher.new(Nucleoc::Config.new(ignore_case: true))
score3 = matcher_ci.fuzzy_indices("fooBarbaz1", "fbb", indices)
puts "3. 'fbb' fuzzy (case insensitive): #{score3}"
indices.clear

# Test "你好"
score4 = matcher_ci.fuzzy_indices("你好世界", "你好", indices)
puts "4. '你好' fuzzy: #{score4}"
indices.clear

# Test "md" with prefer_prefix
matcher_pp = Nucleoc::Matcher.new(Nucleoc::Config.new(prefer_prefix: true, ignore_case: true))
score5 = matcher_pp.fuzzy_indices("Moby Dick", "md", indices)
puts "5. 'md' fuzzy with prefer_prefix: #{score5}"
indices.clear