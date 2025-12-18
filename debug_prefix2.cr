require "./src/nucleoc"

config = Nucleoc::Config::DEFAULT

# Calculate bonus for each character in "hello"
prev_class = config.initial_char_class
total_score = 0_u16

"hello".chars.each_with_index do |char, i|
  char_class = Nucleoc::Chars.char_class(char, config)
  bonus = config.bonus_for(prev_class, char_class)

  if i == 0
    char_score = (bonus * 2) + 16 # BONUS_FIRST_CHAR_MULTIPLIER * bonus + SCORE_MATCH
    puts "Char #{i} '#{char}': bonus=#{bonus}, first_char_multiplier=2, SCORE_MATCH=16, score=#{char_score}"
  else
    char_score = bonus + 16 # bonus + SCORE_MATCH
    puts "Char #{i} '#{char}': bonus=#{bonus}, SCORE_MATCH=16, score=#{char_score}"
  end

  total_score += char_score
  prev_class = char_class
end

puts "\nTotal calculated score: #{total_score}"
puts "Actual prefix_match score: #{Nucleoc::Matcher.new.prefix_match("hello world", "hello")}"

# Let's also check what the Rust test expects
puts "\nExpected score from Rust test: 140"
puts "Difference: #{140 - total_score}"

# Check if there's a prefix bonus scale
puts "\nPREFIX_BONUS_SCALE = #{Nucleoc::PREFIX_BONUS_SCALE}"
puts "If we multiply by PREFIX_BONUS_SCALE: #{total_score} * #{Nucleoc::PREFIX_BONUS_SCALE} = #{total_score * Nucleoc::PREFIX_BONUS_SCALE}"
