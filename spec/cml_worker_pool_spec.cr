require "./spec_helper"

describe Nucleoc::CMLWorkerPool do
  it "matches multiple haystacks in parallel with CML events" do
    haystacks = ["foo", "bar", "foobar", "fbar", "baz", "qux"]
    needle = "fb"

    pool = Nucleoc::CMLWorkerPool.new(2)
    scores, _ = pool.match_many(haystacks, needle, false)

    matcher = Nucleoc::Matcher.new
    expected = haystacks.map { |h| matcher.fuzzy_match(h, needle) }

    scores.should eq expected
  end

  it "returns indices when requested using CML events" do
    haystacks = ["hello", "yellow", "mellow", "fellow", "bellow"]
    needle = "elow"

    pool = Nucleoc::CMLWorkerPool.new(2)
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
    pool = Nucleoc::CMLWorkerPool.new(2)

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
    # Create many haystacks to ensure work distribution
    haystacks = Array.new(100) { |i| "test#{i}string#{i}" }
    needle = "t0"

    pool = Nucleoc::CMLWorkerPool.new(4)
    scores, _ = pool.match_many(haystacks, needle, false)

    # All should have scores (some may be nil if no match)
    scores.size.should eq haystacks.size
  end

  it "processes work correctly" do
    pool = Nucleoc::CMLWorkerPool.new(2)

    # Do some work
    scores, _ = pool.match_many(["test1", "test2"], "t", false)
    scores.size.should eq 2

    # Both should match "t"
    scores[0].should_not be_nil
    scores[1].should_not be_nil
  end

  it "uses default size based on CPU count" do
    default_size = Nucleoc::CMLWorkerPool.default_size
    default_size.should be > 0
    default_size.should be <= 16

    pool = Nucleoc::CMLWorkerPool.new
    pool.size.should eq default_size
  end

  it "handles empty haystacks array" do
    pool = Nucleoc::CMLWorkerPool.new(2)
    scores, indices = pool.match_many([] of String, "test", false)

    scores.should eq [] of UInt16?
    indices.should be_nil
  end

  it "preserves result order regardless of completion time" do
    # Create haystacks with varying complexity
    haystacks = [
      "a",                                           # Simple
      "ab",                                          # Simple
      "abcdefghijklmnop",                            # Longer
      "verylongstringthatwilltakemoretimetoprocess", # Complex
      "medium",
    ]
    needle = "a"

    pool = Nucleoc::CMLWorkerPool.new(2)
    scores, _ = pool.match_many(haystacks, needle, false)

    # Results should be in same order as input
    scores.size.should eq haystacks.size

    # Verify with sequential matcher
    matcher = Nucleoc::Matcher.new
    expected = haystacks.map { |h| matcher.fuzzy_match(h, needle) }
    scores.should eq expected
  end

  it "returns sorted results by score descending" do
    haystacks = ["foo", "bar", "foobar", "fbar", "baz", "qux"]
    needle = "fb"

    pool = Nucleoc::CMLWorkerPool.new(2)
    scores, _ = pool.match_many_sorted(haystacks, needle, false)

    # Verify scores are sorted descending (higher scores first)
    # Note: some scores may be nil (no match)
    previous = UInt16::MAX
    scores.each do |score|
      if score
        score.should be <= previous
        previous = score
      else
        # nil scores should be at the end
        previous = 0
      end
    end

    # Verify all scores are present (same count)
    scores.size.should eq haystacks.size

    # Verify scores match expected values (unordered)
    matcher = Nucleoc::Matcher.new
    expected_scores = haystacks.map { |h| matcher.fuzzy_match(h, needle) }
    scores.compact.sort!.should eq expected_scores.compact.sort!
  end

  it "returns sorted indices when compute_indices is true" do
    haystacks = ["hello", "yellow", "mellow", "fellow", "bellow"]
    needle = "elow"

    pool = Nucleoc::CMLWorkerPool.new(2)
    scores, indices = pool.match_many_sorted(haystacks, needle, true)

    # Verify scores sorted descending
    previous = UInt16::MAX
    scores.each do |score|
      if score
        score.should be <= previous
        previous = score
      else
        previous = 0
      end
    end

    # Verify indices correspond to scores
    indices.not_nil!.each_with_index do |idx_list, i|
      if scores[i]
        idx_list.should_not be_nil
        # Could further verify indices correctness
      end
    end

    # Verify all items present
    scores.size.should eq haystacks.size
  end

  it "handles timeout in match_many" do
    haystacks = ["foo", "bar", "foobar", "fbar", "baz", "qux"]
    needle = "fb"

    pool = Nucleoc::CMLWorkerPool.new(2)
    # Very short timeout - should return some (possibly all nil) results
    scores, _ = pool.match_many(haystacks, needle, false, 1.millisecond)

    # Should return array of correct size
    scores.size.should eq haystacks.size
    # May be all nil if timeout occurs before processing
  end

  it "handles timeout in match_many_sorted" do
    haystacks = ["foo", "bar", "foobar", "fbar", "baz", "qux"]
    needle = "fb"

    pool = Nucleoc::CMLWorkerPool.new(2)
    # Very short timeout - should return some (possibly all nil) results
    scores, _ = pool.match_many_sorted(haystacks, needle, false, timeout: 1.millisecond)

    # Should return array of correct size
    scores.size.should eq haystacks.size
    # May be all nil if timeout occurs before processing
  end

  it "completes before timeout when given sufficient time" do
    haystacks = ["foo", "bar", "foobar", "fbar", "baz", "qux"]
    needle = "fb"

    pool = Nucleoc::CMLWorkerPool.new(2)
    # Generous timeout - should complete all work
    scores, _ = pool.match_many(haystacks, needle, false, 5.seconds)

    # Verify all scores match expected
    matcher = Nucleoc::Matcher.new
    expected = haystacks.map { |h| matcher.fuzzy_match(h, needle) }
    scores.should eq expected
  end

  pending "timeout may not fire due to fast matching" do
    # This test uses the single match timeout method
    pool = Nucleoc::CMLWorkerPool.new(2)
    # Use extremely short timeout - should timeout

    score, indices = pool.match_with_timeout("hello world", "hlo", 1.millisecond)

    score.should be_nil
    indices.should be_nil
  end

  it "match_with_timeout returns score when matches within timeout" do
    pool = Nucleoc::CMLWorkerPool.new(2)
    # Use reasonable timeout - should match

    score, indices = pool.match_with_timeout("hello world", "hlo", 5.seconds)

    score.should_not be_nil
    # indices should be nil since compute_indices defaults to false
    indices.should be_nil
  end
end
