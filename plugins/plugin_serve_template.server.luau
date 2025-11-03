local PORT = "{{PORT}}"
local SERVER_URL = string.format("ws://localhost:%s", PORT)

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

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

local function executeScript(script: string, executionId: string)
	currentExecutionId = executionId

	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Source = script .. "\nif true then return true end"

	-- stylua: ignore
	local success, result = (xpcall :: any)(require, debug.traceback, moduleScript)
	moduleScript:Destroy()

	if not success then
		local event = Instance.new("BindableEvent")
		event.Event:Connect(function()
			error(result, 0)
			return
		end)
		event:Fire()
	end

	task.wait(0.5)

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
			print("[rir3] Connected to serve server")

			safeSend(HttpService:JSONEncode({
				clientType = "studio",
			}))
		end)

		client.Closed:Connect(function()
			isConnected = false
			print("[rir3] Disconnected from serve server")

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
			warn("[rir3] WebSocket error:", responseStatusCode, errorMessage)
			isConnected = false
		end)

		setupLogCapture()

		client.MessageReceived:Connect(function(message)
			local decoded = HttpService:JSONDecode(message)

			if decoded.type == "exec" then
				executeScript(decoded.script, decoded.executionId)
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

print("[rir3] Persistent plugin loaded, connecting to serve server...")
