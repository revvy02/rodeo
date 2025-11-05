local constants = require(script.constants)
local utils = require(script.utils)
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

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

local function setupLogCapture()
	logConnection = LogService.MessageOut:Connect(function(body, messageType)
		if not isConnected or not currentExecutionId then
			return
		end

		sendMessage("output", currentExecutionId, {
			level = LOG_TYPE_TO_LEVEL[messageType] or "Info",
			body = body,
		})
	end)
end

local function executeScript(script: string, executionId: string, instancePath: string?)
	currentExecutionId = executionId

	local moduleScript = utils.createModuleScript(script, instancePath)
	utils.executeModule(moduleScript)

	task.wait(0.1)

	sendMessage("done", currentExecutionId)
	currentExecutionId = nil
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

		setupLogCapture()

		client.MessageReceived:Connect(function(message)
			local decoded = HttpService:JSONDecode(message)

			if decoded.type == "exec" then
				executeScript(decoded.script, decoded.executionId, decoded.instancePath)
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
