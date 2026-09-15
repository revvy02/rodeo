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
	7680, GetResolutionAsync errors when no device is active, GetDeviceAsync
	returns "default" then, and the viewport takes a few frames to follow.
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
local MAX_WIDTH = 7680

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
function simulator.apply(executionId: string, device: string?, width: number?, height: number?): (number, number)
	if not device and not (width and height) then
		error("roblox.captureViewport: a device or a viewportSize is required to drive the simulator", 0)
	end
	if width and width > MAX_WIDTH then
		error(`roblox.captureViewport: viewportSize width {width} exceeds the device simulator's limit of {MAX_WIDTH}`, 0)
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
		if device then
			sim:SetDeviceAsync(device)
			if width and height then
				sim:SetResolutionAsync(width, height)
				expected = Vector2.new(width, height)
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
				DeviceForm = Enum.DeviceForm.Desktop,
			})
			sim:SetDeviceAsync(session.created)
			expected = Vector2.new(width :: number, height :: number)
		end
		sim:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
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

	local vp = viewport()
	return math.floor(vp.X + 0.5), math.floor(vp.Y + 0.5)
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
