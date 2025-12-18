require "./src/nucleoc"

matcher = Nucleoc::Matcher.new

# Test 1: Exact match with equal strings
score1 = matcher.exact_match("hello", "hello")
puts "exact_match(\"hello\", \"hello\") = #{score1.inspect}"

# Test 2: Exact match with whitespace in haystack
score2 = matcher.exact_match("  hello  ", "hello")
puts "exact_match(\"  hello  \", \"hello\") = #{score2.inspect}"

# Test 3: Exact match with whitespace in needle
score3 = matcher.exact_match("hello world", "hello")
puts "exact_match(\"hello world\", \"hello\") = #{score3.inspect}"

# Test 4: Exact match with whitespace in both
score4 = matcher.exact_match("  hello world  ", "hello")
puts "exact_match(\"  hello world  \", \"hello\") = #{score4.inspect}"
