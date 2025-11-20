local constants = require(script.constants)
local reloader = require(script.reloader)
local utils = require(script.utils)
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

local SERVER_URL = `ws://localhost:{constants.SERVE_PORT}`

local client = nil
local isConnected = false
local logConnection = nil
local currentExecutionId = nil

local retryDelay = 2
local maxRetryDelay = 10
local isRetrying = false

local LOG_TYPE_TO_LEVEL = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

local function getContextBitset(): number
	local bitset = 0

	if RunService:IsRunning() then
		bitset = bit32.bor(bitset, bit32.lshift(1, constants.CONTEXT_BITS.isRunning))
	end
	if RunService:IsEdit() then
		bitset = bit32.bor(bitset, bit32.lshift(1, constants.CONTEXT_BITS.isEdit))
	end
	if RunService:IsServer() then
		bitset = bit32.bor(bitset, bit32.lshift(1, constants.CONTEXT_BITS.isServer))
	end
	if RunService:IsClient() then
		bitset = bit32.bor(bitset, bit32.lshift(1, constants.CONTEXT_BITS.isClient))
	end
	if RunService:IsStudio() then
		bitset = bit32.bor(bitset, bit32.lshift(1, constants.CONTEXT_BITS.isStudio))
	end

	return bitset
end

local function safeSend(data: string)
	if not client then
		return
	end
	client:Send(data)
end

local function sendMessage(messageType: string, executionId: string, additionalData: { [string]: any }?)
	local message = {
		type = messageType,
		executionId = executionId,
	}

	if additionalData then
		for key, value in additionalData do
			message[key] = value
		end
	end

	safeSend(HttpService:JSONEncode(message))
end

local function cleanupConnection()
	if logConnection then
		logConnection:Disconnect()
		logConnection = nil
	end
	if client then
		client:Close()
		client = nil
	end
	isConnected = false
	currentExecutionId = nil
end

local function setupLogCapture(logFilter: any)
	if not logFilter or not logFilter.enableLogs then
		return
	end

	logConnection = LogService.MessageOut:Connect(function(body, messageType)
		if not isConnected or not currentExecutionId then
			return
		end

		local level = LOG_TYPE_TO_LEVEL[messageType] or "Info"

		-- Filter based on log level
		if level == "Warning" and not logFilter.enableWarn then
			return
		elseif level == "Error" and not logFilter.enableError then
			return
		elseif level == "Info" and not logFilter.enableInfo then
			return
		elseif level == "Print" and not logFilter.enableOutput then
			return
		end

		sendMessage("output", currentExecutionId, {
			level = level,
			body = body,
		})
	end)
end

local function executeScript(script: string, executionId: string, instancePath: string?, logFilter: any, cacheRequires: boolean?)
	currentExecutionId = executionId

	-- Clear previous log connection
	if logConnection then
		logConnection:Disconnect()
		logConnection = nil
	end

	-- Setup log capture with filter
	setupLogCapture(logFilter)

	local moduleScript = utils.createModuleScript(script, instancePath)

	-- Setup uncachable require traversal (clones and renames modules)
	-- Skip if --cache-requires flag is set for better performance
	local cleanup = nil
	if not cacheRequires then
		cleanup = reloader.setupUncachableRequireModuleTraversal(moduleScript)
	end

	-- Execute the module
	local success, result = utils.executeModule(moduleScript)

	-- Wait longer for logs to be captured and sent
	task.wait(0.1)

	-- Cleanup: restore original names and destroy clones
	if cleanup then
		cleanup()
	end

	-- Serialize result
	local serializedResult = nil
	if success and result ~= nil then
		local serializeSuccess, encoded = pcall(function()
			return HttpService:JSONEncode(result)
		end)
		if serializeSuccess then
			serializedResult = encoded
		else
			-- Fallback to tostring for non-serializable types
			serializedResult = tostring(result)
		end
	end

	sendMessage("done", currentExecutionId, {
		result = serializedResult,
	})

	-- Wait for "done" message to flush through WebSocket buffers
	task.wait(0.1)

	currentExecutionId = nil

	-- Cleanup log connection after execution
	if logConnection then
		logConnection:Disconnect()
		logConnection = nil
	end
end

local function connect()
	cleanupConnection()

	local success = pcall(function()
		client = HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
			Url = SERVER_URL,
		})

		client.Opened:Connect(function()
			isConnected = true
			retryDelay = 2

			safeSend(HttpService:JSONEncode({
				clientType = "studio",
				contextBitset = getContextBitset(),
			}))
		end)

		client.Closed:Connect(function()
			isConnected = false

			if not isRetrying then
				isRetrying = true
				task.delay(retryDelay, function()
					isRetrying = false
					retryDelay = math.min(retryDelay * 1.5, maxRetryDelay)
					connect()
				end)
			end
		end)

		client.Error:Connect(function(responseStatusCode, errorMessage)
			-- warn("[rir3] WebSocket error:", responseStatusCode, errorMessage)
			isConnected = false
		end)

		client.MessageReceived:Connect(function(message)
			local decoded = HttpService:JSONDecode(message)

			if decoded.type == "exec" then
				local logFilter = decoded.logFilter or {
					enableWarn = true,
					enableError = true,
					enableInfo = true,
					enableOutput = true,
					enableLogs = true,
				}
				executeScript(decoded.script, decoded.executionId, decoded.instancePath, logFilter, decoded.cacheRequires)
			end
		end)
	end)

	if not success then
		if not isRetrying then
			isRetrying = true
			task.delay(retryDelay, function()
				isRetrying = false
				retryDelay = math.min(retryDelay * 1.5, maxRetryDelay)
				connect()
			end)
		end
	end
end

connect()

-- Create debug toggle button
local toolbar = plugin:CreateToolbar("rir3")
local debugButton = toolbar:CreateButton("Debug", "Toggle debug logging for reloader", "rbxasset://textures/ui/Settings/Help/AButtonDark.png")

local function updateDebugButton()
	if _G.__RIR3_DEBUG__ then
		debugButton:SetActive(true)
	else
		debugButton:SetActive(false)
	end
end

debugButton.Click:Connect(function()
	_G.__RIR3_DEBUG__ = not _G.__RIR3_DEBUG__
	updateDebugButton()
	print(`[rir3] Debug mode: {if _G.__RIR3_DEBUG__ then "ON" else "OFF"}`)
end)

-- Initialize button state
updateDebugButton()

plugin.Unloading:Connect(function()
	cleanupConnection()
end)
