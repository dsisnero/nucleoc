use nucleo_rust::matcher::{Config, Matcher};

fn main() {
    let config = Config::DEFAULT;
    let mut matcher = Matcher::new(config);
    
    let haystack = "hello world";
    let needle = "";
    
    // Test fuzzy_match
    let score = matcher.fuzzy_match(haystack, needle);
    println!("Rust fuzzy_match('hello world', '') = {:?}", score);
    
    // Test fuzzy_indices
    let mut indices = Vec::new();
    let score_with_indices = matcher.fuzzy_indices(haystack, needle, &mut indices);
    println!("Rust fuzzy_indices('hello world', '') = {:?}", score_with_indices);
    println!("Indices: {:?}", indices);
}