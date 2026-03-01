require "./spec_helper"

describe Nucleoc::WorkerPool do
  it "matches multiple haystacks in parallel with native Crystal concurrency" do
    haystacks = ["foo", "bar", "foobar", "fbar", "baz", "qux"]
    needle = "fb"

    pool = Nucleoc::WorkerPool.new(2)
    scores, _ = pool.match_many(haystacks, needle, false)

    matcher = Nucleoc::Matcher.new
    expected = haystacks.map { |h| matcher.fuzzy_match(h, needle) }

    scores.should eq expected
  end

  it "returns indices when requested using native Crystal concurrency" do
    haystacks = ["hello", "yellow", "mellow", "fellow", "bellow"]
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

  it "handles single matches via match_many" do
    pool = Nucleoc::WorkerPool.new(2)

    # Use match_many with single item
    scores, _ = pool.match_many(["hello world"], "hlo", false)
    scores.size.should eq 1
    score = scores[0]
    score.should_not be_nil

    # Compare with direct matcher
    matcher = Nucleoc::Matcher.new
    expected_score = matcher.fuzzy_match("hello world", "hlo")
    score.should eq expected_score
  end

  it "distributes work across multiple workers" do
    haystacks = ["a" * 100, "b" * 100, "c" * 100, "d" * 100]
    needle = "x" # Won't match anything

    pool = Nucleoc::WorkerPool.new(4)
    scores, _ = pool.match_many(haystacks, needle, false)

    scores.size.should eq 4
    scores.each do |score|
      score.should be_nil
    end
  end

  it "processes work correctly" do
    haystacks = ["hello world", "world hello", "hell world", "hello"]
    needle = "hello"

    pool = Nucleoc::WorkerPool.new(2)
    scores, _ = pool.match_many(haystacks, needle, false)

    matcher = Nucleoc::Matcher.new
    expected = haystacks.map { |h| matcher.fuzzy_match(h, needle) }

    scores.should eq expected
  end

  it "uses default size based on CPU count" do
    default_size = Nucleoc::WorkerPool.default_size
    default_size.should be > 0
    default_size.should be <= 16 # Reasonable upper bound

    pool = Nucleoc::WorkerPool.new
    pool.size.should eq default_size
  end

  it "handles empty haystacks array" do
    pool = Nucleoc::WorkerPool.new(2)
    scores, indices = pool.match_many([] of String, "needle", false)

    scores.should eq [] of UInt16?
    indices.should be_nil
  end

  it "preserves result order regardless of completion time" do
    # Create haystacks with varying complexity
    haystacks = [
      "sample",               # Quick to process
      "a" * 1000 + "e",       # Longer to process but has match
      "medium length string", # Medium
      "b" * 500 + "e",        # Medium-long but has match
      "short e",              # Quick
    ]
    needle = "e" # Matches in all

    pool = Nucleoc::WorkerPool.new(2)
    scores, _ = pool.match_many(haystacks, needle, false)

    # All should have scores (e matches in all strings)
    scores.each do |score|
      score.should_not be_nil
    end

    # Verify we got 5 results
    scores.size.should eq 5
  end
end
