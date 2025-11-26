--[[
	useWebSocket - Custom hook for WebSocket lifecycle management

	Uses state + useEffect pattern for clearer data flow:
	- targetUrl state drives connection lifecycle
	- retryCounter state triggers reconnection attempts
	- client state holds the WebSocket instance
]]

local React = require("@pkg/react")
local HttpService = game:GetService("HttpService")

export type ConnectionStatus = {
	connected: boolean,
	message: string,
}

export type UseWebSocketOptions = {
	autoRetry: boolean?,
	verbose: boolean?,
	onMessage: ((message: string) -> ())?,
	onConnect: ((send: (data: string) -> ()) -> ())?,
	onDisconnect: (() -> ())?,
}

export type UseWebSocketReturn = {
	connect: (host: string, port: number) -> (),
	disconnect: () -> (),
	send: (data: string) -> (),
	connectionStatus: ConnectionStatus,
}

local function useWebSocket(options: UseWebSocketOptions): UseWebSocketReturn
	-- Target URL state - setting this triggers connection
	local targetUrl, setTargetUrl = React.useState(nil :: string?)

	-- Retry counter - incrementing triggers reconnection
	local retryCounter, setRetryCounter = React.useState(0)

	-- WebSocket client state
	local client, setClient = React.useState(nil :: any)

	-- Connection status state
	local connectionStatus, setConnectionStatus = React.useState({
		connected = false,
		message = "Disconnected",
	} :: ConnectionStatus)

	-- Send function
	local send = React.useCallback(function(data: string)
		if client then
			pcall(function()
				client:Send(data)
			end)
		end
	end, { client })

	-- Connect function - sets target URL
	local connect = React.useCallback(function(host: string, port: number)
		setTargetUrl(`ws://{host}:{port}`)
	end, {})

	-- Disconnect function - clears target URL and resets retry counter
	local disconnect = React.useCallback(function()
		setTargetUrl(nil)
		setRetryCounter(0)
	end, {})

	-- Effect: Create WebSocket client when targetUrl or retryCounter changes
	React.useEffect(function()
		if not targetUrl then
			setClient(nil)
			setConnectionStatus({
				connected = false,
				message = "Disconnected",
			})
			return
		end

		setConnectionStatus({
			connected = false,
			message = "Connecting...",
		})

		local success, newClient = pcall(function()
			return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
				Url = targetUrl,
			})
		end)

		if success and newClient then
			setClient(newClient)
		else
			setClient(nil)
			setConnectionStatus({
				connected = false,
				message = "Failed to connect",
			})

			-- Auto-retry on failure
			if options.autoRetry then
				task.delay(1, function()
					setRetryCounter(function(n)
						return n + 1
					end)
				end)
			end
		end

		-- Cleanup: close client when effect re-runs or unmounts
		return function()
			if newClient then
				pcall(function()
					newClient:Close()
				end)
			end
		end
	end, { targetUrl, retryCounter })

	-- Effect: Set up event listeners when client changes
	React.useEffect(function()
		if not client then
			return
		end

		local connections: { RBXScriptConnection } = {}

		table.insert(connections, client.Opened:Connect(function()
			setConnectionStatus({
				connected = true,
				message = "Connected",
			})

			if options.onConnect then
				options.onConnect(send)
			end
		end))

		table.insert(connections, client.Closed:Connect(function()
			setClient(nil)
			setConnectionStatus({
				connected = false,
				message = "Disconnected",
			})

			if options.onDisconnect then
				options.onDisconnect()
			end

			-- Auto-retry on unexpected close
			if options.autoRetry and targetUrl then
				task.delay(1, function()
					setRetryCounter(function(n)
						return n + 1
					end)
				end)
			end
		end))

		table.insert(connections, client.Error:Connect(function(statusCode, errorMessage)
			if options.verbose then
				warn("[rodeo] WebSocket error:", statusCode, errorMessage)
			end

			setConnectionStatus({
				connected = false,
				message = "Connection error",
			})
		end))

		table.insert(connections, client.MessageReceived:Connect(function(message: string)
			if options.onMessage then
				options.onMessage(message)
			end
		end))

		-- Cleanup: disconnect all event listeners
		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, { client, targetUrl, options.autoRetry, options.onConnect, options.onDisconnect, options.onMessage, options.verbose, send })

	return {
		connect = connect,
		disconnect = disconnect,
		send = send,
		connectionStatus = connectionStatus,
	}
end

return useWebSocket
