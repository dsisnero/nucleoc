require "../src/nucleoc"

# Basic example of using nucleoc
puts "Nucleoc v#{Nucleoc::VERSION}"
puts "=" * 40

# Create a matcher with default configuration
matcher = Nucleoc::Matcher.new

# Test exact matching
puts "Exact matching:"
puts "  'hello world' matches 'hello world': #{matcher.exact_match("hello world", "hello world") != nil}"
puts "  'hello world' matches 'goodbye': #{matcher.exact_match("hello world", "goodbye") != nil}"

# Test case insensitive matching (default)
puts "\nCase insensitive matching (default):"
puts "  'Hello' matches 'hello': #{matcher.exact_match("Hello", "hello") != nil}"
puts "  'HELLO' matches 'hello': #{matcher.exact_match("HELLO", "hello") != nil}"

# Test with indices
puts "\nExact matching with indices:"
indices = [] of UInt32
score = matcher.exact_indices("crystal", "crystal", indices)
puts "  'crystal' matches 'crystal' with indices: #{indices}"

# Create a case-sensitive matcher
config = Nucleoc::Config.new(ignore_case: false)
case_sensitive_matcher = Nucleoc::Matcher.new(config)

puts "\nCase sensitive matching:"
puts "  'Hello' matches 'hello': #{case_sensitive_matcher.exact_match("Hello", "hello") != nil}"
puts "  'Hello' matches 'Hello': #{case_sensitive_matcher.exact_match("Hello", "Hello") != nil}"
