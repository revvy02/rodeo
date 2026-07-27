-- @rodeo/roblox shim. import/export come from the factory-built singleton
-- (transport tier); capture is implemented here in the shim (composition
-- tier) — it only needs the public fs/process API plus engine services, so it
-- rides the inlined bundle and works over any backend the singleton fronts.
--
-- NOTE: this file is inlined into user scripts as an IIFE with all comments
-- stripped (see bundle.rs inline_shims). Do not put `--` inside string
-- literals.
local g = _G.__rodeo_procs[_G.__rodeo_eid]
local fs = g.fs
local process = g.process
local roblox = g.roblox

type CaptureOptions = {
	cframe: CFrame?,
	fov: number?,
	focus: CFrame?,
	settle: number?,
}

-- Capture a Studio screenshot and copy it to a stable path. `output` ending
-- in .png is the exact file path; any other value is a directory the
-- auto-named .png lands in; nil defaults to the .rodeo-screenshots directory.
-- Owns temporary scripted-camera state for one capture and always restores
-- the camera state it found. Returns the absolute output path.
local function capture(output: string?, options: CaptureOptions?): string
	local resolved: CaptureOptions = options or {}

	local platform = process.platform()
	if platform ~= "macos" then
		error(`roblox.capture is not yet supported on platform '{platform}' (macOS only: the engine capture directory is not mapped elsewhere)`, 2)
	end

	local camera = workspace.CurrentCamera
	if not camera then
		error("roblox.capture: no viewport camera in this context (use plugin context, or client context in a running session)", 2)
	end

	local CaptureService = game:GetService("CaptureService")
	local RunService = game:GetService("RunService")

	local savedType = camera.CameraType
	local savedCFrame = camera.CFrame
	local savedFocus = camera.Focus
	local savedFov = camera.FieldOfView
	local connection: RBXScriptConnection? = nil

	local function captureAndWrite(): string
		local cframe = resolved.cframe
		local fov = resolved.fov
		local focus = resolved.focus

		if cframe then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cframe
		end
		if fov then
			camera.FieldOfView = fov
		end

		if cframe or fov or focus then
			connection = RunService.RenderStepped:Connect(function()
				if cframe then
					camera.CFrame = cframe
				end
				if focus then
					camera.Focus = focus
				elseif cframe then
					camera.Focus = CFrame.new(cframe.Position + cframe.LookVector * 100)
				end
				if fov then
					camera.FieldOfView = fov
				end
			end)
		end

		task.wait(resolved.settle or 0)

		local captureDirectory = process.homedir() .. "/Library/Roblox/tmp-capture-storage"

		local before: { [string]: boolean } = {}
		if fs.exists(captureDirectory) then
			for _, entry in fs.listdir(captureDirectory) do
				before[entry.name] = true
			end
		end

		local contentId: string? = nil
		CaptureService:CaptureScreenshot(function(id: string)
			contentId = id
		end)
		local callbackDeadline = os.clock() + 10
		while not contentId do
			if os.clock() > callbackDeadline then
				error("roblox.capture: CaptureScreenshot callback never fired within 10s")
			end
			task.wait()
		end

		local newFile: string? = nil
		local fileDeadline = os.clock() + 10
		while os.clock() < fileDeadline do
			if fs.exists(captureDirectory) then
				for _, entry in fs.listdir(captureDirectory) do
					if not before[entry.name] and entry.name:sub(1, 4) == "wob-" then
						newFile = entry.name
						break
					end
				end
			end
			if newFile then
				break
			end
			task.wait(0.1)
		end
		if not newFile then
			error("roblox.capture: no new screenshot file appeared in " .. captureDirectory)
		end

		local outputPath
		if output and output:lower():sub(-4) == ".png" then
			outputPath = output
		else
			local directory = output or ".rodeo-screenshots"
			if directory:sub(-1) == "/" then
				directory = directory:sub(1, -2)
			end
			outputPath = directory .. "/" .. newFile .. ".png"
		end
		if outputPath:sub(1, 1) ~= "/" then
			local cwd = process.cwd()
			if cwd:sub(-1) == "/" then
				cwd = cwd:sub(1, -2)
			end
			outputPath = cwd .. "/" .. outputPath
		end

		local parentDirectory = outputPath:match("^(.+)/[^/]+$")
		if parentDirectory and not fs.exists(parentDirectory) then
			fs.mkdir(parentDirectory)
		end

		local source = captureDirectory .. "/" .. newFile
		fs.copy(source, outputPath)
		pcall(fs.remove, source)
		return outputPath
	end

	local ok, result = pcall(captureAndWrite)
	if connection then
		connection:Disconnect()
	end
	camera.CameraType = savedType
	camera.CFrame = savedCFrame
	camera.Focus = savedFocus
	camera.FieldOfView = savedFov

	if not ok then
		error(result, 0)
	end
	return result
end

roblox.capture = capture

return roblox
