print("Hello, world!")
local n = 0
game:GetService("LogService").MessageOut:Connect(function(a, b)
	if string.find(a, "Stack Begin") then
		n += 1
	end
end)
for i = 1, 100 do
	local choice = math.random(1, 4)

	if choice == 1 then
		print("Regular print #" .. i)
	elseif choice == 2 then
		warn("Warning message #" .. i)
	elseif choice == 3 then
		print("Processing iteration", i)
	else
		task.spawn(function()
			error("error" .. i)
		end)
	end
end

task.wait(1)

return n
