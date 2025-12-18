# Test saturating subtraction
a = 10_u16
b = 5_u16
c = 15_u16

puts "10 - 5 = #{a - b}"
puts "5 - 10 = #{b - a}"                    # This might underflow
puts "10_u16 - 15_u16 = #{10_u16 - 15_u16}" # This will underflow

# Check if Crystal has saturating_sub
puts "Has saturating_sub? #{10_u16.responds_to?(:saturating_sub)}"
