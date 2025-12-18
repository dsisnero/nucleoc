require "./src/nucleoc"

puts "Testing normalization:"
matcher = Nucleoc::Matcher.new
indices = [] of UInt32

# Test with decomposed unicode
score = matcher.fuzzy_indices("cafe\u{0301}", "café", indices)
puts "Score for 'café' in 'cafe\\u{0301}': #{score.inspect}"
puts "Indices: #{indices.inspect}"

# Also test the reverse
indices.clear
score2 = matcher.fuzzy_indices("café", "cafe\u{0301}", indices)
puts "\nScore for 'cafe\\u{0301}' in 'café': #{score2.inspect}"
puts "Indices: #{indices.inspect}"

# Test with ASCII
indices.clear
score3 = matcher.fuzzy_indices("cafe", "cafe", indices)
puts "\nScore for 'cafe' in 'cafe': #{score3.inspect}"
puts "Indices: #{indices.inspect}"
