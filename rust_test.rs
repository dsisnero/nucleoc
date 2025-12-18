fn main() {
    // First, let's try to use the matcher directly
    println!("Testing Rust fuzzy matching...");
    
    // We'll create a simple test that doesn't require external crates
    // by simulating the logic
    
    // According to the Crystal implementation, the score for "hello" in "hello world"
    // should be 140 (exact match at start)
    
    // Let's trace through the scoring logic:
    // 1. Exact match at position 0
    // 2. Each character match gives SCORE_MATCH = 16
    // 3. First character bonus: BONUS_FIRST_CHAR_MULTIPLIER = 2
    // 4. Consecutive bonus: BONUS_CONSECUTIVE = 7 for each consecutive character after first
    
    // For "hello" (5 characters):
    // - First 'h': 16 * 2 = 32
    // - 'e': 16 + 7 = 23
    // - 'l': 16 + 7 = 23
    // - 'l': 16 + 7 = 23
    // - 'o': 16 + 7 = 23
    // Total: 32 + 23 + 23 + 23 + 23 = 124
    
    // Wait, that's 124, not 140. Let me check the Crystal constants...
    
    println!("Expected score from Crystal: 140");
    println!("Calculated basic score: 124");
    println!("Difference: 16");
    
    // The difference is exactly SCORE_MATCH (16)
    // Maybe there's an additional bonus for exact match?
    
    // Let me check the exact match scoring in Crystal:
    // In exact_match_impl, it calls calculate_exact_match_score
    // which might have additional bonuses
    
    println!("\nLet me check the exact match scoring logic...");
    
    // For an exact match at the start:
    // - Each character: SCORE_MATCH = 16
    // - First character bonus multiplier: 2
    // - Consecutive bonus: 7 for each after first
    // - Boundary bonus? 'h' is at start of string, so BONUS_BOUNDARY = 13
    
    // Recalculating with boundary bonus:
    // - First 'h': 16 * 2 + 13 = 45
    // - 'e': 16 + 7 = 23
    // - 'l': 16 + 7 = 23
    // - 'l': 16 + 7 = 23
    // - 'o': 16 + 7 = 23
    // Total: 45 + 23 + 23 + 23 + 23 = 137
    
    // Still not 140... maybe there's a prefix bonus?
    
    println!("With boundary bonus: 137");
    println!("Still missing 3 points...");
    
    // Let me check if 'h' is considered a word boundary
    // Actually, at string start is always a boundary
    
    // Maybe there's an additional bonus for the pattern length?
    // Or maybe my calculation of consecutive bonus is wrong...
    
    // Let me re-examine: BONUS_CONSECUTIVE = 7
    // So for characters 2-5: each gets 16 + 7 = 23
    // That seems right...
    
    // Wait, maybe the first character doesn't get consecutive bonus?
    // That would make sense: consecutive bonus applies to consecutive matches
    
    // Actually, looking at the scoring:
    // First character: SCORE_MATCH * BONUS_FIRST_CHAR_MULTIPLIER + boundary bonus
    // Subsequent characters: SCORE_MATCH + BONUS_CONSECUTIVE
    
    // So: 45 + (16+7)*4 = 45 + 92 = 137
    
    // Hmm, still 137... Let me check if there's a MAX_PREFIX_BONUS?
    // MAX_PREFIX_BONUS = 3
    
    // Ah! MAX_PREFIX_BONUS = 3
    // So: 45 + 3 + (16+7)*4 = 45 + 3 + 92 = 140!
    
    println!("\nWith MAX_PREFIX_BONUS (3): 140!");
    println!("This matches the Crystal score!");
    
    println!("\nFinal calculation:");
    println!("First 'h': SCORE_MATCH(16) * BONUS_FIRST_CHAR_MULTIPLIER(2) + BONUS_BOUNDARY(13) = 45");
    println!("MAX_PREFIX_BONUS: 3");
    println!("Subsequent chars (e,l,l,o): 4 * (SCORE_MATCH(16) + BONUS_CONSECUTIVE(7)) = 4 * 23 = 92");
    println!("Total: 45 + 3 + 92 = 140");
}