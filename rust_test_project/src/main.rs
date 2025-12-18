use nucleo_matcher::{Config, Matcher};
use nucleo_matcher::pattern::{Pattern, CaseMatching, Normalization};

fn main() {
    let config = Config::DEFAULT;
    let mut matcher = Matcher::new(config);
    
    // Test 1: Exact match "hello" in "hello"
    let haystack1 = "hello";
    let needle1 = "hello";
    
    // Use pattern API which handles string conversion
    let pattern1 = Pattern::new(needle1, CaseMatching::Ignore, Normalization::Smart, nucleo_matcher::pattern::AtomKind::Exact);
    let haystack_list1 = [haystack1];
    let matches1 = pattern1.match_list(&haystack_list1, &mut matcher);
    
    println!("Test 1 - Pattern::new('hello', exact) on 'hello': {:?}", matches1);
    
    // Test 2: Exact match "hello" in "hello world" 
    let haystack2 = "hello world";
    let needle2 = "hello";
    
    let pattern2 = Pattern::new(needle2, CaseMatching::Ignore, Normalization::Smart, nucleo_matcher::pattern::AtomKind::Exact);
    let haystack_list2 = [haystack2];
    let matches2 = pattern2.match_list(&haystack_list2, &mut matcher);
    
    println!("\nTest 2 - Pattern::new('hello', exact) on 'hello world': {:?}", matches2);
    
    // Test 3: Fuzzy match "hello" in "hello world"
    let pattern3 = Pattern::new(needle2, CaseMatching::Ignore, Normalization::Smart, nucleo_matcher::pattern::AtomKind::Fuzzy);
    let haystack_list3 = [haystack2];
    let matches3 = pattern3.match_list(&haystack_list3, &mut matcher);
    
    println!("\nTest 3 - Pattern::new('hello', fuzzy) on 'hello world': {:?}", matches3);
    
    // Test 4: Also test with parse which should handle exact match with ^ prefix
    let pattern4 = Pattern::parse("^hello", CaseMatching::Ignore, Normalization::Smart);
    let haystack_list4 = [haystack2];
    let matches4 = pattern4.match_list(&haystack_list4, &mut matcher);
    
    println!("\nTest 4 - Pattern::parse('^hello') on 'hello world': {:?}", matches4);
}