local constants = require(script.constants)
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
	pcall(function()
		client:Send(data)
	end)
end

local function sendMessage(messageType: string, executionId: string, additionalData: {[string]: any}?)
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
		pcall(function()
			client:Close()
		end)
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

local function executeScript(script: string, executionId: string, instancePath: string?, logFilter: any)
	currentExecutionId = executionId

	-- Clear previous log connection
	if logConnection then
		logConnection:Disconnect()
		logConnection = nil
	end

	-- Setup log capture with filter
	setupLogCapture(logFilter)

	local moduleScript = utils.createModuleScript(script, instancePath)
	local success, result = utils.executeModule(moduleScript)

	task.wait(0.1)

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
				executeScript(decoded.script, decoded.executionId, decoded.instancePath, logFilter)
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

plugin.Unloading:Connect(function()
	cleanupConnection()
end)
