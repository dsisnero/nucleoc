require "../src/nucleoc"

# Simulate streaming updates with periodic tick calls
config = Nucleoc::Config.new
nucleo = Nucleoc::Nucleo(Int32).new(config, -> { nil }, 1, 1)

injector = nucleo.injector
items = ["alpha", "beta", "gamma", "delta", "epsilon"]

items.each do |item|
  injector.inject(0, item)
  status = nucleo.tick(0)
  puts "added=#{item} changed=#{status.changed?}"

  snapshot = nucleo.match
  snapshot.items.each do |match|
    puts "  #{match.item}: #{match.score}"
  end
end
