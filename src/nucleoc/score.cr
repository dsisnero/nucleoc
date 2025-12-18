# Scoring constants and utilities for fuzzy matching
require "./config"

module Nucleoc
  # Score cell used in the matching matrix
  struct ScoreCell
    property score : UInt16
    property consecutive_bonus : UInt8
    property matched : Bool

    def initialize(@score : UInt16, @consecutive_bonus : UInt8, @matched : Bool)
    end

    def ==(other : ScoreCell) : Bool
      @score == other.score && @consecutive_bonus == other.consecutive_bonus && @matched == other.matched
    end
  end

  # Unmatched score cell constant
  UNMATCHED = ScoreCell.new(0_u16, 0_u8, true)

  # Calculate the score for a match
  def self.next_m_cell(p_score : UInt16, bonus : UInt16, m_cell : ScoreCell) : ScoreCell
    if m_cell == UNMATCHED
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

  # Calculate the p_score (gap penalty)
  def self.p_score(prev_p_score : UInt16, prev_m_score : UInt16) : Tuple(UInt16, Bool)
    # Apply gap penalty
    gap_score = prev_p_score + PENALTY_GAP_START.to_u16
    match_score = prev_m_score + PENALTY_GAP_EXTENSION.to_u16

    if gap_score > match_score
      {gap_score, false}
    else
      {match_score, true}
    end
  end
end
