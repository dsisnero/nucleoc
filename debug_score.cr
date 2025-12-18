require "./src/nucleoc"

matcher = Nucleoc::Matcher.new

puts "Testing exact match 'hello' in 'hello':"
score = matcher.exact_match("hello", "hello")
puts "Score: #{score}"
puts "Expected: 140"

puts "\nTesting fuzzy match 'hello' in 'hello world':"
score = matcher.fuzzy_match("hello world", "hello")
puts "Score: #{score}"
puts "Expected: 140"

puts "\nConstants:"
puts "SCORE_MATCH: #{Nucleoc::SCORE_MATCH}"
puts "BONUS_BOUNDARY: #{Nucleoc::BONUS_BOUNDARY}"
puts "BONUS_CONSECUTIVE: #{Nucleoc::BONUS_CONSECUTIVE}"
puts "MAX_PREFIX_BONUS: #{Nucleoc::MAX_PREFIX_BONUS}"
puts "BONUS_FIRST_CHAR_MULTIPLIER: #{Nucleoc::BONUS_FIRST_CHAR_MULTIPLIER}"

puts "\nConfig bonuses:"
config = matcher.config
puts "bonus_boundary_white: #{config.bonus_boundary_white}"
puts "bonus_boundary_delimiter: #{config.bonus_boundary_delimiter}"

# Let's trace through the calculation manually
puts "\nManual calculation for 'hello' at start of 'hello':"
# For first character 'h' at position 0:
# prev_class = CharClass::Whitespace (initial)
# char_class = CharClass::Lower
# bonus = bonus_boundary_white = BONUS_BOUNDARY + 2 = 8 + 2 = 10
# First char score: (bonus * 2) + 16 = (10 * 2) + 16 = 20 + 16 = 36

# Subsequent characters: bonus + 16
# For consecutive matches, bonus should be BONUS_CONSECUTIVE = 7
# So each subsequent char: 7 + 16 = 23
# 4 chars * 23 = 92

# Total without MAX_PREFIX_BONUS: 36 + 92 = 128
# With MAX_PREFIX_BONUS (3): 128 + 3 = 131

puts "Expected with current logic: 131"
puts "But we need 140!"

# Wait, maybe BONUS_BOUNDARY is actually 13, not 8?
# If BONUS_BOUNDARY = 13, then:
# bonus_boundary_white = 13 + 2 = 15
# First char: (15 * 2) + 16 = 30 + 16 = 46
# Subsequent: 4 * (7 + 16) = 4 * 23 = 92
# Total: 46 + 92 = 138
# Plus MAX_PREFIX_BONUS (3): 141 (close to 140)

# Or if MAX_PREFIX_BONUS = BONUS_BOUNDARY = 13:
# First char: (10 * 2) + 16 = 36
# Subsequent: 4 * 23 = 92
# Total: 36 + 92 + 13 = 141

# Actually, looking at rust_test.rs analysis:
# First 'h': SCORE_MATCH(16) * BONUS_FIRST_CHAR_MULTIPLIER(2) + BONUS_BOUNDARY(13) = 45
# So BONUS_BOUNDARY must be 13, not 8!
