use nucleo_matcher::{Config, Matcher};

fn main() {
    let config = Config::DEFAULT;
    let mut matcher = Matcher::new(config);
    
    // Test 1: Exact match "hello" in "hello"
    let score1 = matcher.exact_match("hello", "hello");
    println!("Rust exact_match('hello', 'hello') = {:?}", score1);
    
    // Test 2: Exact match "hello" in "hello world"
    let score2 = matcher.exact_match("hello world", "hello");
    println!("Rust exact_match('hello world', 'hello') = {:?}", score2);
    
    // Test 3: Fuzzy match "hello" in "hello world"
    let score3 = matcher.fuzzy_match("hello world", "hello");
    println!("Rust fuzzy_match('hello world', 'hello') = {:?}", score3);
}