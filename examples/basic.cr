require "../src/nucleoc"

# Basic example of using nucleoc
puts "Nucleoc v#{Nucleoc::VERSION}"
puts "=" * 40

# Create a matcher with default configuration
matcher = Nucleoc::Matcher.new

puts "1. EXACT MATCHING"
puts "-" * 40

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

puts "\n\n2. FUZZY MATCHING"
puts "-" * 40

# Basic fuzzy matching
puts "Basic fuzzy matching:"
if score = matcher.fuzzy_match("hello world", "hlo")
  puts "  'hello world' matches 'hlo' with score: #{score}"
end
if score = matcher.fuzzy_match("hello world", "hw")
  puts "  'hello world' matches 'hw' with score: #{score}"
end
if score = matcher.fuzzy_match("hello world", "xyz")
  puts "  'hello world' matches 'xyz' with score: #{score}"
else
  puts "  'hello world' does NOT match 'xyz'"
end

# Fuzzy matching with indices
puts "\nFuzzy matching with indices:"
indices.clear
if score = matcher.fuzzy_indices("hello world", "hlo", indices)
  puts "  'hello world' matches 'hlo' with score: #{score}, indices: #{indices}"
end

# Greedy vs optimal algorithm
puts "\nGreedy vs optimal fuzzy matching:"
score_greedy = matcher.fuzzy_match_greedy("hello world", "hlo")
score_optimal = matcher.fuzzy_match("hello world", "hlo")
puts "  Greedy algorithm score: #{score_greedy}"
puts "  Optimal algorithm score: #{score_optimal}"

puts "\n\n3. SUBSTRING, PREFIX, AND POSTFIX MATCHING"
puts "-" * 40

# Substring matching
puts "Substring matching:"
if score = matcher.substring_match("hello world", "world")
  puts "  'hello world' contains 'world' with score: #{score}"
end
if score = matcher.substring_match("hello world", "lo wo")
  puts "  'hello world' contains 'lo wo' with score: #{score}"
end

# Prefix matching
puts "\nPrefix matching:"
if score = matcher.prefix_match("hello world", "hello")
  puts "  'hello world' starts with 'hello' with score: #{score}"
end
if score = matcher.prefix_match("  hello world", "hello")
  puts "  '  hello world' starts with 'hello' (ignores leading whitespace) with score: #{score}"
end

# Postfix matching
puts "\nPostfix matching:"
if score = matcher.postfix_match("hello world", "world")
  puts "  'hello world' ends with 'world' with score: #{score}"
end
if score = matcher.postfix_match("hello world  ", "world")
  puts "  'hello world  ' ends with 'world' (ignores trailing whitespace) with score: #{score}"
end

puts "\n\n4. PATTERN PARSING"
puts "-" * 40

# Basic pattern parsing
pattern = Nucleoc::Pattern.parse("hello world")
puts "Pattern 'hello world' (space = AND):"
if score = pattern.match(matcher, "hello beautiful world")
  puts "  Matches 'hello beautiful world' with score: #{score}"
end

# Pattern syntax examples
puts "\nPattern syntax examples:"
patterns = [
  "'world",   # substring match
  "^hello",   # prefix match
  "world$",   # postfix match
  "^hello$",  # exact match
  "!error",   # negative match
  "\\!hello", # escaped '!' (literal !hello)
]

patterns.each do |pat|
  pattern = Nucleoc::Pattern.parse(pat)
  puts "  #{pat} -> #{pattern.inspect}"
end

puts "\n\n5. CONFIGURATION"
puts "-" * 40

# Custom configuration
config = Nucleoc::Config.new(
  ignore_case: false,
  normalize: true,
  prefer_prefix: true,
  delimiter_chars: "/,:;|"
)
custom_matcher = Nucleoc::Matcher.new(config)
puts "Custom configuration (case-sensitive, prefer_prefix):"

# Case-sensitive matching
puts "Case-sensitive matching:"
if score = custom_matcher.fuzzy_match("HelloWorld", "HW")
  puts "  'HelloWorld' matches 'HW' with score: #{score}"
else
  puts "  'HelloWorld' does NOT match 'HW' (case-sensitive)"
end
if score = custom_matcher.fuzzy_match("HelloWorld", "hw")
  puts "  'HelloWorld' matches 'hw' with score: #{score}"
else
  puts "  'HelloWorld' does NOT match 'hw' (case-sensitive)"
end

# Show prefer_prefix effect
puts "\nPrefer prefix bonus:"
if score = custom_matcher.fuzzy_match("prefix_suffix", "pref")
  puts "  'prefix_suffix' matches 'pref' with score: #{score}"
end
# Compare with default config (no prefer_prefix)
default_matcher = Nucleoc::Matcher.new
if default_score = default_matcher.fuzzy_match("prefix_suffix", "pref")
  puts "  With default config (no prefer_prefix): score: #{default_score}"
end

# Path matching configuration
path_config = Nucleoc::Config::DEFAULT.match_paths
path_matcher = Nucleoc::Matcher.new(path_config)
puts "\nPath matching configuration:"
if score = path_matcher.fuzzy_match("src/nucleoc/matcher.cr", "matcher.cr")
  puts "  'src/nucleoc/matcher.cr' matches 'matcher.cr' with score: #{score}"
end

puts "\n\n6. PARALLEL MATCHING"
puts "-" * 40

# Parallel matching
haystacks = ["hello", "world", "foo", "bar", "crystal", "nucleoc"]
needle = "lo"
puts "Parallel fuzzy match #{haystacks.size} haystacks with needle '#{needle}':"
scores = Nucleoc.parallel_fuzzy_match(haystacks, needle)
scores.each_with_index do |match_score, i|
  if match_score
    puts "  '#{haystacks[i]}': #{match_score}"
  else
    puts "  '#{haystacks[i]}': no match"
  end
end

puts "\n" + "=" * 40
puts "Example completed successfully!"
