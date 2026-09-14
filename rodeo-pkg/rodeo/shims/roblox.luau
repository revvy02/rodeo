-- @rodeo/roblox shim. import/export come from the factory-built singleton
-- (transport tier); capture is implemented here in the shim (composition
-- tier) — it only needs the public fs/stream/process API plus engine services
-- and the singleton's internal capture plumbing, so it rides the inlined
-- bundle and works over any backend the singleton fronts.
--
-- NOTE: this file is inlined into user scripts as an IIFE with all comments
-- stripped (see bundle.rs inline_shims). Do not put `--` inside string
-- literals.
local g = _G.__rodeo_procs[_G.__rodeo_eid]
local fs = g.fs
local stream = g.stream
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
-- The frame is read back from the exact content id the CaptureScreenshot
-- callback names (EditableImage:ReadPixelsBuffer), never found by diffing the
-- engine's per-user temp directory, so concurrent Studios cannot hand each
-- other's captures out. The RGBA bytes stream to the run client, which
-- verifies them against the viewport, resamples to exactly its size (the
-- engine renders at the display scale, 2x on Retina) and writes the PNG.
--
-- `device` / `viewportSize` drive Studio's device simulator for the shot via
-- plugin-handled RPCs (the service is PluginSecurity; the plugin acts in this
-- DOM at its own identity). Camera and simulator state are restored on every
-- exit path. Returns the absolute output path and the image size.
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
	if output then
		output = output:gsub("\\", "/")
	end

	local camera = workspace.CurrentCamera
	if not camera then
		error("roblox.capture: no viewport camera in this context (use plugin context, or client context in a running session)", 2)
	end

	local AssetService = game:GetService("AssetService")
	local CaptureService = game:GetService("CaptureService")
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")
	local platform = process.platform()

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

		-- The viewport the frame is rendered at; the finalize step verifies the
		-- frame against it and resamples to exactly this size.
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

		-- Read the exact frame the callback named.
		local okImage, image = pcall(function()
			return AssetService:CreateEditableImageAsync(Content.fromUri(contentId :: string))
		end)
		if not okImage or not image then
			error(`roblox.capture: could not load the captured frame ({contentId}): {tostring(image)}`)
		end
		local frameSize = image.Size
		local sourceWidth, sourceHeight = frameSize.X, frameSize.Y
		local pixels = image:ReadPixelsBuffer(Vector2.zero, frameSize)
		image:Destroy()
		local expectedBytes = sourceWidth * sourceHeight * 4
		if buffer.len(pixels) ~= expectedBytes then
			error(`roblox.capture: frame buffer is {buffer.len(pixels)} bytes, expected {expectedBytes} for {sourceWidth}x{sourceHeight}`)
		end

		local outputPath
		if output and output:lower():sub(-4) == ".png" then
			outputPath = output
		else
			local directory = output or ".rodeo/.temp/captures"
			if directory:sub(-1) == "/" then
				directory = directory:sub(1, -2)
			end
			outputPath = directory .. "/capture-" .. HttpService:GenerateGUID(false):lower() .. ".png"
		end
		if outputPath:sub(1, 1) ~= "/" and not outputPath:match("^%a:") then
			local cwd = (process.cwd():gsub("\\", "/"))
			if cwd:sub(-1) == "/" then
				cwd = cwd:sub(1, -2)
			end
			outputPath = cwd .. "/" .. outputPath
		end

		-- Stream the frame to the run client and finalize in place of
		-- stream.close (the finalize RPC consumes the handle).
		local h = fs.open(outputPath, "w")
		stream.writeBytes(h, pixels)
		local outWidth, outHeight = roblox._captureFinalize(h.__handle, sourceWidth, sourceHeight, width, height)
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
