print("Hello, world!")

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
