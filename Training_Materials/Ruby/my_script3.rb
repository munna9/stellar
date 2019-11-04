#!/usr/bin/ruby

$i = 0 
$num = 5

while $i <= $num do 
	puts("Inside the loop i = #$i" ) 
	$i +=1 
end

$threshold = 3
for i in 0..5 
	if( i < $threshold && i==2) then
		 puts "threshold met, break out of loop…..."
		break
	end
	puts "cycle no. #{i}"
end


