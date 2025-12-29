require "../src/nucleoc"

# Batch matching with the CML worker pool
haystacks = [
  "hello",
  "world",
  "hello there",
  "goodbye",
]
needle = "hel"

pool = Nucleoc::CMLWorkerPool.new(2)
scores, _ = pool.match_many(haystacks, needle, false)

scores.each_with_index do |score, idx|
  puts "#{haystacks[idx]}: #{score.inspect}"
end
