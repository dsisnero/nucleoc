require "./src/nucleoc"

matcher = Nucleoc::Matcher.new
score = matcher.exact_match("hello", "hello")
puts "Exact match 'hello' in 'hello': #{score}"
puts "Expected: 140"
puts "Got: #{score.inspect}"
