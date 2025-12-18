require "./src/nucleoc"

# Test the prefer_prefix functionality
config = Nucleoc::Config.new(prefer_prefix: true)
matcher = Nucleoc::Matcher.new(config)

# Test case from the spec
haystack1 = "foo bar baz"
haystack2 = "xfoo bar baz"
needle = "fbb"

puts "Testing with prefer_prefix=true:"
score1 = matcher.fuzzy_match(haystack1, needle)
score2 = matcher.fuzzy_match(haystack2, needle)

puts "Score1 (starts at beginning): #{score1}"
puts "Score2 (doesn't start at beginning): #{score2}"

# Now test with prefer_prefix=false
config2 = Nucleoc::Config.new(prefer_prefix: false)
matcher2 = Nucleoc::Matcher.new(config2)

puts "\nTesting with prefer_prefix=false:"
score1 = matcher2.fuzzy_match(haystack1, needle)
score2 = matcher2.fuzzy_match(haystack2, needle)

puts "Score1 (starts at beginning): #{score1}"
puts "Score2 (doesn't start at beginning): #{score2}"
