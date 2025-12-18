require "./src/nucleoc"

matcher = Nucleoc::Matcher.new
haystack = "hello world"
needle = "hw"

puts "Testing fuzzy_match with '#{haystack}' and '#{needle}'"
score = matcher.fuzzy_match(haystack, needle)
puts "Score: #{score.inspect}"

puts "\nTesting fuzzy_match_greedy directly:"
score2 = matcher.fuzzy_match_greedy(haystack, needle)
puts "Greedy score: #{score2.inspect}"

puts "\nTesting with indices:"
indices = [] of UInt32
score3 = matcher.fuzzy_indices(haystack, needle, indices)
puts "Indices score: #{score3.inspect}"
puts "Indices: #{indices.inspect}"
