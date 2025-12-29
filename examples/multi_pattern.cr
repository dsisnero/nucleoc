require "../src/nucleoc"

# MultiPattern scoring across multiple columns
matcher = Nucleoc::Matcher.new
pattern = Nucleoc::MultiPattern.new(2)
pattern.reparse(0, "foo")
pattern.reparse(1, "bar")

haystacks = ["foo.txt", "bar.log"]
score = pattern.score(haystacks, matcher)
puts "score=#{score.inspect}"

parallel_score = pattern.score_parallel(haystacks, Nucleoc::Config::DEFAULT)
puts "parallel_score=#{parallel_score.inspect}"
