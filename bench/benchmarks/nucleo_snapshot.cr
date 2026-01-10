require "./support"

module NucleocBench
  module NucleoSnapshot
    private def self.wait_for_snapshot(matcher)
      status = matcher.tick(0)
      while status.running?
        Fiber.yield
        status = matcher.tick(0)
      end
    end

    def self.run(config : Config)
      NucleocBench.report_header("Nucleo snapshot", config)
      haystacks = NucleocBench.haystacks_with_needle(
        config.dataset_size,
        config.haystack_size,
        config.needle,
        4242
      )
      patterns = ["#{config.needle}", "#{config.needle}x"]
      pattern_idx = 0

      Benchmark.ips(calculation: config.calculation, warmup: config.warmup) do |x|
        x.report("nucleo sequential") do
          matcher = Nucleoc::Nucleo(String).new(Nucleoc::Config.new, -> { nil }, 1, 1)
          matcher.add_all(haystacks)
          matcher.pattern = patterns[pattern_idx % 2]
          pattern_idx += 1
          wait_for_snapshot(matcher)
          matcher.match
        end

        x.report("nucleo parallel") do
          matcher = Nucleoc::Nucleo(String).new(Nucleoc::Config.new, -> { nil }, 4, 1)
          matcher.add_all(haystacks)
          matcher.pattern = patterns[pattern_idx % 2]
          pattern_idx += 1
          wait_for_snapshot(matcher)
          matcher.match
        end
      end
    end
  end
end
