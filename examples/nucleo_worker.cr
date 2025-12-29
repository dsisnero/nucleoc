require "../src/nucleoc"

# High-level matcher usage with Nucleo
config = Nucleoc::Config.new
nucleo = Nucleoc::Nucleo(Int32).new(config, -> { nil }, 1, 1)

injector = nucleo.injector
injector.inject(0, "hello world")
injector.inject(1, "goodbye world")
injector.inject(2, "hello there")

nucleo.pattern = "hello"
status = nucleo.tick(0)
puts "changed=#{status.changed?} running=#{status.running?}"

while status.running?
  status = nucleo.tick(0)
end

snapshot = nucleo.match
snapshot.items.each do |match|
  puts "#{match.item}: #{match.score}"
end
