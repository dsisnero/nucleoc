require "./spec_helper"

describe Nucleoc::WorkerPool do
  it "matches multiple haystacks in parallel order" do
    haystacks = ["foo", "bar", "foobar", "fbar"]
    needle = "fb"

    pool = Nucleoc::WorkerPool.new(2)
    scores, _ = pool.match_many(haystacks, needle, false)

    matcher = Nucleoc::Matcher.new
    expected = haystacks.map { |h| matcher.fuzzy_match(h, needle) }

    scores.should eq expected
  end

  it "returns indices when requested" do
    haystacks = ["hello", "yellow", "mellow"]
    needle = "elow"

    pool = Nucleoc::WorkerPool.new(2)
    scores, indices = pool.match_many(haystacks, needle, true)

    matcher = Nucleoc::Matcher.new
    expected = haystacks.map do |h|
      idxs = [] of UInt32
      score = matcher.fuzzy_indices(h, needle, idxs)
      {score, idxs}
    end

    scores.should eq expected.map(&.[0])
    indices.not_nil!.map(&.not_nil!).should eq expected.map(&.[1])
  end
end
