require "./src/nucleoc"

matcher = Nucleoc::Matcher.new

puts "=== Testing exact_match ==="
score1 = matcher.exact_match("hello", "hello")
puts "Crystal exact_match('hello', 'hello') = #{score1.inspect}"

score2 = matcher.exact_match("hello world", "hello")
puts "Crystal exact_match('hello world', 'hello') = #{score2.inspect}"

score3 = matcher.exact_match("Hello", "hello")
puts "Crystal exact_match('Hello', 'hello') = #{score3.inspect}"

score4 = matcher.exact_match("hello", "world")
puts "Crystal exact_match('hello', 'world') = #{score4.inspect}"

puts "\n=== Testing exact_indices ==="
indices1 = [] of UInt32
score_with_indices1 = matcher.exact_indices("hello", "hello", indices1)
puts "Crystal exact_indices('hello', 'hello') = #{score_with_indices1.inspect}"
puts "Crystal Indices: #{indices1}"

indices2 = [] of UInt32
score_with_indices2 = matcher.exact_indices("hello world", "hello", indices2)
puts "Crystal exact_indices('hello world', 'hello') = #{score_with_indices2.inspect}"
puts "Crystal Indices: #{indices2}"

puts "\n=== Testing fuzzy_match ==="
score5 = matcher.fuzzy_match("hello world", "hello")
puts "Crystal fuzzy_match('hello world', 'hello') = #{score5.inspect}"

indices3 = [] of UInt32
score_with_indices3 = matcher.fuzzy_indices("hello world", "hello", indices3)
puts "Crystal fuzzy_indices('hello world', 'hello') = #{score_with_indices3.inspect}"
puts "Crystal Indices: #{indices3}"

puts "\n=== Testing 'obr' in 'fooBarbaz1' ==="
score6 = matcher.fuzzy_match("fooBarbaz1", "obr")
puts "Crystal fuzzy_match('fooBarbaz1', 'obr') = #{score6.inspect}"
