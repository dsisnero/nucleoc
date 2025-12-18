use nucleo_matcher::{Config, Matcher, Utf32Str};

fn main() {
    let config = Config::DEFAULT; // Default is case-insensitive
    let mut matcher = Matcher::new(config);
    
    // Test case-insensitive matching
    let test_cases = vec![
        ("Hello", "hello"),
        ("HELLO", "hello"),
        ("HeLlO", "hello"),
    ];
    
    for (haystack, needle) in test_cases {
        let mut needle_buf = Vec::new();
        let mut haystack_buf = Vec::new();
        
        let needle_str = Utf32Str::new(needle, &mut needle_buf);
        let haystack_str = Utf32Str::new(haystack, &mut haystack_buf);
        
        let score = matcher.exact_match(haystack_str, needle_str);
        
        println!("exact_match(\"{}\", \"{}\") = {:?}", haystack, needle, score);
    }
}