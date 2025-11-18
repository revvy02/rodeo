local constants = require(script.constants)
local utils = require(script.utils)
local reloader = require(script.reloader)
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
		local logFilter = decoded.logFilter or {
			enableWarn = true,
			enableError = true,
			enableInfo = true,
			enableOutput = true,
			enableLogs = true,
		}

		-- Only connect LogService if logging is enabled
		if logFilter.enableLogs then
			logConnection = LogService.MessageOut:Connect(function(body, messageType)
				if not isConnected or not executionId then
					return
				end

				local level = logTypeToLevel[messageType] or "Info"

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

				safeSend(HttpService:JSONEncode({
					type = "output",
					executionId = executionId,
					level = level,
					body = body,
				}))
			end)
		end

		local moduleScript = utils.createModuleScript(decoded.script, decoded.instancePath)

		-- Setup uncachable require traversal (clones and renames modules)
		local cleanup = reloader.setupUncachableRequireModuleTraversal(moduleScript)

		-- Execute the module
		local success, result = utils.executeModule(moduleScript)

		task.wait(0.1)

		-- Cleanup: restore original names and destroy clones
		cleanup()

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

		safeSend(HttpService:JSONEncode({
			type = "done",
			executionId = executionId,
			result = serializedResult,
		}))

		if logConnection then
			logConnection:Disconnect()
		end

		task.wait(0.1)
		if client and isConnected then
			client:Close()
		end
	end
end)
