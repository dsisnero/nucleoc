use nucleo_matcher::{Matcher, Config};
use nucleo_matcher::pattern::{Pattern, Normalization, CaseMatching};

fn main() {
    let paths = ["foo/bar", "bar/foo", "foobar"];
    let mut matcher = Matcher::new(Config::DEFAULT.match_paths());
    
    println!("Testing pattern 'foo bar' against 'foobar':");
    let matches = Pattern::parse("foo bar", CaseMatching::Ignore, Normalization::Smart).match_list(&paths, &mut matcher);
    println!("Matches: {:?}", matches);
    
    // Let's also test just "foo" against "foobar"
    println!("\nTesting pattern 'foo' against 'foobar':");
    let matches = Pattern::parse("foo", CaseMatching::Ignore, Normalization::Smart).match_list(&paths, &mut matcher);
    println!("Matches: {:?}", matches);
    
    // And "bar" against "foobar"
    println!("\nTesting pattern 'bar' against 'foobar':");
    let matches = Pattern::parse("bar", CaseMatching::Ignore, Normalization::Smart).match_list(&paths, &mut matcher);
    println!("Matches: {:?}", matches);
}