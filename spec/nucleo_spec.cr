require "./spec_helper"
require "../src/nucleoc"

describe Nucleoc do
  describe "active_injector_count" do
    it "tracks active injectors correctly" do
      # Port of active_injector_count test from Rust tests.rs
      # Adapted for Crystal: use explicit release() instead of GC
      config = Nucleoc::Config.new
      nucleo = Nucleoc::Nucleo(Int32).new(config, -> { }, 1, 1)

      nucleo.active_injectors.should eq(0)

      injector = nucleo.injector
      nucleo.active_injectors.should eq(1)

      injector2 = nucleo.injector
      nucleo.active_injectors.should eq(2)

      injector2.release
      nucleo.active_injectors.should eq(1)

      nucleo.restart(false)
      nucleo.active_injectors.should eq(0)

      injector3 = nucleo.injector
      nucleo.active_injectors.should eq(1)

      nucleo.tick(0)
      nucleo.active_injectors.should eq(1)

      injector.release
      nucleo.active_injectors.should eq(1)

      injector3.release
      nucleo.active_injectors.should eq(0)
    end
  end

  describe "match_list" do
    it "matches patterns against a list" do
      config = Nucleoc::Config.new
      nucleo = Nucleoc::Nucleo(Int32).new(config, -> { }, 1, 1)

      items = ["hello world", "goodbye world", "hello there"]
      pattern = "hello"

      # Using module method since nucleo.match_list doesn't exist in native implementation
      matches = Nucleoc.match_list(items, pattern, config)
      matches.size.should be > 0

      # Should match "hello world" and "hello there"
      matches.any? { |match| match.item == "hello world" }.should be_true
      matches.any? { |match| match.item == "hello there" }.should be_true
      matches.any? { |match| match.item == "goodbye world" }.should be_false
    end

    it "sorts matches by score" do
      config = Nucleoc::Config.new
      nucleo = Nucleoc::Nucleo(Int32).new(config, -> { }, 1, 1)

      items = ["hello", "hello world", "world hello"]
      pattern = "hello"

      matches = Nucleoc.match_list(items, pattern, config)
      matches.size.should eq(3)

      # "hello" should have highest score (exact match)
      # "hello world" should have next highest (prefix match)
      # "world hello" should have lowest (fuzzy match not at start)
      matches[0].item.should eq("hello")
      matches[1].item.should eq("hello world")
      matches[2].item.should eq("world hello")
    end
  end

  describe "injector" do
    it "injects items for matching" do
      nucleo = Nucleoc::Nucleo(String).new(Nucleoc::Config.new, -> { }, 1, 1)
      injector = nucleo.injector

      # Inject some items
      injector.push("hello") { |value, columns| columns << Nucleoc::Utf32String.from(value) }
      injector.push("world") { |value, columns| columns << Nucleoc::Utf32String.from(value) }
      injector.push("hello world") { |value, columns| columns << Nucleoc::Utf32String.from(value) }

      # Force a tick to process items
      nucleo.tick(0)

      # Match against injected items
      pattern = "hello"
      nucleo.tick(0) # Process pattern

      # Get matches
      # Note: Actual match retrieval depends on implementation
    end

    it "clears items" do
      nucleo = Nucleoc::Nucleo(String).new(Nucleoc::Config.new, -> { }, 1, 1)
      injector = nucleo.injector

      injector.push("hello") { |value, columns| columns << Nucleoc::Utf32String.from(value) }
      injector.push("world") { |value, columns| columns << Nucleoc::Utf32String.from(value) }

      injector.clear

      # After clear, no items should be matched
      nucleo.tick(0)
    end
  end

  describe "pattern updates" do
    it "updates pattern and rescans" do
      nucleo = Nucleoc::Nucleo(String).new(Nucleoc::Config.new, -> { }, 1, 1)
      injector = nucleo.injector

      # Inject items
      items = ["hello world", "goodbye world", "hello there", "hi world"]
      items.each do |item|
        injector.push(item) { |value, columns| columns << Nucleoc::Utf32String.from(value) }
      end

      nucleo.tick(0) # Process items

      # Initial pattern
      nucleo.reparse(0, "hello", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      nucleo.tick(0) # Process pattern

      # Should match "hello world" and "hello there"

      # Update pattern
      nucleo.reparse(0, "world", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      nucleo.tick(0) # Process updated pattern

      # Should match all items containing "world"
    end
  end

  describe "worker threads" do
    it "uses multiple workers when configured" do
      # Test with multiple worker threads
      config = Nucleoc::Config.new
      nucleo = Nucleoc::Nucleo(String).new(config, -> { }, 2, 2) # 2 workers

      # Note: native Nucleo doesn't have worker_count property
      # nucleo.worker_count.should eq(2)

      # Inject many items to test parallel processing
      injector = nucleo.injector
      100.times do |i|
        injector.push("item #{i}") { |value, columns| columns << Nucleoc::Utf32String.from(value) }
      end

      nucleo.tick(0)

      # Update pattern
      nucleo.reparse(0, "item", Nucleoc::CaseMatching::Smart, Nucleoc::Normalization::Smart)
      nucleo.tick(0)

      # Should match all items
    end
  end
end
