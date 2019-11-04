#!/usr/bin/ruby 

$arr=[1,2,3,4,5]
def test 
	sum = 0
	$arr.each do |i|
		sum += i
	end
	return sum 
end 

var = test
puts "total : #{var}"

