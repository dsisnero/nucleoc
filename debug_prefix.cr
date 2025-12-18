require "./src/nucleoc"

matcher = Nucleoc::Matcher.new

# Test prefix_match
score = matcher.prefix_match("hello world", "hello")
puts "prefix_match(\"hello world\", \"hello\") = #{score.inspect}"

# Test prefix_indices
indices = [] of UInt32
score2 = matcher.prefix_indices("hello world", "hello", indices)
puts "prefix_indices(\"hello world\", \"hello\", indices) = #{score2.inspect}"
puts "indices = #{indices.inspect}"

# Test exact_match
score3 = matcher.exact_match("café", "cafe\u{0301}")
puts "exact_match(\"café\", \"cafe\\u{0301}\") = #{score3.inspect}"

# Test the prefer_prefix test
config = Nucleoc::Config.new(prefer_prefix: true)
matcher2 = Nucleoc::Matcher.new(config)

indices1 = [] of UInt32
score1 = matcher2.fuzzy_indices("foo bar baz", "fbb", indices1)
puts "fuzzy_indices(\"foo bar baz\", \"fbb\") = #{score1.inspect}"

indices2 = [] of UInt32
score2 = matcher2.fuzzy_indices("xfoo bar baz", "fbb", indices2)
puts "fuzzy_indices(\"xfoo bar baz\", \"fbb\") = #{score2.inspect}"

# Let's also check the bonus calculation
puts "\nChecking bonus calculation for 'h' (first char of 'hello'):"
puts "Char class of 'h': #{Nucleoc::Chars.char_class('h', Nucleoc::Config::DEFAULT)}"
puts "Initial char class: #{Nucleoc::Config::DEFAULT.initial_char_class}"
puts "Bonus for first char: #{Nucleoc::Config::DEFAULT.bonus_for(Nucleoc::Config::DEFAULT.initial_char_class, Nucleoc::Chars.char_class('h', Nucleoc::Config::DEFAULT))}"
