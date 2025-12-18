use nucleo_matcher::{Config, Matcher};

fn main() {
    let config = Config::DEFAULT;
    let mut matcher = Matcher::new(config);
    
    // Test exact match
    let haystack = "hello";
    let needle = "hello";
    
    let score = matcher.exact_match(haystack, needle);
    println!("Rust exact_match('hello', 'hello') = {:?}", score);
    
    // Test with indices
    let mut indices = Vec::new();
    let score_with_indices = matcher.exact_indices(haystack, needle, &mut indices);
    println!("Rust exact_indices('hello', 'hello') = {:?}", score_with_indices);
    println!("Indices: {:?}", indices);
}