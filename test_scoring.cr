require "./src/nucleoc"

matcher = Nucleoc::Matcher.new

# Test exact scoring to understand constants
puts "Constants:"
puts "SCORE_MATCH: #{Nucleoc::SCORE_MATCH}"
puts "PENALTY_GAP_START: #{Nucleoc::PENALTY_GAP_START}"
puts "PENALTY_GAP_EXTENSION: #{Nucleoc::PENALTY_GAP_EXTENSION}"
puts "BONUS_BOUNDARY: #{Nucleoc::BONUS_BOUNDARY}"
puts "BONUS_CONSECUTIVE: #{Nucleoc::BONUS_CONSECUTIVE}"
puts "BONUS_FIRST_CHAR_MULTIPLIER: #{Nucleoc::BONUS_FIRST_CHAR_MULTIPLIER}"
puts "BONUS_CAMEL123: #{Nucleoc::BONUS_CAMEL123}"

# Test the specific case
haystack = "fooBarbaz1"
needle = "obr"

puts "\nTesting 'obr' in 'fooBarbaz1':"

# Greedy algorithm
greedy_indices = [] of UInt32
greedy_score = matcher.fuzzy_indices_greedy(haystack, needle, greedy_indices)
puts "Greedy - Score: #{greedy_score}, Indices: #{greedy_indices}"

# Optimal algorithm
optimal_indices = [] of UInt32
optimal_score = matcher.fuzzy_indices(haystack, needle, optimal_indices)
puts "Optimal - Score: #{optimal_score}, Indices: #{optimal_indices}"

# Let's trace through manually
# Positions: f(0) o(1) o(2) B(3) a(4) r(5) b(6) a(7) z(8) 1(9)
# We want: o at 2, b at 3, r at 5 = [2, 3, 5]
# Normalized: 'o' 'o' 'b' 'a' 'r' (sliced haystack from prefilter start=1 to end=6)

puts "\nManual analysis:"
puts "Haystack normalized: fooBarbaz1"
puts "Expected match: positions 2, 3, 5"
puts "Characters: 'o' at 2, 'B' at 3, 'r' at 5"
puts "Bonuses:"
puts "  'o' at 2: previous char 'o' (lower), current 'o' (lower) → no bonus"
puts "  'B' at 3: previous char 'o' (lower), current 'B' (upper) → BONUS_CAMEL123 = #{Nucleoc::BONUS_CAMEL123}"
puts "  'r' at 5: previous char 'a' (lower), current 'r' (lower) → no bonus (gap penalty applies)"

puts "\nExpected score calculation:"
puts "First char 'o': SCORE_MATCH(16) * BONUS_FIRST_CHAR_MULTIPLIER(2) + 0 = 32"
puts "Gap from 2 to 3: PENALTY_GAP_START(3) = 32 - 3 = 29"
puts "Second char 'B': SCORE_MATCH(16) + BONUS_CAMEL123(5) = 21 → total 50"
puts "Gap from 3 to 5: PENALTY_GAP_START(3) = 50 - 3 = 47"
puts "Third char 'r': SCORE_MATCH(16) + 0 = 16 → total 63"

puts "\nBut optimal returns 50, not 63. Why?"

# Maybe our bonus calculation is wrong
config = matcher.config
puts "\nConfig bonuses:"
puts "bonus_boundary_white: #{config.bonus_boundary_white}"
puts "bonus_boundary_delimiter: #{config.bonus_boundary_delimiter}"