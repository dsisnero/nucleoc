require "./spec_helper"
require "../src/nucleoc/multi_pattern"

module Nucleoc
  describe MultiPattern do
    it "creates with specified number of columns" do
      mp = MultiPattern.new(3)
      mp.columns.should eq 3
      mp.empty?.should be_true
    end

    it "reparses a column pattern" do
      mp = MultiPattern.new(2)
      mp.reparse(0, "hello")
      mp.column_pattern(0).atoms.size.should eq 1
      mp.column_pattern(0).atoms[0].needle.should eq "hello"
      mp.column_status(0).should eq PatternStatus::Rescore
      mp.status.should eq PatternStatus::Rescore
    end

    it "tracks status updates on append" do
      mp = MultiPattern.new(1)
      mp.reparse(0, "hello", append: false)
      mp.column_status(0).should eq PatternStatus::Rescore
      mp.reset_status
      mp.column_status(0).should eq PatternStatus::Unchanged
      mp.reparse(0, "hello world", append: true)
      mp.column_status(0).should eq PatternStatus::Update
    end

    it "scores single column matches" do
      mp = MultiPattern.new(1)
      mp.reparse(0, "hello")
      matcher = Matcher.new
      haystacks = ["hello world"]
      score = mp.score(haystacks, matcher)
      score.should_not be_nil
      score.not_nil!.should be > 0
    end

    it "returns nil when column doesn't match" do
      mp = MultiPattern.new(1)
      mp.reparse(0, "goodbye")
      matcher = Matcher.new
      haystacks = ["hello world"]
      mp.score(haystacks, matcher).should be_nil
    end

    it "scores multi-column matches sequentially" do
      mp = MultiPattern.new(2)
      mp.reparse(0, "hello")
      mp.reparse(1, "world")
      matcher = Matcher.new
      haystacks = ["hello there", "world"]
      score = mp.score(haystacks, matcher)
      score.should_not be_nil
      score.not_nil!.should be > 0
    end

    it "parallel scores with CML.spawn" do
      mp = MultiPattern.new(2)
      mp.reparse(0, "hello")
      mp.reparse(1, "world")
      config = Config.new
      haystacks = ["hello there", "world"]
      score = mp.score_parallel(haystacks, config)
      score.should_not be_nil
      score.not_nil!.should be > 0
    end

    it "handles timeout in parallel scoring" do
      mp = MultiPattern.new(2)
      mp.reparse(0, "hello")
      mp.reparse(1, "world")
      config = Config.new
      haystacks = ["hello there", "world"]
      # Very short timeout, should still complete
      score = mp.score_with_timeout(haystacks, config, 1.millisecond)
      score.should_not be_nil
      score.not_nil!.should be > 0
    end
  end
end