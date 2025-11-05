local constants = require(script.constants)
local utils = require(script.utils)
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

local SERVER_URL = `ws://localhost:{constants.ONCE_PORT}`

local client = HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
	Url = SERVER_URL,
})

local isConnected = false
local executionId = nil
local logConnection = nil

local function safeSend(data: string)
	pcall(function()
		client:Send(data)
	end)
end

local logTypeToLevel = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

-- Handle connection lifecycle
client.Opened:Connect(function()
	isConnected = true
end)

client.Closed:Connect(function()
	isConnected = false
	if logConnection then
		logConnection:Disconnect()
	end
end)

client.Error:Connect(function(responseStatusCode, errorMessage)
	warn("[rir3 plugin] WebSocket error:", responseStatusCode, errorMessage)
	isConnected = false
end)

client.MessageReceived:Connect(function(message)
	local decoded = HttpService:JSONDecode(message)

	if decoded.type == "exec" then
		executionId = decoded.executionId

		logConnection = LogService.MessageOut:Connect(function(body, messageType)
			if not isConnected or not executionId then
				return
			end

			safeSend(HttpService:JSONEncode({
				type = "output",
				executionId = executionId,
				level = logTypeToLevel[messageType] or "Info",
				body = body,
			}))
		end)

		local moduleScript = utils.createModuleScript(decoded.script, decoded.instancePath)
		utils.executeModule(moduleScript)

		task.wait(0.1)

		safeSend(HttpService:JSONEncode({
			type = "done",
			executionId = executionId,
		}))

		if logConnection then
			logConnection:Disconnect()
		end
		if client and isConnected then
			client:Close()
		end
	end
end)

