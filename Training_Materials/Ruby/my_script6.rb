#!/usr/bin/ruby 
	def test (*arr)
sum = 0
arr.each do |i|
sum += i
end
return sum 
end 
var = test 1,2,3,4,5
var2 = test 1,2,3,4,5,6

puts "total1 : #{var}"
puts "total2 : #{var2}"
