use nucleo_matcher::{Config, Matcher, Utf32Str};

fn main() {
    let config = Config::DEFAULT;
    let mut matcher = Matcher::new(config);
    
    // Test cases from Crystal tests
    let test_cases = vec![
        ("hello world", "hello world"),
        ("hello", "hello"),
        ("foo bar", "foo bar"),
    ];
    
    for (haystack, needle) in test_cases {
        let mut needle_buf = Vec::new();
        let mut haystack_buf = Vec::new();
        
        let needle_str = Utf32Str::new(needle, &mut needle_buf);
        let haystack_str = Utf32Str::new(haystack, &mut haystack_buf);
        
        let score = matcher.exact_match(haystack_str, needle_str);
        
        println!("exact_match(\"{}\", \"{}\") = {:?}", haystack, needle, score);
        
        // Also test with indices
        let mut indices = Vec::new();
        let score_with_indices = matcher.exact_indices(haystack_str, needle_str, &mut indices);
        println!("exact_indices(\"{}\", \"{}\") = {:?}, indices: {:?}", 
                 haystack, needle, score_with_indices, indices);
        println!();
    }
}