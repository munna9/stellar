#!/usr/bin/ruby

while 1
   puts "Enter a number>>"
   begin
     num = Kernel.gets.match(/\d+/)[0]
   rescue StandardError=>e
     puts "Erroneous input!"
     puts e
     puts "\tTry again...\n"
   else  
     puts "#{num} + 1 is: #{num.to_i+1}"
   end  
end
