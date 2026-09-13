-- @rodeo/roblox shim. import/export come from the factory-built singleton
-- (transport tier); capture is implemented here in the shim (composition
-- tier) — it only needs the public fs/process API plus engine services and
-- the singleton's internal capture plumbing, so it rides the inlined bundle
-- and works over any backend the singleton fronts.
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
	device: string?,
	viewportSize: Vector2?,
}

type CaptureInfo = {
	width: number,
	height: number,
}

local MAX_VIEWPORT_WIDTH = 7680

-- Capture a Studio screenshot and write it to a stable path. `output` ending
-- in .png is the exact file path; any other value is a directory the
-- auto-named .png lands in; nil defaults to .rodeo/.temp/captures (next to
-- the profiles and logs rodeo already keeps under .rodeo/.temp, which is the
-- directory projects gitignore, rather than a new top-level directory).
--
-- `device` / `viewportSize` drive Studio's device simulator for the shot via
-- plugin-handled RPCs (the service is PluginSecurity; the plugin acts in this
-- DOM at its own identity). The engine's frame is then finalized on the run
-- client: verified against the viewport and resampled to exactly its size,
-- so the image is the same size on every display scale. Camera and simulator
-- state are restored on every exit path. Returns the absolute output path and
-- the image size.
local function capture(output: string?, options: CaptureOptions?): (string, CaptureInfo)
	local resolved: CaptureOptions = options or {}

	local viewportSize = resolved.viewportSize
	if viewportSize ~= nil then
		if typeof(viewportSize) ~= "Vector2" then
			error("roblox.capture: viewportSize must be a Vector2", 2)
		end
		local w, h = math.floor(viewportSize.X + 0.5), math.floor(viewportSize.Y + 0.5)
		if w < 1 or h < 1 then
			error(`roblox.capture: viewportSize must be at least 1x1 (got {w}x{h})`, 2)
		end
		if w > MAX_VIEWPORT_WIDTH then
			error(`roblox.capture: viewportSize width {w} exceeds the device simulator's limit of {MAX_VIEWPORT_WIDTH}`, 2)
		end
		viewportSize = Vector2.new(w, h)
	end
	if resolved.device ~= nil and type(resolved.device) ~= "string" then
		error("roblox.capture: device must be a simulator preset id string", 2)
	end

	-- The engine writes captures into a per-user directory it never reports to
	-- Luau; the location is the platform-specific Roblox app-data root. Paths
	-- are normalized to forward slashes (Rust std accepts them on Windows).
	local platform = process.platform()
	local homedir = (process.homedir():gsub("\\", "/"))
	local captureDirectory
	if platform == "macos" then
		captureDirectory = homedir .. "/Library/Roblox/tmp-capture-storage"
	elseif platform == "windows" then
		captureDirectory = homedir .. "/AppData/Local/Roblox/tmp-capture-storage"
	else
		error(`roblox.capture is not yet supported on platform '{platform}' (the engine capture directory is not mapped there)`, 2)
	end
	if output then
		output = output:gsub("\\", "/")
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
	local simulatorApplied = false

	local function captureAndWrite(): (string, CaptureInfo)
		if resolved.device or viewportSize then
			roblox._simulatorApply(
				resolved.device,
				viewportSize and viewportSize.X,
				viewportSize and viewportSize.Y
			)
			simulatorApplied = true
		end

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

		local before: { [string]: boolean } = {}
		if fs.exists(captureDirectory) then
			for _, entry in fs.listdir(captureDirectory) do
				before[entry.name] = true
			end
		end

		-- The viewport the frame is rendered at; the finalize step verifies the
		-- engine's frame against it and resamples to exactly this size.
		local viewport = camera.ViewportSize
		local width, height = math.floor(viewport.X + 0.5), math.floor(viewport.Y + 0.5)

		local contentId: string? = nil
		CaptureService:CaptureScreenshot(function(id: string)
			contentId = id
		end)
		local callbackDeadline = os.clock() + 10
		while not contentId do
			if os.clock() > callbackDeadline then
				if platform == "windows" then
					error("roblox.capture: CaptureScreenshot callback never fired within 10s. A minimized Studio never renders its viewport on Windows, and background launches are minimized; launch with focus (focus = true / no background) or restore the Studio window and retry. A frame beyond roughly 16384 physical pixels also never completes; reduce viewportSize.")
				end
				error("roblox.capture: CaptureScreenshot callback never fired within 10s. A frame beyond roughly 16384 physical pixels never completes; reduce viewportSize.")
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
		local source = captureDirectory .. "/" .. newFile

		-- The engine may still be writing when the file first appears; wait
		-- until its size holds still so the finalize step never decodes a
		-- partial PNG.
		-- (FsStatResponse.size is an int64, which arrives as a string over
		-- the proto JSON mapping; compare as numbers.)
		local function fileSize(): number
			return tonumber(fs.stat(source).size) or 0
		end
		local size = fileSize()
		local stableDeadline = os.clock() + 5
		while os.clock() < stableDeadline do
			task.wait(0.1)
			local next = fileSize()
			if next == size and size > 0 then
				break
			end
			size = next
		end

		local outputPath
		if output and output:lower():sub(-4) == ".png" then
			outputPath = output
		else
			local directory = output or ".rodeo/.temp/captures"
			if directory:sub(-1) == "/" then
				directory = directory:sub(1, -2)
			end
			outputPath = directory .. "/" .. newFile .. ".png"
		end
		if outputPath:sub(1, 1) ~= "/" and not outputPath:match("^%a:") then
			local cwd = (process.cwd():gsub("\\", "/"))
			if cwd:sub(-1) == "/" then
				cwd = cwd:sub(1, -2)
			end
			outputPath = cwd .. "/" .. outputPath
		end

		local outWidth, outHeight = roblox._captureFinalize(source, outputPath, width, height)
		return outputPath, { width = outWidth, height = outHeight }
	end

	local ok, result, info = pcall(captureAndWrite)
	if simulatorApplied then
		pcall(roblox._simulatorRestore)
	end
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
	return result, info
end

roblox.capture = capture

return roblox
