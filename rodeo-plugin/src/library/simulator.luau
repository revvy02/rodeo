--!strict
--[[
	Device-simulator sessions for roblox.captureViewport.

	StudioDeviceSimulatorService is PluginSecurity, so the capture shim (which
	runs at the run's own identity, e.g. a LocalScript in client context) asks
	the plugin over the RPC bridge to apply a device for one capture and to
	restore afterward. MessageHandler intercepts those RPCs and calls into here
	at plugin identity, in the same DOM as the run. One session per execution;
	MessageHandler also restores on completion/kill as a safety net.

	Measured behaviour this relies on (Studio 0.738): a custom device needs
	DeviceForm Desktop for exact dimensions (other forms lose height to a
	status bar), SetResolutionAsync needs an active device and caps width at
	7680 and height at 4320 (Studio 0.739; CreateDeviceAsync caps Width the
	same way) — those engine errors propagate to the caller unchanged, so this
	module does no limit checks of its own. GetResolutionAsync errors when no
	device is active, GetDeviceAsync returns "default" then, and the viewport
	takes a few frames to follow.
]]

local RunService = game:GetService("RunService")

local constants = require(script.Parent.constants)

local simulator = {}

type Prior = {
	device: string?,
	mode: Enum.DeviceSimulatorScalingMode?,
	width: number?,
	height: number?,
	density: number?,
	orientation: Enum.ScreenOrientation?,
}

type Session = {
	prior: Prior?, -- nil = no device was active
	created: string?, -- id of the temporary custom device, if one was made
}

local sessions: { [string]: Session } = {}

-- Per-backend prefix: several rodeo plugins can share a Studio and each
-- sweeps the devices it left behind, so the prefix is unique to this plugin.
-- It also must not start with `rodeo-capture-`, which pre-1.5 plugins sweep
-- wholesale on every connection.
local DEVICE_PREFIX = `rodeoCapture-{constants.PORT}-`

local function service(): any
	local ok, sim = pcall(game.GetService, game, "StudioDeviceSimulatorService")
	if not ok or not sim then
		error("roblox.captureViewport: StudioDeviceSimulatorService is unavailable in this Studio (device/viewportSize need the device simulator)", 0)
	end
	return sim
end

-- Snapshot of the active device, or nil when the simulator is off.
local function readPrior(sim: any): Prior?
	local okRes, res = pcall(function()
		return sim:GetResolutionAsync()
	end)
	if not okRes then
		return nil
	end
	local prior: Prior = { width = res.X, height = res.Y }
	pcall(function()
		prior.device = sim:GetDeviceAsync()
	end)
	pcall(function()
		prior.mode = sim:GetScalingModeAsync()
	end)
	pcall(function()
		prior.orientation = sim:GetOrientationAsync()
	end)
	pcall(function()
		prior.density = sim:GetPixelDensityAsync()
	end)
	return prior
end

local function viewport(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.zero
end

-- Wait (bounded) for Camera.ViewportSize to reflect the new device: an exact
-- match when the size is known, otherwise any change from the starting value
-- (presets apply safe-area insets, so their viewport is not their resolution).
local function waitForViewport(start: Vector2, expected: Vector2?)
	local deadline = os.clock() + 5
	while os.clock() < deadline do
		local vp = viewport()
		if expected then
			if math.abs(vp.X - expected.X) < 1 and math.abs(vp.Y - expected.Y) < 1 then
				return
			end
		elseif vp ~= start then
			return
		end
		task.wait()
	end
end

--[[
	Apply a preset and/or a custom desktop device at width x height for this
	execution. Returns the resulting Camera.ViewportSize. On any failure the
	simulator is put back before the error propagates.
]]
-- Resolve an enum item by name for an option; the engine's own limits apply
-- once the item is set, this only turns a typo into a message naming the option.
local function enumItem(enum: Enum, name: string, option: string): EnumItem
	for _, item in enum:GetEnumItems() do
		if item.Name == name then
			return item
		end
	end
	local names = {}
	for _, item in enum:GetEnumItems() do
		table.insert(names, item.Name)
	end
	error(`roblox.captureViewport: unknown {option} "{name}" (expected one of {table.concat(names, ", ")})`, 0)
end

function simulator.apply(
	executionId: string,
	device: string?,
	width: number?,
	height: number?,
	scalingMode: string?,
	pixelDensity: number?,
	orientation: string?,
	deviceForm: string?
): (number, number)
	if not device and not (width and height) then
		error("roblox.captureViewport: a device or a viewportSize is required to drive the simulator", 0)
	end
	if device and deviceForm then
		error("roblox.captureViewport: deviceForm shapes the custom viewportSize device; a preset brings its own form", 0)
	end

	local sim = service()
	if sessions[executionId] then
		simulator.restore(executionId)
	end

	local start = viewport()
	local session: Session = { prior = readPrior(sim) }
	sessions[executionId] = session

	local expected: Vector2? = nil
	local ok, err = pcall(function()
		-- Resolve names first so a typo fails before anything is touched.
		local form = enumItem(Enum.DeviceForm, deviceForm or "Desktop", "deviceForm")
		local mode = enumItem(Enum.DeviceSimulatorScalingMode, scalingMode or "ActualResolution", "scalingMode")
		local orient = if orientation then enumItem(Enum.ScreenOrientation, orientation, "orientation") else nil
		if device then
			sim:SetDeviceAsync(device)
			if width and height then
				sim:SetResolutionAsync(width, height)
				expected = Vector2.new(width, height)
			end
			-- A phone/tablet preset's viewport is its resolution minus the
			-- safe-area insets, so an exact match never comes; wait for a change.
			local okInfo, info = pcall(function()
				return sim:GetDeviceInfoAsync(device)
			end)
			if okInfo and info.DeviceForm ~= Enum.DeviceForm.Desktop then
				expected = nil
			end
		else
			local name = DEVICE_PREFIX .. executionId
			-- A device of this name can survive a crash mid-capture (custom
			-- devices persist in Studio settings); replace rather than fail.
			pcall(function()
				sim:RemoveDeviceAsync(name)
			end)
			session.created = sim:CreateDeviceAsync({
				Name = name,
				Width = width,
				Height = height,
				PixelDensity = 96,
				DeviceForm = form,
			})
			sim:SetDeviceAsync(session.created)
			expected = Vector2.new(width :: number, height :: number)
			-- Phone/tablet/console forms add their chrome, so the viewport is
			-- not the requested size; wait for any change instead of a match.
			if form ~= Enum.DeviceForm.Desktop then
				expected = nil
			end
		end
		sim:SetScalingModeAsync(mode)
		if pixelDensity then
			sim:SetPixelDensityAsync(pixelDensity)
		end
		if orient then
			-- Portrait swaps the axes and moves the insets: the engine errors
			-- on non-mobile forms, and that message propagates.
			sim:SetOrientationAsync(orient)
			expected = nil
		end
	end)
	if not ok then
		simulator.restore(executionId)
		error(tostring(err), 0)
	end

	waitForViewport(start, expected)
	-- Let the render target settle at the new size before the caller captures.
	for _ = 1, 3 do
		RunService.RenderStepped:Wait()
	end

	-- The engine renders and captures the device's full resolution, rotated in
	-- portrait, even when safe-area insets make Camera.ViewportSize smaller
	-- (iPhone 13: 844x390 rendered, 750x369 viewport). That is the logical
	-- size the frame is matched and resampled against, so return it, not the
	-- viewport; for a desktop device the two are the same.
	local okRes, res = pcall(function()
		return sim:GetResolutionAsync()
	end)
	if not okRes then
		local vp = viewport()
		return math.floor(vp.X + 0.5), math.floor(vp.Y + 0.5)
	end
	local okOrient, orient = pcall(function()
		return sim:GetOrientationAsync()
	end)
	local w, h = math.floor(res.X + 0.5), math.floor(res.Y + 0.5)
	if okOrient and orient == Enum.ScreenOrientation.Portrait then
		w, h = h, w
	end
	return w, h
end

--[[
	Put back whatever was active before `apply` and drop the temporary device.
	Idempotent; safe to call when no session exists.
]]
function simulator.restore(executionId: string)
	local session = sessions[executionId]
	if not session then
		return
	end
	sessions[executionId] = nil

	local sim = service()
	local prior = session.prior
	pcall(function()
		if prior and prior.device and prior.device ~= "default" then
			sim:SetDeviceAsync(prior.device)
			if prior.width and prior.height then
				sim:SetResolutionAsync(prior.width, prior.height)
			end
			if prior.mode then
				sim:SetScalingModeAsync(prior.mode)
			end
			if prior.density then
				sim:SetPixelDensityAsync(prior.density)
			end
			if prior.orientation then
				-- Only mobile forms accept it; the prior device may not.
				pcall(function()
					sim:SetOrientationAsync(prior.orientation)
				end)
			end
		else
			sim:StopSimulationAsync()
		end
	end)
	if session.created then
		pcall(function()
			sim:RemoveDeviceAsync(session.created)
		end)
	end
end

-- Remove custom devices left behind by captures that never restored (the
-- plugin reloaded, Studio crashed). Called once when a plugin session starts.
function simulator.sweep()
	local sim = service()
	local list = sim:GetDeviceListAsync()
	for _, id in ipairs(list) do
		if type(id) == "string" and id:sub(1, #DEVICE_PREFIX) == DEVICE_PREFIX then
			pcall(function()
				sim:RemoveDeviceAsync(id)
			end)
		end
	end
end

return simulator
