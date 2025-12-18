require "./src/nucleoc"

# Full trace including second row
config = Nucleoc::Config.new(normalize: false, ignore_case: true, prefer_prefix: false)

SCORE_MATCH = Nucleoc::SCORE_MATCH
BONUS_FIRST_CHAR_MULTIPLIER = Nucleoc::BONUS_FIRST_CHAR_MULTIPLIER
PENALTY_GAP_START = Nucleoc::PENALTY_GAP_START
PENALTY_GAP_EXTENSION = Nucleoc::PENALTY_GAP_EXTENSION
BONUS_CONSECUTIVE = Nucleoc::BONUS_CONSECUTIVE
BONUS_BOUNDARY = Nucleoc::BONUS_BOUNDARY

haystack = ['o', 'o', 'b', 'a', 'r']  # normalized
bonus = [0_u8, 0_u8, 5_u8, 0_u8, 0_u8]
row_offs = [0_u16, 2_u16, 4_u16]
needle = ['o', 'b', 'r']

haystack_len = 5
needle_len = 3
current_row_size = 3

# After first row (from previous trace):
current_row_scores = [37_u16, 0_u16, 0_u16]
current_row_matched = [true, true, true]  # UNMATCHED has matched=true

puts "After first row, current_row scores: #{current_row_scores}"
puts "These are scores for matching needle[1]='b' at positions offset from row_offs[1]=2"
puts "  current_row[0] = score at position 2 (relative to row 1)"
puts "  current_row[1] = score at position 3"
puts "  current_row[2] = score at position 4"

# Now process the second row (needle[1]='b' -> needle[2]='r')
# Rust's populate_matrix loop calls score_row with:
#   row_off=row_offs[1]=2, next_row_off=row_offs[2]=4
#   needle_idx=1, needle_char='b', next_needle_char='r'

n = 1  # This is needle_idx in Rust
row_off = row_offs[n]  # 2
next_row_off = row_offs[n + 1]  # 4

puts "\nSecond row (n=#{n}):"
puts "  row_off=#{row_off}, next_row_off=#{next_row_off}"
puts "  needle_char='#{needle[n]}', next_needle_char='#{needle[n + 1]}'"

adj_next_row_off = next_row_off - 1  # 3
relative_row_off = row_off.to_i - n  # 2 - 1 = 1
next_relative_row_off = adj_next_row_off.to_i - n  # 3 - 1 = 2

puts "  adj_next_row_off=#{adj_next_row_off}"
puts "  relative_row_off=#{relative_row_off}, next_relative_row_off=#{next_relative_row_off}"

prev_p_score = 0_u16
prev_m_score = 0_u16

puts "\nFirst loop (columns #{row_off} to #{adj_next_row_off - 1}):"
(row_off.to_i...adj_next_row_off.to_i).each do |i|
  relative_i = i - relative_row_off  # i - 1
  
  # calc_p_score
  score_match = prev_m_score > PENALTY_GAP_START ? prev_m_score - PENALTY_GAP_START : 0_u16
  score_skip = prev_p_score > PENALTY_GAP_EXTENSION ? prev_p_score - PENALTY_GAP_EXTENSION : 0_u16
  p_score = score_match > score_skip ? score_match : score_skip
  
  # m_cell from current_row (not first row)
  if relative_i >= 0 && relative_i < current_row_size
    m_cell_score = current_row_scores[relative_i]
    m_cell_matched = current_row_matched[relative_i]
  else
    m_cell_score = 0_u16
    m_cell_matched = true  # UNMATCHED
  end
  
  puts "  [#{i}] relative_i=#{relative_i} p_score=#{p_score} m_cell.score=#{m_cell_score}"
  
  prev_p_score = p_score
  prev_m_score = m_cell_score
end

puts "\nSecond loop (columns #{adj_next_row_off} to #{haystack.size - 2}):"
(adj_next_row_off.to_i...(haystack.size - 1)).each do |i|
  relative_i = i - relative_row_off
  row_idx = i - adj_next_row_off.to_i
  
  # calc_p_score
  score_match = prev_m_score > PENALTY_GAP_START ? prev_m_score - PENALTY_GAP_START : 0_u16
  score_skip = prev_p_score > PENALTY_GAP_EXTENSION ? prev_p_score - PENALTY_GAP_EXTENSION : 0_u16
  p_score = score_match > score_skip ? score_match : score_skip
  
  # m_cell from current_row
  if relative_i >= 0 && relative_i < current_row_size
    m_cell_score = current_row_scores[relative_i]
    m_cell_matched = current_row_matched[relative_i]
  else
    m_cell_score = 0_u16
    m_cell_matched = true
  end
  
  puts "  [#{i}] relative_i=#{relative_i} row_idx=#{row_idx} p_score=#{p_score} m_cell.score=#{m_cell_score}"
  
  # Check if haystack[i+1] matches next_needle_char='r'
  if i + 1 < haystack.size && haystack[i + 1] == needle[n + 1]
    # next_m_cell
    if m_cell_matched && m_cell_score == 0  # UNMATCHED
      new_score = p_score + bonus[i + 1].to_u16 + SCORE_MATCH
      puts "    [i+1=#{i+1}] matches 'r': new_score=#{new_score} (from UNMATCHED)"
    else
      consecutive_bonus = [0_u16, BONUS_CONSECUTIVE].max  # m_cell.consecutive_bonus is 0 for UNMATCHED
      score_match_opt = m_cell_score + [consecutive_bonus, bonus[i + 1].to_u16].max
      score_skip_opt = p_score + bonus[i + 1].to_u16
      if score_match_opt > score_skip_opt
        new_score = score_match_opt + SCORE_MATCH
        puts "    [i+1=#{i+1}] matches 'r': new_score=#{new_score} (from match)"
      else
        new_score = score_skip_opt + SCORE_MATCH
        puts "    [i+1=#{i+1}] matches 'r': new_score=#{new_score} (from skip)"
      end
    end
    current_row_scores[row_idx] = new_score
    current_row_matched[row_idx] = new_score > 0
  else
    current_row_scores[row_idx] = 0_u16
    current_row_matched[row_idx] = true  # UNMATCHED
    puts "    [i+1=#{i+1}] '#{haystack[i+1]? || "N/A"}' != 'r': UNMATCHED"
  end
  
  prev_p_score = p_score
  prev_m_score = m_cell_score
end

puts "\ncurrent_row after second row: #{current_row_scores}"

# Find best score
last_row_off = row_offs[needle_len - 1]  # 4
relative_last_row_off = last_row_off.to_i + 1 - needle_len  # 4 + 1 - 3 = 2

puts "\nFinding best score:"
puts "  last_row_off=#{last_row_off}, relative_last_row_off=#{relative_last_row_off}"
puts "  Searching current_row[#{relative_last_row_off}...#{current_row_size}]"

best_score = 0_u16
(relative_last_row_off...current_row_size).each do |i|
  puts "  current_row[#{i}] = #{current_row_scores[i]}"
  if current_row_scores[i] > best_score
    best_score = current_row_scores[i]
  end
end

puts "\nbest_score = #{best_score}"
if best_score == 0
  puts "Algorithm returns nil!"
end
