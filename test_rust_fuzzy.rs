use nucleo_matcher::{Config, Matcher};

fn main() {
    let config = Config::DEFAULT;
    let mut matcher = Matcher::new(config);
    
    // Test 1: Exact match "hello" in "hello"
    let haystack1 = "hello";
    let needle1 = "hello";
    
    let score1 = matcher.exact_match(haystack1, needle1);
    println!("Test 1 - Rust exact_match('hello', 'hello') = {:?}", score1);
    
    let mut indices1 = Vec::new();
    let score_with_indices1 = matcher.exact_indices(haystack1, needle1, &mut indices1);
    println!("Test 1 - Rust exact_indices('hello', 'hello') = {:?}", score_with_indices1);
    println!("Test 1 - Indices: {:?}", indices1);
    
    // Test 2: Exact match "hello" in "hello world" 
    let haystack2 = "hello world";
    let needle2 = "hello";
    
    let score2 = matcher.exact_match(haystack2, needle2);
    println!("\nTest 2 - Rust exact_match('hello world', 'hello') = {:?}", score2);
    
    let mut indices2 = Vec::new();
    let score_with_indices2 = matcher.exact_indices(haystack2, needle2, &mut indices2);
    println!("Test 2 - Rust exact_indices('hello world', 'hello') = {:?}", score_with_indices2);
    println!("Test 2 - Indices: {:?}", indices2);
    
    // Test 3: Fuzzy match "hello" in "hello world"
    let score3 = matcher.fuzzy_match(haystack2, needle2);
    println!("\nTest 3 - Rust fuzzy_match('hello world', 'hello') = {:?}", score3);
    
    let mut indices3 = Vec::new();
    let score_with_indices3 = matcher.fuzzy_indices(haystack2, needle2, &mut indices3);
    println!("Test 3 - Rust fuzzy_indices('hello world', 'hello') = {:?}", score_with_indices3);
    println!("Test 3 - Indices: {:?}", indices3);
}