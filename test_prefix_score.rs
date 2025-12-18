use nucleo_matcher::{Config, Matcher};

fn main() {
    let config = Config::DEFAULT;
    let mut matcher = Matcher::new(config);
    
    // Test prefix match
    let prefix_score = matcher.prefix_match("hello world", "hello");
    println!("prefix_match(\"hello world\", \"hello\") = {:?}", prefix_score);
    
    // Test fuzzy match for comparison
    let fuzzy_score = matcher.fuzzy_match("hello world", "hello");
    println!("fuzzy_match(\"hello world\", \"hello\") = {:?}", fuzzy_score);
    
    // Test exact match for comparison
    let exact_score = matcher.exact_match("hello world", "hello world");
    println!("exact_match(\"hello world\", \"hello world\") = {:?}", exact_score);
}