use nucleo::Nucleo;

fn main() {
    let mut nucleo = Nucleo::new(1, 1, None);
    let matches = nucleo.match_list(&["hello world"], "hello");
    
    if let Some(matches) = matches {
        for (idx, score) in matches {
            println!("Match at index {} with score: {}", idx, score);
        }
    } else {
        println!("No matches found");
    }
}