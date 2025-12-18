require "./src/nucleoc"

matcher = Nucleoc::Matcher.new

# Test 1: Exact match "hello" in "hello"
haystack1 = "hello"
needle1 = "hello"

score1 = matcher.exact_match(haystack1, needle1)
puts "Test 1 - Crystal exact_match('hello', 'hello') = #{score1}"

indices1 = [] of UInt32
score_with_indices1 = matcher.exact_indices(haystack1, needle1, indices1)
puts "Test 1 - Crystal exact_indices('hello', 'hello') = #{score_with_indices1}"
puts "Test 1 - Indices: #{indices1}"

# Test 2: Exact match "hello" in "hello world"
haystack2 = "hello world"
needle2 = "hello"

score2 = matcher.exact_match(haystack2, needle2)
puts "\nTest 2 - Crystal exact_match('hello world', 'hello') = #{score2}"

indices2 = [] of UInt32
score_with_indices2 = matcher.exact_indices(haystack2, needle2, indices2)
puts "Test 2 - Crystal exact_indices('hello world', 'hello') = #{score_with_indices2}"
puts "Test 2 - Indices: #{indices2}"

# Test 3: Fuzzy match "hello" in "hello world"
score3 = matcher.fuzzy_match(haystack2, needle2)
puts "\nTest 3 - Crystal fuzzy_match('hello world', 'hello') = #{score3}"

indices3 = [] of UInt32
score_with_indices3 = matcher.fuzzy_indices(haystack2, needle2, indices3)
puts "Test 3 - Crystal fuzzy_indices('hello world', 'hello') = #{score_with_indices3}"
puts "Test 3 - Indices: #{indices3}"

# Test 4: Prefix match (^hello) - simulate with exact match at start
puts "\nTest 4 - Testing prefix match behavior:"
# For prefix match, we need to check if "hello" matches at the beginning of "hello world"
# This should be similar to fuzzy match but with prefix bonus
score4 = matcher.fuzzy_match(haystack2, needle2)
puts "Crystal fuzzy_match('hello world', 'hello') = #{score4} (should be 140)"

# Test 5: Additional test cases from Rust
puts "\nTest 5 - Additional test cases:"
# Test case from Rust: "hello" in "Hello"
score5 = matcher.fuzzy_match("Hello", "hello")
puts "Crystal fuzzy_match('Hello', 'hello') = #{score5} (case insensitive match)"

# Test case: empty needle
score6 = matcher.fuzzy_match("hello world", "")
puts "Crystal fuzzy_match('hello world', '') = #{score6} (empty needle)"

# Test case: needle longer than haystack
score7 = matcher.fuzzy_match("hello", "hello world")
puts "Crystal fuzzy_match('hello', 'hello world') = #{score7} (needle longer than haystack)"
