# Matcher module for nucleoc fuzzy matching library
module Nucleoc
  # Score cell for tracking matching state in optimal algorithm
  # Matches Rust's ScoreCell exactly
  private struct ScoreCell
    property score : UInt16
    property consecutive_bonus : UInt8
    property? matched : Bool

    def initialize(@score : UInt16 = 0_u16, @consecutive_bonus : UInt8 = 0_u8, @matched : Bool = true)
    end

    def ==(other : ScoreCell) : Bool
      @score == other.score && @consecutive_bonus == other.consecutive_bonus && matched? == other.matched?
    end

    # UNMATCHED constant - if matched is true then consecutive_bonus is always at least
    # BONUS_CONSECUTIVE so this constant can never occur naturally
    UNMATCHED = new(0_u16, 0_u8, true)
  end

  # Matrix cell for backtracking in optimal algorithm
  # Matches Rust's MatrixCell
  private struct MatrixCell
    @data : UInt8

    def initialize
      @data = 0_u8
    end

    def set(p_matched : Bool, m_matched : Bool) : self
      @data = (p_matched ? 1_u8 : 0_u8) | (m_matched ? 2_u8 : 0_u8)
      self
    end

    def get(m_matrix : Bool) : Bool
      if m_matrix
        (@data & 2_u8) != 0
      else
        (@data & 1_u8) != 0
      end
    end
  end

  # A matcher engine that can execute (fuzzy) matches.
  class Matcher
    MAX_MATRIX_SIZE  = 100 * 1024 # 100KB
    MAX_HAYSTACK_LEN = 2048
    MAX_NEEDLE_LEN   =  128

    @config : Config

    def initialize(@config : Config = Config::DEFAULT)
    end

    private def bonus_for(prev_class : CharClass, char_class : CharClass) : UInt16
      @config.bonus_for(prev_class, char_class)
    end

    # Find the fuzzy match with the highest score in the `haystack`.
    def fuzzy_match(haystack : String, needle : String) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      indices = [] of UInt32
      fuzzy_match_impl(haystack, needle, indices, false)
    end

    # Find the fuzzy match with the highest score and compute indices.
    def fuzzy_indices(haystack : String, needle : String, indices : Array(UInt32)) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      fuzzy_match_impl(haystack, needle, indices, true)
    end

    private def fuzzy_match_impl(haystack : String, needle : String, indices : Array(UInt32), compute_indices : Bool) : UInt16?
      # Prefilter to find match bounds (like Rust)
      prefilter_result = prefilter(haystack, needle)
      return unless prefilter_result

      start, greedy_end, end_idx = prefilter_result

      # If exact length match, use optimized path
      if needle.size == end_idx - start
        return calculate_score(haystack.chars, needle.chars, start, greedy_end, indices)
      end

      fuzzy_match_optimal(haystack, needle, start, greedy_end, end_idx, indices, compute_indices)
    end

    # Prefilter to find match bounds - matches Rust prefilter_ascii/prefilter_non_ascii
    private def prefilter(haystack : String, needle : String) : Tuple(Int32, Int32, Int32)?
      haystack_chars = haystack.chars
      needle_chars = needle.chars

      return if needle_chars.empty?
      return if haystack_chars.size < needle_chars.size

      # Find first needle char
      first_needle = Chars.normalize(needle_chars[0], @config)
      start = nil
      max_start = haystack_chars.size - needle_chars.size
      (0..max_start).each do |i|
        if Chars.normalize(haystack_chars[i], @config) == first_needle
          start = i
          break
        end
      end
      return unless start

      # Greedy forward match to find greedy_end
      greedy_end = start + 1
      haystack_idx = start + 1
      needle_chars[1..].each do |nc|
        nc_normalized = Chars.normalize(nc, @config)
        found = false
        while haystack_idx < haystack_chars.size
          if Chars.normalize(haystack_chars[haystack_idx], @config) == nc_normalized
            greedy_end = haystack_idx + 1
            haystack_idx += 1
            found = true
            break
          end
          haystack_idx += 1
        end
        return unless found
      end

      # Find last occurrence of last needle char at or after greedy_end-1
      last_needle = Chars.normalize(needle_chars[-1], @config)
      end_idx = greedy_end
      start_search = greedy_end - 1
      start_search = 0 if start_search < 0
      (start_search...haystack_chars.size).each do |i|
        if Chars.normalize(haystack_chars[i], @config) == last_needle
          end_idx = i + 1
        end
      end

      {start, greedy_end, end_idx}
    end

    # Internal optimal matching implementation - matches Rust fuzzy_match_optimal
    private def fuzzy_match_optimal(haystack : String, needle : String, start : Int32, greedy_end : Int32, end_idx : Int32, indices : Array(UInt32), compute_indices : Bool) : UInt16?
      haystack_chars = haystack.chars
      needle_chars = needle.chars
      haystack_len = end_idx - start
      needle_len = needle_chars.size

      return if needle_len > haystack_len

      debug = (haystack == "/usr/share/doc/at/ChangeLog" && needle == "changelog") || (haystack == "abc" && needle == "ac")

      # Check if matrix would be too large - fall back to greedy
      cells = haystack_len * needle_len
      if cells > MAX_MATRIX_SIZE || haystack_len > MAX_HAYSTACK_LEN || needle_len > MAX_NEEDLE_LEN
        return fuzzy_match_greedy_(haystack, needle, start, greedy_end, indices)
      end

      # Optimal algorithm implementation complete
      # Continue with optimal matching

      # Allocate working arrays (simulating Rust's slab.alloc)
      # Work on the sliced haystack [start..end_idx]
      sliced_haystack = Array(Char).new(haystack_len) { |i| haystack_chars[start + i] }
      bonus = Array(UInt8).new(haystack_len, 0_u8)
      row_offs = Array(UInt16).new(needle_len, 0_u16)
      current_row = Array(ScoreCell).new(haystack_len + 1 - needle_len) { ScoreCell::UNMATCHED }
      matrix_cells = Array(MatrixCell).new((haystack_len + 1 - needle_len) * needle_len) { MatrixCell.new }

      debug = (haystack == "/usr/share/doc/at/ChangeLog" && needle == "changelog") || (haystack == "abc" && needle == "ac")

      # Setup phase - normalize haystack and find first occurrence of each needle char
      prev_class = start > 0 ? Chars.char_class(haystack_chars[start - 1], @config) : @config.initial_char_class

      # Iterator state for finding needle chars
      row_iter_idx = 0
      needle_char = Chars.normalize(needle_chars[0], @config)
      matched = false

      haystack_len.times do |i|
        # Normalize haystack char in place and get char class
        c = sliced_haystack[i]
        char_class = Chars.char_class(c, @config)
        normalized_c = Chars.normalize(c, @config)
        sliced_haystack[i] = normalized_c

        # Calculate bonus
        bonus[i] = bonus_for(prev_class, char_class).to_u8
        prev_class = char_class

        # Find first occurrence of each needle char
        if normalized_c == needle_char
          if row_iter_idx < needle_len - 1
            row_offs[row_iter_idx] = i.to_u16
            row_iter_idx += 1
            needle_char = Chars.normalize(needle_chars[row_iter_idx], @config)
            if debug
              puts "  Now looking for needle[#{row_iter_idx}]: #{needle_char.inspect}"
            end
          elsif !matched
            row_offs[row_iter_idx] = i.to_u16
            matched = true
            if debug
              puts "  Found last needle char, matched = true"
            end
            if debug
              puts "After score_row_first, current_row:"
              current_row.each_with_index do |cell, idx|
                puts "  [#{idx}] score=#{cell.score}, matched?=#{cell.matched?}, consecutive_bonus=#{cell.consecutive_bonus}"
              end
            end
          end
        end
      end

      if debug
        puts "Setup complete: matched = #{matched}, row_offs = #{row_offs}"
        puts "sliced_haystack (normalized): #{sliced_haystack.map(&.inspect).join(' ')}"
      end

      return unless matched

      # Rust asserts row_offs[0] == 0 because the sliced haystack starts at the first needle char
      # This should be true due to our prefilter

      # Normalize needle chars
      normalized_needle = needle_chars.map { |c| Chars.normalize(c, @config) }

      # Compute compressed matrix row offsets (Rust uses sliding slice, we precompute)
      # For each row i (0 <= i < needle_len - 1), matrix cells needed = haystack_len - 1 - row_offs[i]
      # Last row (needle_len - 1) doesn't need matrix cells for reconstruction
      matrix_row_offsets = Array(Int32).new(needle_len, 0)
      cumulative = 0
      (0...needle_len - 1).each do |i|
        matrix_row_offsets[i] = cumulative
        cumulative += haystack_len - 1 - row_offs[i].to_i
      end
      matrix_row_offsets[needle_len - 1] = cumulative # Not used but for completeness

      if debug
        puts "Compressed matrix layout:"
        puts "  Total cells needed: #{cumulative}"
        puts "  Rectangular cells: #{(haystack_len + 1 - needle_len) * needle_len}"
        puts "  Row offsets: #{matrix_row_offsets}"
        (0...needle_len - 1).each do |i|
          puts "  Row #{i}: offset=#{matrix_row_offsets[i]}, length=#{haystack_len - 1 - row_offs[i].to_i}"
        end
      end

      # Calculate prefix bonus for prefer_prefix mode
      prefix_bonus = if @config.prefer_prefix?
                       if start == 0
                         MAX_PREFIX_BONUS * PREFIX_BONUS_SCALE
                       else
                         (MAX_PREFIX_BONUS * PREFIX_BONUS_SCALE - PENALTY_GAP_START).to_i -
                           ((start - 1).clamp(0, UInt16::MAX.to_i) * PENALTY_GAP_EXTENSION).clamp(0, (MAX_PREFIX_BONUS * PREFIX_BONUS_SCALE - PENALTY_GAP_START).to_i)
                       end.to_u16
                     else
                       0_u16
                     end

      # Score the first row (setup calls score_row with FIRST_ROW=true)
      next_row_off = needle_len > 1 ? row_offs[1] : haystack_len.to_u16
      score_row_first(
        current_row, matrix_cells, sliced_haystack, bonus,
        0_u16, next_row_off, normalized_needle[0],
        needle_len > 1 ? normalized_needle[1] : normalized_needle[0],
        prefix_bonus, compute_indices
      )

      # Populate matrix - score remaining rows
      if needle_len > 1
        # Score rows for needle indices 1 through n-1
        # Rust uses needle[1..] and row_offs[1..]
        (1...needle_len).each do |n|
          row_off = row_offs[n]
          next_row_off = if n < needle_len - 1
                           row_offs[n + 1]
                         else
                           haystack_len.to_u16 # Last row, next_row_off is end of haystack
                         end

          score_row(
            current_row, matrix_cells, sliced_haystack, bonus,
            row_off, next_row_off, n.to_u16,
            normalized_needle[n], normalized_needle[n + 1]? || normalized_needle[n],
            matrix_row_offsets[n], compute_indices
          )
        end
      end

      if debug
        puts "Matrix cells after population (size #{matrix_cells.size}):"
        matrix_cells.each_with_index do |cell, idx|
          puts "  [#{idx}] data=#{cell.@data.to_s(2)} p=#{cell.get(false)} m=#{cell.get(true)}"
        end
      end

      # Find the best score in the last row
      last_row_off = row_offs[needle_len - 1]
      relative_last_row_off = last_row_off.to_i + 1 - needle_len

      if debug
        puts "Finding best score in last row:"
        puts "last_row_off: #{last_row_off}, relative_last_row_off: #{relative_last_row_off}"
        puts "current_row size: #{current_row.size}"
        puts "current_row cells:"
        current_row.each_with_index do |cell, idx|
          puts "  [#{idx}] score=#{cell.score}, matched?=#{cell.matched?}, consecutive_bonus=#{cell.consecutive_bonus}"
        end
      end

      best_score = 0_u16
      best_end = 0
      (relative_last_row_off...current_row.size).each do |i|
        if current_row[i].score > best_score
          best_score = current_row[i].score
          best_end = i - relative_last_row_off
          if debug
            puts "  New best score: #{best_score} at i=#{i}, best_end=#{best_end}"
          end
        end
      end

      if debug
        puts "Best score found: #{best_score} at end position #{best_end}"
      end

      return if best_score == 0

      # Reconstruct path if indices needed
      if compute_indices
        reconstruct_optimal_path(matrix_cells, current_row, row_offs, best_end.to_u16, indices, start.to_u32, matrix_row_offsets[needle_len - 1])
      end

      best_score
    end

    # Score the first row - matches Rust score_row with FIRST_ROW=true
    private def score_row_first(
      current_row : Array(ScoreCell),
      matrix_cells : Array(MatrixCell),
      haystack : Array(Char),
      bonus : Array(UInt8),
      row_off : UInt16,
      next_row_off : UInt16,
      needle_char : Char,
      next_needle_char : Char,
      prefix_bonus : UInt16,
      compute_indices : Bool,
      matrix_offset : Int32 = 0,
    )
      debug = (haystack.size == 5 && needle_char == 'o' && next_needle_char == 'b') || (haystack.size == 14 && needle_char == 'c') || (haystack.size == 3 && needle_char == 'a')
      adj_next_row_off = next_row_off - 1
      relative_row_off = row_off.to_i               # 0 for first row
      next_relative_row_off = adj_next_row_off.to_i # next_row_off - 1 for first row
      if debug
        puts "=== DEBUG score_row_first ==="
        puts "compute_indices: #{compute_indices}"
        puts "row_off: #{row_off}, next_row_off: #{next_row_off}"
        puts "adj_next_row_off: #{adj_next_row_off}, relative_row_off: #{relative_row_off}, next_relative_row_off: #{next_relative_row_off}"
        puts "current_row size: #{current_row.size}"
        puts "prefix_bonus: #{prefix_bonus}"
      end

      prev_p_score = 0_u16
      prev_m_score = 0_u16
      current_prefix_bonus = prefix_bonus

      # First loop: skipped columns (row_off to next_row_off-1)
      # In Rust, this iterates over current_row[relative_row_off..next_relative_row_off]
      matrix_idx = matrix_offset
      (row_off.to_i...adj_next_row_off.to_i).each do |i|
        p_score, p_matched = calc_p_score(prev_p_score, prev_m_score)

        # First row: calculate m_cell based on needle_char match
        m_cell = if haystack[i] == needle_char
                   ScoreCell.new(
                     bonus[i].to_u16 * BONUS_FIRST_CHAR_MULTIPLIER + SCORE_MATCH + current_prefix_bonus // PREFIX_BONUS_SCALE,
                     bonus[i],
                     false
                   )
                 else
                   ScoreCell::UNMATCHED
                 end
        current_prefix_bonus = current_prefix_bonus > PENALTY_GAP_EXTENSION ? current_prefix_bonus - PENALTY_GAP_EXTENSION : 0_u16

        if compute_indices && matrix_idx < matrix_cells.size
          matrix_cells[matrix_idx] = matrix_cells[matrix_idx].set(p_matched, m_cell.matched?)
          if debug
            puts "    matrix[#{matrix_idx}] set p=#{p_matched}, m=#{m_cell.matched?}"
          end
        end
        matrix_idx += 1

        prev_p_score = p_score
        prev_m_score = m_cell.score
      end

      # Second loop: columns from next_row_off-1 to end, using windows of 2
      # In Rust: iterates haystack[adj_next_row_off..].windows(2) paired with current_row[next_relative_row_off..]
      # Number of iterations = min(current_row[next_relative_row_off..].size, haystack[adj_next_row_off..].windows(2).size)
      max_iter = haystack.size - 1 - adj_next_row_off.to_i
      max_iter = 0 if max_iter < 0
      slice_len = Math.min(current_row.size - next_relative_row_off, max_iter)
      slice_len.times do |j|
        i = adj_next_row_off.to_i + j
        row_idx = next_relative_row_off + j

        p_score, p_matched = calc_p_score(prev_p_score, prev_m_score)
        if debug
          puts "  j=#{j}, i=#{i}, row_idx=#{row_idx}, p_score=#{p_score}, prev_m_score=#{prev_m_score}"
          puts "  haystack[i]=#{haystack[i].inspect}, needle_char=#{needle_char.inspect}, match=#{haystack[i] == needle_char}"
          puts "  bonus[i]=#{bonus[i]}, current_prefix_bonus=#{current_prefix_bonus}"
        end

        # First row: calculate m_cell for position i
        m_cell = if haystack[i] == needle_char
                   ScoreCell.new(
                     bonus[i].to_u16 * BONUS_FIRST_CHAR_MULTIPLIER + SCORE_MATCH + current_prefix_bonus // PREFIX_BONUS_SCALE,
                     bonus[i],
                     false
                   )
                 else
                   ScoreCell::UNMATCHED
                 end
        current_prefix_bonus = current_prefix_bonus > PENALTY_GAP_EXTENSION ? current_prefix_bonus - PENALTY_GAP_EXTENSION : 0_u16

        # Update current_row for next_needle_char at position i+1
        if row_idx >= 0 && row_idx < current_row.size
          current_row[row_idx] = if haystack[i + 1] == next_needle_char
                                   next_m_cell(p_score, bonus[i + 1].to_u16, m_cell)
                                 else
                                   ScoreCell::UNMATCHED
                                 end
          if debug
            puts "  haystack[i+1]=#{haystack[i + 1].inspect}, next_needle_char=#{next_needle_char.inspect}, match=#{haystack[i + 1] == next_needle_char}"
            puts "  Set current_row[#{row_idx}] = #{current_row[row_idx].score} (matched? #{current_row[row_idx].matched?})"
          end
        end

        if compute_indices && matrix_idx < matrix_cells.size
          matrix_cells[matrix_idx] = matrix_cells[matrix_idx].set(p_matched, m_cell.matched?)
          if debug
            puts "    matrix[#{matrix_idx}] set p=#{p_matched}, m=#{m_cell.matched?}"
          end
        end
        matrix_idx += 1

        prev_p_score = p_score
        prev_m_score = m_cell.score
      end
    end

    # Score subsequent rows - matches Rust score_row with FIRST_ROW=false
    private def score_row(
      current_row : Array(ScoreCell),
      matrix_cells : Array(MatrixCell),
      haystack : Array(Char),
      bonus : Array(UInt8),
      row_off : UInt16,
      next_row_off : UInt16,
      needle_idx : UInt16,
      needle_char : Char,
      next_needle_char : Char,
      matrix_offset : Int32,
      compute_indices : Bool,
    )
      # DEBUG
      debug = (haystack.size == 5 && needle_char == 'b') || (haystack.size == 14 && needle_char == 'h') || (haystack.size == 3 && needle_char == 'c')
      if debug
        puts "=== DEBUG score_row ==="
        puts "compute_indices: #{compute_indices}"
        puts "needle_idx: #{needle_idx}, needle_char: #{needle_char.inspect}, next_needle_char: #{next_needle_char.inspect}"
        puts "row_off: #{row_off}, next_row_off: #{next_row_off}"
        puts "matrix_offset: #{matrix_offset}"
      end
      adj_next_row_off = next_row_off - 1
      relative_row_off = row_off.to_i - needle_idx.to_i
      next_relative_row_off = adj_next_row_off.to_i - needle_idx.to_i

      prev_p_score = 0_u16
      prev_m_score = 0_u16

      # First loop: columns from row_off to next_row_off-1
      matrix_idx = matrix_offset
      (row_off.to_i...adj_next_row_off.to_i).each do |i|
        relative_i = i - relative_row_off
        if debug
          puts "    first loop i=#{i}, relative_i=#{relative_i}"
        end

        p_score, p_matched = calc_p_score(prev_p_score, prev_m_score)

        # Not first row: get m_cell from current_row
        m_cell = if relative_i >= 0 && relative_i < current_row.size
                   current_row[relative_i]
                 else
                   ScoreCell::UNMATCHED
                 end

        if compute_indices && matrix_idx < matrix_cells.size
          matrix_cells[matrix_idx] = matrix_cells[matrix_idx].set(p_matched, m_cell.matched?)
          if debug
            puts "      matrix[#{matrix_idx}] set p=#{p_matched}, m=#{m_cell.matched?}"
          end
        end
        matrix_idx += 1

        prev_p_score = p_score
        prev_m_score = m_cell.score
      end

      # Second loop: columns from next_row_off-1 to end
      # In Rust: iterates haystack[adj_next_row_off..].windows(2) paired with current_row[next_relative_row_off..]
      # Number of iterations = min(current_row[next_relative_row_off..].size, haystack[adj_next_row_off..].windows(2).size)
      max_iter = haystack.size - 1 - adj_next_row_off.to_i
      max_iter = 0 if max_iter < 0
      slice_len = Math.min(current_row.size - next_relative_row_off, max_iter)
      slice_len.times do |j|
        i = adj_next_row_off.to_i + j
        relative_i = i - relative_row_off
        row_idx = next_relative_row_off + j
        if debug
          puts "    second loop j=#{j}, i=#{i}, relative_i=#{relative_i}, row_idx=#{row_idx}"
        end

        p_score, p_matched = calc_p_score(prev_p_score, prev_m_score)

        # Not first row: get m_cell from current_row at row_idx (matches Rust's *score_cell)
        m_cell = current_row[row_idx]

        # Update current_row for next_needle_char at position i+1
        if row_idx >= 0 && row_idx < current_row.size
          current_row[row_idx] = if haystack[i + 1] == next_needle_char
                                   next_m_cell(p_score, bonus[i + 1].to_u16, m_cell)
                                 else
                                   ScoreCell::UNMATCHED
                                 end
          if debug
            puts "      Set current_row[#{row_idx}] = #{current_row[row_idx].score} (matched? #{current_row[row_idx].matched?})"
          end
        end

        if compute_indices && matrix_idx < matrix_cells.size
          matrix_cells[matrix_idx] = matrix_cells[matrix_idx].set(p_matched, m_cell.matched?)
          if debug
            puts "      matrix[#{matrix_idx}] set p=#{p_matched}, m=#{m_cell.matched?}"
          end
        end
        matrix_idx += 1

        prev_p_score = p_score
        prev_m_score = m_cell.score
      end
    end

    # Calculate p_score (gap penalty score) - matches Rust p_score exactly
    private def calc_p_score(prev_p_score : UInt16, prev_m_score : UInt16) : Tuple(UInt16, Bool)
      score_match = prev_m_score > PENALTY_GAP_START ? prev_m_score - PENALTY_GAP_START : 0_u16
      score_skip = prev_p_score > PENALTY_GAP_EXTENSION ? prev_p_score - PENALTY_GAP_EXTENSION : 0_u16
      if score_match > score_skip
        {score_match, true}
      else
        {score_skip, false}
      end
    end

    # Calculate next m_cell score - matches Rust next_m_cell exactly
    private def next_m_cell(p_score : UInt16, bonus : UInt16, m_cell : ScoreCell) : ScoreCell
      if m_cell == ScoreCell::UNMATCHED
        return ScoreCell.new(
          p_score + bonus + SCORE_MATCH,
          bonus.to_u8,
          false
        )
      end

      consecutive_bonus = Math.max(m_cell.consecutive_bonus.to_u16, BONUS_CONSECUTIVE)
      if bonus >= BONUS_BOUNDARY && bonus > consecutive_bonus
        consecutive_bonus = bonus
      end

      score_match = m_cell.score + Math.max(consecutive_bonus, bonus)
      score_skip = p_score + bonus

      if score_match > score_skip
        ScoreCell.new(
          score_match + SCORE_MATCH,
          consecutive_bonus.to_u8,
          true
        )
      else
        ScoreCell.new(
          score_skip + SCORE_MATCH,
          bonus.to_u8,
          false
        )
      end
    end

    # Reconstruct the optimal path through the matrix - matches Rust reconstruct_optimal_path
    private def reconstruct_optimal_path(
      matrix_cells : Array(MatrixCell),
      current_row : Array(ScoreCell),
      row_offs : Array(UInt16),
      max_score_end : UInt16,
      indices : Array(UInt32),
      start : UInt32,
      matrix_len : Int32,
    )
      indices_start = indices.size
      needle_len = row_offs.size
      needle_len.times { indices << 0_u32 }

      width = current_row.size
      debug = needle_len == 2 && width == 2
      if debug
        puts "=== RECONSTRUCT DEBUG ==="
        puts "max_score_end: #{max_score_end}"
        puts "row_offs: #{row_offs}"
        puts "current_row: #{current_row.each_with_index.map { |cell, idx| "[#{idx}] score=#{cell.score} matched?=#{cell.matched?}" }.join(", ")}"
      end

      last_row_off = row_offs[needle_len - 1]
      indices[indices_start + needle_len - 1] = start + max_score_end.to_u32 + last_row_off.to_u32

      relative_last_row_off = last_row_off.to_i + 1 - needle_len

      col = max_score_end.to_i
      matched = current_row[col + relative_last_row_off].matched?

      # Iterate through rows in reverse
      if needle_len > 1
        # Calculate row positions from the end of matrix_cells (matching Rust's split_at logic)
        # Rust: for each row i, takes width - (row_offs[i] - i) cells from end
        rows = Array(Tuple(Int32, UInt16, Array(MatrixCell))).new(needle_len - 1)
        remaining_cells = matrix_cells[0, matrix_len]

        (0...(needle_len - 1)).to_a.reverse.each do |i|
          row_off = row_offs[i]
          relative_off = row_off.to_i - i
          row_size = width - relative_off

          # Take row_size cells from the end of remaining_cells
          split_idx = remaining_cells.size - row_size
          row_cells = remaining_cells[split_idx..]
          remaining_cells = remaining_cells[0...split_idx]

          rows << {i, row_off, row_cells}
        end

        # rows[0] is last row (needle_len-2), rows[1] is previous, etc.
        row_index = 0
        row_idx, row_off, row = rows[row_index]
        col += last_row_off.to_i - row_off.to_i - 1

        debug = (needle_len == 3 && width == 3) || (needle_len == 2 && width == 2) # Our test case
        if debug
          puts "=== DEBUG reconstruct_optimal_path (Rust algorithm) ==="
          puts "max_score_end: #{max_score_end}, col after adjustment: #{col}"
          puts "row_offs: #{row_offs}, last_row_off: #{last_row_off}"
          puts "width: #{width}, matrix_len: #{matrix_len}"
          puts "rows sizes: #{rows.map { |_, _, r| r.size }}"
        end

        loop do
          if debug
            puts "  Loop: row_idx=#{row_idx}, col=#{col}, matched=#{matched}, row.size=#{row.size}"
          end

          if matched
            indices[indices_start + row_idx] = start + col.to_u32 + row_off.to_u32
            if debug
              puts "  Set index #{row_idx} = #{start} + #{col} + #{row_off} = #{start + col.to_u32 + row_off.to_u32}"
            end
          end

          # Avoid out of bounds access
          if col < 0 || col >= row.size
            break
          end
          next_matched = row[col].get(matched)
          if debug
            puts "  row[#{col}].get(#{matched}) = #{next_matched}"
          end

          if matched
            row_index += 1
            if row_index < rows.size
              next_row_idx, next_row_off, next_row = rows[row_index]
              col += row_off.to_i - next_row_off.to_i
              row_idx, row_off, row = next_row_idx, next_row_off, next_row
            else
              break
            end
          end

          col -= 1
          matched = next_matched
        end
      end
    end

    # Greedy fuzzy match
    def fuzzy_match_greedy(haystack : String, needle : String) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      indices = [] of UInt32
      fuzzy_match_greedy_(haystack, needle, 0, haystack.size, indices)
    end

    def fuzzy_indices_greedy(haystack : String, needle : String, indices : Array(UInt32)) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      fuzzy_match_greedy_(haystack, needle, 0, haystack.size, indices)
    end

    private def fuzzy_match_greedy_(haystack : String, needle : String, start : Int32, end_idx : Int32, indices : Array(UInt32)) : UInt16?
      haystack_chars = haystack.chars
      needle_chars = needle.chars

      # Forward matching
      needle_idx = 0
      haystack_idx = start
      forward_indices = [] of Int32

      while needle_idx < needle_chars.size && haystack_idx < end_idx
        needle_char = Chars.normalize(needle_chars[needle_idx], @config)
        haystack_char = Chars.normalize(haystack_chars[haystack_idx], @config)

        if needle_char == haystack_char
          forward_indices << haystack_idx
          needle_idx += 1
        end
        haystack_idx += 1
      end

      return if needle_idx < needle_chars.size

      # Backward matching to find tighter bounds
      needle_idx = needle_chars.size - 1
      haystack_idx = forward_indices.last
      backward_indices = Array(Int32).new(needle_chars.size, 0)

      while needle_idx >= 0 && haystack_idx >= start
        needle_char = Chars.normalize(needle_chars[needle_idx], @config)
        haystack_char = Chars.normalize(haystack_chars[haystack_idx], @config)

        if needle_char == haystack_char
          backward_indices[needle_idx] = haystack_idx
          needle_idx -= 1
        end
        haystack_idx -= 1
      end

      # Use backward indices for the result
      indices.clear
      backward_indices.each { |idx| indices << idx.to_u32 }

      match_start = backward_indices.first
      match_end = backward_indices.last + 1

      calculate_score(haystack_chars, needle_chars, match_start, match_end, indices)
    end

    # Calculate score for a match - used by both greedy and exact match paths
    private def calculate_score(haystack_chars : Array(Char), needle_chars : Array(Char), start : Int32, end_idx : Int32, indices : Array(UInt32)) : UInt16
      return 0_u16 if needle_chars.empty?

      prev_class = start > 0 ? Chars.char_class(haystack_chars[start - 1], @config) : @config.initial_char_class

      score = 0_u16
      consecutive = 0
      first_bonus = 0_u16
      in_gap = false
      needle_idx = 0

      indices.clear

      (start...end_idx).each do |i|
        char = haystack_chars[i]
        char_class = Chars.char_class(char, @config)
        bonus = bonus_for(prev_class, char_class)
        prev_class = char_class

        normalized_char = Chars.normalize(char, @config)
        if needle_idx < needle_chars.size && normalized_char == Chars.normalize(needle_chars[needle_idx], @config)
          indices << i.to_u32

          if consecutive == 0
            first_bonus = bonus
            if needle_idx == 0
              score += bonus * BONUS_FIRST_CHAR_MULTIPLIER + SCORE_MATCH
            else
              score += bonus + SCORE_MATCH
            end
          else
            if bonus >= BONUS_BOUNDARY && bonus > first_bonus
              first_bonus = bonus
            end
            actual_bonus = Math.max(Math.max(first_bonus, BONUS_CONSECUTIVE), bonus)
            score += actual_bonus + SCORE_MATCH
          end

          consecutive += 1
          in_gap = false
          needle_idx += 1
        else
          if !in_gap && needle_idx > 0
            score = score > PENALTY_GAP_START ? score - PENALTY_GAP_START : 0_u16
            in_gap = true
          elsif in_gap
            score = score > PENALTY_GAP_EXTENSION ? score - PENALTY_GAP_EXTENSION : 0_u16
          end
          consecutive = 0
        end
      end

      # Add prefix bonus if configured
      if @config.prefer_prefix?
        prefix_bonus = if start == 0
                         MAX_PREFIX_BONUS
                       else
                         penalty = PENALTY_GAP_START + (start - 1).clamp(0, UInt16::MAX.to_i).to_u16 * PENALTY_GAP_EXTENSION
                         MAX_PREFIX_BONUS > penalty ? MAX_PREFIX_BONUS - penalty : 0_u16
                       end
        score += prefix_bonus
      end

      score
    end

    # Substring match
    def substring_match(haystack : String, needle : String) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      indices = [] of UInt32
      substring_match_(haystack, needle, indices, false)
    end

    def substring_indices(haystack : String, needle : String, indices : Array(UInt32)) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      substring_match_(haystack, needle, indices, true)
    end

    private def substring_match_(haystack : String, needle : String, indices : Array(UInt32), compute_indices : Bool) : UInt16?
      haystack_chars = haystack.chars
      needle_chars = needle.chars

      best_score = 0_u16
      best_start = 0

      (0..(haystack_chars.size - needle_chars.size)).each do |start|
        match = true
        needle_chars.each_with_index do |needle_char, i|
          haystack_char = haystack_chars[start + i]
          if Chars.normalize(haystack_char, @config) != Chars.normalize(needle_char, @config)
            match = false
            break
          end
        end

        if match
          temp_indices = [] of UInt32
          score = calculate_score(haystack_chars, needle_chars, start, start + needle_chars.size, temp_indices)
          if score > best_score
            best_score = score
            best_start = start
          end
        end
      end

      return if best_score == 0

      if compute_indices
        indices.clear
        needle_chars.size.times do |i|
          indices << (best_start + i).to_u32
        end
      end

      best_score
    end

    # Exact match
    def exact_match(haystack : String, needle : String) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.size != needle.size

      haystack.chars.each_with_index do |hc, i|
        return if Chars.normalize(hc, @config) != Chars.normalize(needle[i], @config)
      end

      indices = [] of UInt32
      calculate_score(haystack.chars, needle.chars, 0, haystack.size, indices)
    end

    def exact_indices(haystack : String, needle : String, indices : Array(UInt32)) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.size != needle.size

      haystack.chars.each_with_index do |hc, i|
        return if Chars.normalize(hc, @config) != Chars.normalize(needle[i], @config)
      end

      calculate_score(haystack.chars, needle.chars, 0, haystack.size, indices)
    end

    # Prefix match
    def prefix_match(haystack : String, needle : String) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      indices = [] of UInt32
      prefix_match_(haystack, needle, indices, false)
    end

    def prefix_indices(haystack : String, needle : String, indices : Array(UInt32)) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      prefix_match_(haystack, needle, indices, true)
    end

    private def prefix_match_(haystack : String, needle : String, indices : Array(UInt32), compute_indices : Bool) : UInt16?
      haystack_chars = haystack.chars
      needle_chars = needle.chars

      # Skip leading whitespace if needle doesn't start with whitespace
      leading_space = 0
      unless needle_chars[0]?.try(&.whitespace?)
        haystack_chars.each_with_index do |char, index|
          if char.whitespace?
            leading_space = index + 1
          else
            break
          end
        end
      end

      return if haystack_chars.size - leading_space < needle_chars.size

      # Check prefix match
      needle_chars.each_with_index do |needle_char, idx|
        hc = haystack_chars[leading_space + idx]
        return if Chars.normalize(hc, @config) != Chars.normalize(needle_char, @config)
      end

      if compute_indices
        indices.clear
        needle_chars.size.times do |i|
          indices << (leading_space + i).to_u32
        end
      end

      calculate_score(haystack_chars, needle_chars, leading_space, leading_space + needle_chars.size, indices)
    end

    # Postfix match
    def postfix_match(haystack : String, needle : String) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      indices = [] of UInt32
      postfix_match_(haystack, needle, indices, false)
    end

    def postfix_indices(haystack : String, needle : String, indices : Array(UInt32)) : UInt16?
      haystack = normalize_input(haystack)
      needle = normalize_input(needle)
      return 0_u16 if needle.empty?
      return if haystack.empty?

      postfix_match_(haystack, needle, indices, true)
    end

    private def postfix_match_(haystack : String, needle : String, indices : Array(UInt32), compute_indices : Bool) : UInt16?
      haystack_chars = haystack.chars
      needle_chars = needle.chars

      # Skip trailing whitespace if needle doesn't end with whitespace
      trailing_spaces = 0
      unless needle_chars[-1]?.try(&.whitespace?)
        haystack_chars.reverse_each.each_with_index do |char, index|
          if char.whitespace?
            trailing_spaces = index + 1
          else
            break
          end
        end
      end

      effective_len = haystack_chars.size - trailing_spaces
      return if effective_len < needle_chars.size

      start_idx = effective_len - needle_chars.size

      # Check postfix match
      needle_chars.each_with_index do |needle_char, idx|
        hc = haystack_chars[start_idx + idx]
        return if Chars.normalize(hc, @config) != Chars.normalize(needle_char, @config)
      end

      if compute_indices
        indices.clear
        needle_chars.size.times do |i|
          indices << (start_idx + i).to_u32
        end
      end

      calculate_score(haystack_chars, needle_chars, start_idx, start_idx + needle_chars.size, indices)
    end

    def config : Config
      @config
    end

    def config=(config : Config)
      @config = config
    end

    private def normalize_input(str : String) : String
      return str unless @config.normalize?
      str.unicode_normalize(:nfc)
    end
  end
end
