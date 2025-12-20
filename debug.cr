require "./src/nucleoc/boxcar"
vec = Nucleoc::BoxcarVector(Int32).new
puts "Created"
vec.push(42)
puts "Pushed"
