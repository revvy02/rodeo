-- Simple test script
print("Hello from rodeo!")
print("Testing output forwarding...")

for i = 1, 3 do
	print(`Iteration {i}`)
	task.wait(2)
end

warn("This is a warning")
print("Test complete!")

return 2
