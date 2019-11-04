#!/usr/bin/ruby -w

# define a class
class Box
 
 @@count=0
 
# constructor method
 def initialize(w,h)
 @width, @height = w, h
 # increase count every time initialize is called
 @@count += 1
 end


 # accessor methods
 def getWidth
	 @width
 end
 
 def getHeight
	 @height
 end


 # setter methods
 def setWidth=(value)
	 @width = value
 end
 def setHeight=(value)
 	@height = value
 end

 # instance method
 def getArea
	 @width * @height
 end

 # class method
 def self.printCount()
 	puts "Box count is : #@@count"
 end
end


# create an object
box = Box.new(10, 20)

x = box.getWidth() #10
y = box.getHeight() #20

a = box.getArea()

puts "Width of the box is : #{x}"
puts "Height of the box is : #{y}"
puts "Area of the box is : #{a}"

# use setter methods
box.setWidth = 30
box.setHeight = 50

# use accessor methods
x = box.getWidth() #30
y = box.getHeight() #50

a = box.getArea()

puts "Width of the box is : #{x}"
puts "Height of the box is : #{y}"
puts "Area of the box is : #{a}"

Box.printCount()
box2 = Box.new(30, 100)
Box.printCount()

