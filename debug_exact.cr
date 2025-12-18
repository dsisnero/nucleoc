require "./src/nucleoc"

# Create a matcher
config = Nucleoc::Config.new
matcher = Nucleoc::Matcher.new(config)

# Test exact match
haystack = "hello world"
needle = "hello"

puts "Testing exact match: '#{needle}' in '#{haystack}'"

# Get the score
score = matcher.exact_match(haystack, needle)
puts "Score: #{score}"

# Let's trace through the calculation manually
puts "\nManual calculation:"
puts "SCORE_MATCH = 16"
puts "BONUS_BOUNDARY = 8"
puts "BONUS_CONSECUTIVE = 4"
puts "BONUS_FIRST_CHAR_MULTIPLIER = 2"

# Check char classes
puts "\nCharacter classes:"
haystack.chars.each_with_index do |char, i|
  char_class = Nucleoc::Chars.char_class(char, config)
  puts "  '#{char}' at #{i}: #{char_class}"
end

# Let's trace the exact match scoring
puts "\nTracing exact match scoring:"
prev_class = config.initial_char_class
score = 0_u16
consecutive_bonus = 0_u16
last_matched_idx = -1

haystack.chars.each_with_index do |char, i|
  break if i >= needle.size # Only first 5 chars

  char_class = Nucleoc::Chars.char_class(char, config)
  bonus = config.bonus_for(prev_class, char_class)

  puts "\nChar #{i} ('#{char}'):"
  puts "  prev_class: #{prev_class}"
  puts "  char_class: #{char_class}"
  puts "  bonus: #{bonus}"
  puts "  last_matched_idx: #{last_matched_idx}"
  puts "  consecutive_bonus before: #{consecutive_bonus}"

  if last_matched_idx == i - 1
    consecutive_bonus = Math.max(consecutive_bonus, Nucleoc::Matcher::BONUS_CONSECUTIVE)
    if bonus >= Nucleoc::Matcher::BONUS_BOUNDARY && bonus > consecutive_bonus
      consecutive_bonus = bonus
    end
  else
    consecutive_bonus = bonus
  end

  puts "  consecutive_bonus after: #{consecutive_bonus}"

  match_bonus = Math.max(consecutive_bonus, bonus)
  puts "  match_bonus: #{match_bonus}"

  score += Nucleoc::Matcher::SCORE_MATCH + match_bonus
  puts "  score after SCORE_MATCH + match_bonus: #{score}"

  if i == 0
    score += match_bonus * (Nucleoc::Matcher::BONUS_FIRST_CHAR_MULTIPLIER - 1)
    puts "  first char bonus added: #{match_bonus * (Nucleoc::Matcher::BONUS_FIRST_CHAR_MULTIPLIER - 1)}"
    puts "  score after first char bonus: #{score}"
  end

  last_matched_idx = i
  prev_class = char_class
end

puts "\nFinal calculated score: #{score}"
