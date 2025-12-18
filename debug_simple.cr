require "./src/nucleoc"

# Simple debug to understand the scoring
config = Nucleoc::Config.new(normalize: true, ignore_case: true, prefer_prefix: false)
matcher = Nucleoc::Matcher.new(config)

haystack = "fooBarbaz1"
needle = "obr"

puts "Testing 'obr' matching 'fooBarbaz1':"
puts "  Haystack: #{haystack}"
puts "  Needle: #{needle}"

# Try substring match
score1 = matcher.substring_match(haystack, needle)
puts "  Substring match score: #{score1}"

# Try fuzzy match
score2 = matcher.fuzzy_match(haystack, needle)
puts "  Fuzzy match score: #{score2}"

# Try with indices
indices = [] of UInt32
score3 = matcher.substring_indices(haystack, needle, indices)
puts "  Substring indices score: #{score3}"
puts "  Indices: #{indices}"

# Test case sensitive
config2 = Nucleoc::Config.new(normalize: true, ignore_case: false, prefer_prefix: false)
matcher2 = Nucleoc::Matcher.new(config2)
needle2 = "Bar"
puts "\nTesting 'Bar' matching 'fooBarbaz1' (case sensitive):"
score4 = matcher2.substring_match(haystack, needle2)
puts "  Substring match score: #{score4}"
score5 = matcher2.fuzzy_match(haystack, needle2)
puts "  Fuzzy match score: #{score5}"

# Test single character
needle3 = "z"
puts "\nTesting 'z' matching 'fooBarbaz1':"
score6 = matcher.fuzzy_match(haystack, needle3)
puts "  Fuzzy match score: #{score6}"

# Test umlaut
haystack4 = "Über"
needle4 = "uber"
puts "\nTesting 'uber' matching 'Über':"
score7 = matcher.fuzzy_match(haystack4, needle4)
puts "  Fuzzy match score: #{score7}"