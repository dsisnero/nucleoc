require "./src/nucleoc"
require "./spec/test_helpers"

# Test the specific cases that are failing
puts "Testing score calculations:"

# Test 1: "obr" matching "fooBarbaz1" with Substring algorithm
config = Nucleoc::Config.new(normalize: true, ignore_case: true, prefer_prefix: false)
matcher = Nucleoc::Matcher.new(config)
haystack = "fooBarbaz1"

puts "\n1. 'obr' matching 'fooBarbaz1' (Substring):"
indices = [] of UInt32
result = matcher.substring_match("obr", haystack, indices)
if result
  puts "  Score: #{result}"
  puts "  Indices: #{indices}"
else
  puts "  No matches found"
end

# Test 2: "Bar" matching "fooBarbaz1" with Substring algorithm (case sensitive)
config2 = Nucleoc::Config.new(normalize: true, ignore_case: false, prefer_prefix: false)
matcher2 = Nucleoc::Matcher.new(config2)
puts "\n2. 'Bar' matching 'fooBarbaz1' (Substring, case sensitive):"
result2 = matcher2.substring_match("Bar", haystack)
if result2
  puts "  Score: #{result2.score}"
  puts "  Indices: #{result2.indices}"
else
  puts "  No matches found"
end

# Test 3: "Bar" matching "fooBarbaz1" with FuzzyOptimal algorithm (case sensitive)
puts "\n3. 'Bar' matching 'fooBarbaz1' (FuzzyOptimal, case sensitive):"
result3 = matcher2.fuzzy_match("Bar", haystack, optimal: true)
if result3
  puts "  Score: #{result3.score}"
  puts "  Indices: #{result3.indices}"
else
  puts "  No matches found"
end

# Test 4: "obr" matching "fooBarbaz1" with FuzzyOptimal algorithm
puts "\n4. 'obr' matching 'fooBarbaz1' (FuzzyOptimal):"
result4 = matcher.fuzzy_match("obr", haystack, optimal: true)
if result4
  puts "  Score: #{result4.score}"
  puts "  Indices: #{result4.indices}"
else
  puts "  No matches found"
end

# Test 5: "你好" matching "你好世界" with FuzzyOptimal
haystack5 = "你好世界"
puts "\n5. '你好' matching '你好世界' (FuzzyOptimal):"
result5 = matcher.fuzzy_match("你好", haystack5, optimal: true)
if result5
  puts "  Score: #{result5.score}"
  puts "  Indices: #{result5.indices}"
else
  puts "  No matches found"
end

# Test 6: "fbb" matching "fooBarbaz1" with FuzzyOptimal
puts "\n6. 'fbb' matching 'fooBarbaz1' (FuzzyOptimal):"
result6 = matcher.fuzzy_match("fbb", haystack, optimal: true)
if result6
  puts "  Score: #{result6.score}"
  puts "  Indices: #{result6.indices}"
else
  puts "  No matches found"
end

# Test 7: "abcd" matching "axxx xxcx xxdx" with FuzzyOptimal
haystack7 = "axxx xxcx xxdx"
puts "\n7. 'abcd' matching 'axxx xxcx xxdx' (FuzzyOptimal):"
result7 = matcher.fuzzy_match("abcd", haystack7, optimal: true)
if result7
  puts "  Score: #{result7.score}"
  puts "  Indices: #{result7.indices}"
else
  puts "  No matches found"
end

# Test 8: "z" matching "fooBarbaz1" with FuzzyOptimal
puts "\n8. 'z' matching 'fooBarbaz1' (FuzzyOptimal):"
result8 = matcher.fuzzy_match("z", haystack, optimal: true)
if result8
  puts "  Score: #{result8.score}"
  puts "  Indices: #{result8.indices}"
else
  puts "  No matches found"
end

# Test 9: "md" matching "Moby Dick" with FuzzyOptimal
haystack9 = "Moby Dick"
puts "\n9. 'md' matching 'Moby Dick' (FuzzyOptimal):"
result9 = matcher.fuzzy_match("md", haystack9, optimal: true)
if result9
  puts "  Score: #{result9.score}"
  puts "  Indices: #{result9.indices}"
else
  puts "  No matches found"
end

# Test 10: "o" matching "foO" with FuzzyOptimal
haystack10 = "foO"
puts "\n10. 'o' matching 'foO' (FuzzyOptimal):"
result10 = matcher.fuzzy_match("o", haystack10, optimal: true)
if result10
  puts "  Score: #{result10.score}"
  puts "  Indices: #{result10.indices}"
else
  puts "  No matches found"
end

# Test umlaut normalization
puts "\n11. Umlaut normalization test:"
haystack11 = "Über"
result11 = matcher.fuzzy_match("uber", haystack11, optimal: true)
puts "  'uber' matching 'Über' (FuzzyOptimal):"
if result11
  puts "  Score: #{result11.score}"
  puts "  Indices: #{result11.indices}"
else
  puts "  No matches found"
end

haystack12 = "Uber"
result12 = matcher.fuzzy_match("uber", haystack12, optimal: true)
puts "  'uber' matching 'Uber' (FuzzyOptimal):"
if result12
  puts "  Score: #{result12.score}"
  puts "  Indices: #{result12.indices}"
else
  puts "  No matches found"
end