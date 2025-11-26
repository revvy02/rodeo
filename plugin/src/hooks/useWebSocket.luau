--[[
	useWebSocket - Custom hook for WebSocket lifecycle management

	Handles connection, disconnection, retry logic, and message sending.
	All state is managed within the hook and exposed via return values.
]]

local React = require(script.Parent.Parent.Parent.packages.react)
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local constants = require(script.Parent.Parent.constants)

export type ConnectionStatus = {
	connected: boolean,
	message: string,
}

export type UseWebSocketOptions = {
	autoRetry: boolean?,
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

local function useWebSocket(options: UseWebSocketOptions): UseWebSocketReturn
	-- Connection status state (triggers re-renders)
	local connectionStatus, setConnectionStatus = React.useState({
		connected = false,
		message = "Disconnected",
	} :: ConnectionStatus)

	-- Refs for mutable values that don't need re-renders
	local clientRef = React.useRef(nil :: any)
	local retryTaskRef = React.useRef(nil :: thread?)
	local lastHostRef = React.useRef("localhost")
	local lastPortRef = React.useRef(constants.SERVE_PORT)
	local isCleaningUpRef = React.useRef(false)

	-- Internal cleanup function
	local cleanupConnection = React.useCallback(function()
		isCleaningUpRef.current = true

		if retryTaskRef.current then
			task.cancel(retryTaskRef.current)
			retryTaskRef.current = nil
		end

		if clientRef.current then
			pcall(function()
				clientRef.current:Close()
			end)
			clientRef.current = nil
		end

		setConnectionStatus({
			connected = false,
			message = "Disconnected",
		})

		isCleaningUpRef.current = false
	end, {})

	-- Send function
	local send = React.useCallback(function(data: string)
		if clientRef.current then
			pcall(function()
				clientRef.current:Send(data)
			end)
		end
	end, {})

	-- Connect function
	local connect = React.useCallback(function(host: string, port: number)
		-- Store for potential retry
		lastHostRef.current = host
		lastPortRef.current = port

		local serverUrl = `ws://{host}:{port}`

		-- Cleanup any existing connection
		cleanupConnection()

		setConnectionStatus({
			connected = false,
			message = "Connecting...",
		})

		local success = pcall(function()
			local client = HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
				Url = serverUrl,
			})
			clientRef.current = client

			client.Opened:Connect(function()
				setConnectionStatus({
					connected = true,
					message = `Connected to {host}:{port}`,
				})

				-- Call onConnect callback with send function
				if options.onConnect then
					options.onConnect(send)
				end

				-- Send initial identification
				send(HttpService:JSONEncode({
					clientType = "studio",
					contextBitset = getContextBitset(),
				}))
			end)

			client.Closed:Connect(function()
				-- Don't process if we're intentionally cleaning up
				if isCleaningUpRef.current then
					return
				end

				clientRef.current = nil

				setConnectionStatus({
					connected = false,
					message = "Disconnected",
				})

				if options.onDisconnect then
					options.onDisconnect()
				end

				-- Auto-retry if enabled
				if options.autoRetry then
					retryTaskRef.current = task.delay(1, function()
						retryTaskRef.current = nil
						connect(lastHostRef.current, lastPortRef.current)
					end)
				end
			end)

			client.Error:Connect(function(responseStatusCode, errorMessage)
				if _G.RODEO_DEBUG then
					warn("[rodeo] WebSocket error:", responseStatusCode, errorMessage)
				end

				setConnectionStatus({
					connected = false,
					message = "Connection error",
				})
			end)

			client.MessageReceived:Connect(function(message: string)
				if options.onMessage then
					options.onMessage(message)
				end
			end)
		end)

		if not success then
			setConnectionStatus({
				connected = false,
				message = "Failed to connect",
			})

			-- Auto-retry on failure if enabled
			if options.autoRetry then
				retryTaskRef.current = task.delay(1, function()
					retryTaskRef.current = nil
					connect(lastHostRef.current, lastPortRef.current)
				end)
			end
		end
	end, { options.autoRetry, options.onConnect, options.onDisconnect, options.onMessage, cleanupConnection, send })

	-- Disconnect function (public API)
	local disconnect = React.useCallback(function()
		cleanupConnection()
	end, { cleanupConnection })

	-- Cleanup on unmount
	React.useEffect(function()
		return function()
			cleanupConnection()
		end
	end, { cleanupConnection })

	return {
		connect = connect,
		disconnect = disconnect,
		send = send,
		connectionStatus = connectionStatus,
	}
end

return useWebSocket
