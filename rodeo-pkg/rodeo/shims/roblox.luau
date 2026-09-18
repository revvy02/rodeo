-- @rodeo/roblox shim. import/export come from the factory-built singleton
-- (transport tier); captureViewport is implemented here in the shim (composition
-- tier) — it only needs the public fs/stream/process API plus engine services
-- and the singleton's internal capture plumbing, so it rides the inlined
-- bundle and works over any backend the singleton fronts.
--
-- NOTE: this file is inlined into user scripts as an IIFE with all comments
-- stripped (see bundle.rs inline_shims). Do not put `--` inside string
-- literals.
local plugins, key = _G.__rodeo_plugins, script and script:GetAttribute("rodeoPlugin")
local ns = plugins and key and plugins[key]
local g = if ns then ns.procs[script:GetAttribute("rodeoExecutionId")] else _G.__rodeo_procs[_G.__rodeo_eid]
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


-- Capture a Studio screenshot and write it to a stable path. `output` ending
-- in .png is the exact file path; any other value is a directory the
-- auto-named .png lands in; nil defaults to .rodeo/.temp/captures (next to
-- the profiles and logs rodeo already keeps under .rodeo/.temp, which is the
-- directory projects gitignore, rather than a new top-level directory).
--
-- In the edit DOM the frame is read back from the exact content id the
-- CaptureScreenshot callback names (EditableImage:ReadPixelsBuffer), so
-- concurrent Studios cannot hand each other's captures out; the RGBA bytes
-- stream to the run client. In a running session (server/client DOM) the
-- engine refuses that readback, so the run client instead takes the frame
-- from the file the engine writes for every capture: it snapshots the
-- engine's capture directory before the capture and accepts exactly one
-- complete PNG that appears afterwards at the viewport's size, erroring on
-- ambiguity rather than guessing. Either way the run client verifies the
-- frame against the viewport, refuses an all-black frame (a solo play-test
-- session captures black, issue #17), resamples to exactly the viewport (the
-- engine renders at the display scale, 2x on Retina) and writes the PNG.
--
-- `device` / `viewportSize` drive Studio's device simulator for the shot via
-- plugin-handled RPCs (the service is PluginSecurity; the plugin acts in this
-- DOM at its own identity). Camera and simulator state are restored on every
-- exit path. Returns the absolute output path and the image size.
-- An error raised inside the plugin reaches the shim as "RPC error [<method>]:
-- <message>"; the message is the engine's own and is what the caller should see.
local function engineMessage(err: unknown): string
	return (tostring(err):gsub("^RPC error %[[%w_]+%]: ", ""))
end

local function capture(output: string?, options: CaptureOptions?): (string, CaptureInfo)
	local resolved: CaptureOptions = options or {}

	local viewportSize = resolved.viewportSize
	if viewportSize ~= nil then
		if typeof(viewportSize) ~= "Vector2" then
			error("roblox.captureViewport: viewportSize must be a Vector2", 2)
		end
		local w, h = math.floor(viewportSize.X + 0.5), math.floor(viewportSize.Y + 0.5)
		if w < 1 or h < 1 then
			error(`roblox.captureViewport: viewportSize must be at least 1x1 (got {w}x{h})`, 2)
		end
		viewportSize = Vector2.new(w, h)
	end
	if resolved.device ~= nil and type(resolved.device) ~= "string" then
		error("roblox.captureViewport: device must be a simulator preset id string", 2)
	end
	if output then
		output = output:gsub("\\", "/")
	end

	local camera = workspace.CurrentCamera
	if not camera then
		error("roblox.captureViewport: no viewport camera in this context (use plugin context, or client context in a running session)", 2)
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
			-- Limits (width 7680, height 4320, unknown preset) are the engine's:
			-- its message propagates as this call's error, minus the rpc
			-- layer's prefix. The plugin has already put the simulator back.
			simulatorApplied = true
			local okSim, simErr = pcall(
				roblox._simulatorApply,
				resolved.device,
				viewportSize and viewportSize.X,
				viewportSize and viewportSize.Y
			)
			if not okSim then
				error(`roblox.captureViewport: {engineMessage(simErr)}`, 0)
			end
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

		-- In a running session the frame comes from the engine's capture
		-- directory (see the header); the run client snapshots it now so the
		-- file that appears after the callback is unmistakably this capture's.
		-- IsRunning (not IsEdit, which needs the Plugin capability the client
		-- identity lacks) is false in the edit DOM even while a session runs.
		local inSession = RunService:IsRunning()
		local captureToken: string? = if inSession then roblox._captureBegin() else nil

		-- The wait for the callback has no deadline: a large frame or a slow
		-- GPU can take well over 10s, and a timer here only invented failures.
		-- The engine raises its own errors for what cannot work (limits, the
		-- server DOM), and those propagate. The cases that never complete, a
		-- frame beyond roughly 16384 physical pixels and a minimized Studio on
		-- Windows, are documented; killing the run abandons one.
		local contentId: string? = nil
		local okShot, shotErr = pcall(function()
			CaptureService:CaptureScreenshot(function(id: string)
				contentId = id
			end)
		end)
		if not okShot then
			error(`roblox.captureViewport: {engineMessage(shotErr)}`, 0)
		end
		while not contentId do
			task.wait()
		end

		if inSession then
			local outWidth, outHeight = roblox._captureCollect(captureToken :: string, outputPath, width, height)
			return outputPath, { width = outWidth, height = outHeight }
		end

		-- Edit DOM: read the exact frame the callback named.
		local okImage, image = pcall(function()
			return AssetService:CreateEditableImageAsync(Content.fromUri(contentId :: string))
		end)
		if not okImage or not image then
			error(`roblox.captureViewport: could not load the captured frame ({contentId}): {tostring(image)}`)
		end
		local frameSize = image.Size
		local sourceWidth, sourceHeight = frameSize.X, frameSize.Y
		local pixels = image:ReadPixelsBuffer(Vector2.zero, frameSize)
		image:Destroy()
		local expectedBytes = sourceWidth * sourceHeight * 4
		if buffer.len(pixels) ~= expectedBytes then
			error(`roblox.captureViewport: frame buffer is {buffer.len(pixels)} bytes, expected {expectedBytes} for {sourceWidth}x{sourceHeight}`)
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

roblox.captureViewport = capture

-- Deprecated name; warns once per run, then forwards.
local warnedCapture = false
roblox.capture = function(output: string?, options: CaptureOptions?): (string, CaptureInfo)
	if not warnedCapture then
		warnedCapture = true
		warn("[rodeo] roblox.capture is deprecated and will be removed in 2.0; use roblox.captureViewport")
	end
	return capture(output, options)
end

return roblox
