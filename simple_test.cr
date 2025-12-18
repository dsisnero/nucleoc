require "./src/nucleoc"

matcher = Nucleoc::Matcher.new

# Test 1: Basic fuzzy match
puts "Test 1: fuzzy_match(\"hello world\", \"hw\")"
score1 = matcher.fuzzy_match("hello world", "hw")
puts "Score: #{score1.inspect}"

# Test 2: Direct greedy match
puts "\nTest 2: fuzzy_match_greedy(\"hello world\", \"hw\")"
score2 = matcher.fuzzy_match_greedy("hello world", "hw")
puts "Score: #{score2.inspect}"

# Test 3: With indices
puts "\nTest 3: fuzzy_indices_greedy(\"hello world\", \"hw\", indices)"
indices = [] of UInt32
score3 = matcher.fuzzy_indices_greedy("hello world", "hw", indices)
puts "Score: #{score3.inspect}, Indices: #{indices.inspect}"

# Test 4: Check what fuzzy_match_optimal does
puts "\nTest 4: Testing fuzzy_match_optimal directly"
indices4 = [] of UInt32
score4 = matcher.fuzzy_match_optimal("hello world", "hw", 0, 11, 11, indices4, false)
puts "Score with compute_indices=false: #{score4.inspect}, Indices: #{indices4.inspect}"

indices5 = [] of UInt32
score5 = matcher.fuzzy_match_optimal("hello world", "hw", 0, 11, 11, indices5, true)
puts "Score with compute_indices=true: #{score5.inspect}, Indices: #{indices5.inspect}"
