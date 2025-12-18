use nucleo_matcher::{Matcher, Config, Utf32Str};

fn main() {
    // Test with prefer_prefix: true
    let config = Config {
        prefer_prefix: true,
        ..Config::DEFAULT
    };
    let mut matcher = Matcher::new(config);
    
    // Test case from the Crystal test
    let haystack1 = "foo bar baz";
    let haystack2 = "xfoo bar baz";
    let needle = "fbb";
    
    let mut indices1 = Vec::new();
    let mut indices2 = Vec::new();
    
    let score1 = matcher.fuzzy_indices(Utf32Str::new(haystack1), Utf32Str::new(needle), &mut indices1);
    let score2 = matcher.fuzzy_indices(Utf32Str::new(haystack2), Utf32Str::new(needle), &mut indices2);
    
    println!("With prefer_prefix=true:");
    println!("Score1 (starts at beginning): {:?}", score1);
    println!("Indices1: {:?}", indices1);
    println!("Score2 (doesn't start at beginning): {:?}", score2);
    println!("Indices2: {:?}", indices2);
    
    // Test with prefer_prefix: false
    let config = Config {
        prefer_prefix: false,
        ..Config::DEFAULT
    };
    let mut matcher = Matcher::new(config);
    
    indices1.clear();
    indices2.clear();
    
    let score1 = matcher.fuzzy_indices(Utf32Str::new(haystack1), Utf32Str::new(needle), &mut indices1);
    let score2 = matcher.fuzzy_indices(Utf32Str::new(haystack2), Utf32Str::new(needle), &mut indices2);
    
    println!("\nWith prefer_prefix=false:");
    println!("Score1 (starts at beginning): {:?}", score1);
    println!("Indices1: {:?}", indices1);
    println!("Score2 (doesn't start at beginning): {:?}", score2);
    println!("Indices2: {:?}", indices2);
}