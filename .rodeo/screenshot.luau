-- Capture a screenshot from Roblox Studio (only works for mac os atm)

local argparse = require("@pkg/argparse")

local fs = require("@rodeo/fs")
local io = require("@rodeo/io")
local process = require("@rodeo/process")
local stream = require("@rodeo/stream")

local CaptureService = game:GetService("CaptureService")
local RunService = game:GetService("RunService")

-- Parse args via argparse
local parser = argparse("screenshot", "Capture a screenshot from Roblox Studio")
parser:option("--cframe"):description("Camera CFrame expression (Luau)")
parser:option("--fov"):description("Field of view"):convert(tonumber)
parser:option("--settle"):description("Settle time in seconds"):convert(tonumber):default("0")
parser:option("--focus"):description("Focus CFrame expression (Luau)")
parser:option("--skew"):description("Per-frame CFrame skew expression (Luau)")
parser:option("-o --output"):description("Output file path")
local opts = parser:parse(process.args)

local cframe: CFrame? = if opts.cframe then (loadstring("return " .. opts.cframe) :: any)() else nil
local fov: number? = opts.fov
local settle: number = opts.settle or 0
local focus: CFrame? = if opts.focus then (loadstring("return " .. opts.focus) :: any)() else nil
local skew: CFrame? = if opts.skew then (loadstring("return " .. opts.skew) :: any)() else nil

-- Set up camera
local camera = workspace.CurrentCamera
local conn: RBXScriptConnection? = nil

if cframe or fov or focus or skew or settle > 0 then
	if cframe then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cframe
	end
	if fov then
		camera.FieldOfView = fov
	end

	conn = RunService.RenderStepped:Connect(function()
		if cframe then
			camera.CFrame = cframe
		end
		if skew then
			camera.CFrame *= skew
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

	task.wait(settle)
end

-- Capture
local contentId: string? = nil
CaptureService:CaptureScreenshot(function(id: string)
	contentId = id
end)
while not contentId do
	task.wait()
end

local timestamp = DateTime.now().UnixTimestampMillis

if conn then
	conn:Disconnect()
end

-- Find the screenshot file by closest mtime
local captureDir = process.homedir() .. "/Library/Roblox/tmp-capture-storage"
local entries = fs.listdir(captureDir)

local bestFile: string? = nil
local bestDelta = math.huge
for _, entry in entries do
	if entry.name:sub(1, 4) == "wob-" then
		local meta = fs.stat(captureDir .. "/" .. entry.name)
		local delta = math.abs(meta.modifiedMillis - timestamp)
		if delta < bestDelta then
			bestDelta = delta
			bestFile = entry.name
		end
	end
end

if not bestFile then
	error("No screenshot file found in " .. captureDir)
end

if bestDelta > 5000 then
	stream.write(io.stderr, string.format("[screenshot] Warning: closest file differs by %.1fs\n", bestDelta / 1000))
end

-- Copy to output
local cwd = process.cwd()
if cwd:sub(-1) == "/" then
	cwd = cwd:sub(1, -2)
end

local outputPath = opts.output or (".rodeo-screenshots/" .. (bestFile :: string) .. ".png")
if outputPath:sub(1, 1) ~= "/" then
	outputPath = cwd .. "/" .. outputPath
end

local parentDir = outputPath:match("^(.+)/[^/]+$")
if parentDir and not fs.exists(parentDir) then
	fs.mkdir(parentDir)
end

fs.copy(captureDir .. "/" .. bestFile, outputPath)
stream.write(io.stdout, outputPath .. "\n")
