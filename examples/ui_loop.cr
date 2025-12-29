require "../src/nucleoc"

# Minimal UI-style loop example for Nucleo
config = Nucleoc::Config.new
nucleo = Nucleoc::Nucleo(Int32).new(config, -> { nil }, 1, 1)

injector = nucleo.injector
injector.extend(["alpha", "beta", "gamma", "delta"])

# Simulated UI loop
queries = ["a", "ga", "del"]
queries.each do |query|
  nucleo.pattern = query
  status = nucleo.tick(0)

  puts "query=#{query} changed=#{status.changed?}"
  next unless status.changed?

  snapshot = nucleo.match
  snapshot.items.each do |match|
    puts "  #{match.item}: #{match.score}"
  end
end
