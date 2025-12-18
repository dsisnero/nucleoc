use nucleo_matcher::{Config, Matcher};

fn main() {
    println!("Testing Rust implementation:");
    println!("============================\n");
    
    let config = Config::DEFAULT;
    let mut matcher = Matcher::new(config);
    
    // Test exact match
    println!("Exact match tests:");
    let exact1 = matcher.exact_match("hello", "hello");
    let exact2 = matcher.exact_match("hello world", "hello world");
    println!("exact_match(\"hello\", \"hello\") = {:?}", exact1);
    println!("exact_match(\"hello world\", \"hello world\") = {:?}", exact2);
    
    // Test fuzzy match
    println!("\nFuzzy match tests:");
    let fuzzy1 = matcher.fuzzy_match("hello", "hello");
    let fuzzy2 = matcher.fuzzy_match("hello world", "hello");
    let fuzzy3 = matcher.fuzzy_match("hello there world", "hello");
    
    println!("fuzzy_match(\"hello\", \"hello\") = {:?}", fuzzy1);
    println!("fuzzy_match(\"hello world\", \"hello\") = {:?}", fuzzy2);
    println!("fuzzy_match(\"hello there world\", \"hello\") = {:?}", fuzzy3);
    
    // Test with different patterns
    println!("\nTesting with different patterns:");
    println!("--------------------------------");
    
    // Test with pattern "hell"
    let fuzzy_hell1 = matcher.fuzzy_match("hello", "hell");
    let fuzzy_hell2 = matcher.fuzzy_match("hello world", "hell");
    let fuzzy_hell3 = matcher.fuzzy_match("hell", "hell");
    let fuzzy_hell4 = matcher.fuzzy_match("shell", "hell");
    
    println!("\nPattern: 'hell'");
    println!("fuzzy_match(\"hello\", \"hell\") = {:?}", fuzzy_hell1);
    println!("fuzzy_match(\"hello world\", \"hell\") = {:?}", fuzzy_hell2);
    println!("fuzzy_match(\"hell\", \"hell\") = {:?}", fuzzy_hell3);
    println!("fuzzy_match(\"shell\", \"hell\") = {:?}", fuzzy_hell4);
    
    // Test with pattern "world"
    let fuzzy_world1 = matcher.fuzzy_match("hello world", "world");
    let fuzzy_world2 = matcher.fuzzy_match("world", "world");
    let fuzzy_world3 = matcher.fuzzy_match("world hello", "world");
    let fuzzy_world4 = matcher.fuzzy_match("wor ld", "world");
    
    println!("\nPattern: 'world'");
    println!("fuzzy_match(\"hello world\", \"world\") = {:?}", fuzzy_world1);
    println!("fuzzy_match(\"world\", \"world\") = {:?}", fuzzy_world2);
    println!("fuzzy_match(\"world hello\", \"world\") = {:?}", fuzzy_world3);
    println!("fuzzy_match(\"wor ld\", \"world\") = {:?}", fuzzy_world4);
    
    // Test with pattern "he"
    let fuzzy_he1 = matcher.fuzzy_match("hello", "he");
    let fuzzy_he2 = matcher.fuzzy_match("hello world", "he");
    let fuzzy_he3 = matcher.fuzzy_match("the", "he");
    let fuzzy_he4 = matcher.fuzzy_match("he", "he");
    
    println!("\nPattern: 'he'");
    println!("fuzzy_match(\"hello\", \"he\") = {:?}", fuzzy_he1);
    println!("fuzzy_match(\"hello world\", \"he\") = {:?}", fuzzy_he2);
    println!("fuzzy_match(\"the\", \"he\") = {:?}", fuzzy_he3);
    println!("fuzzy_match(\"he\", \"he\") = {:?}", fuzzy_he4);
}