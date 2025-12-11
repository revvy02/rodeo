--[[
	AppContext - Central state management for the Rodeo plugin

	This module provides:
	- Context creation and types
	- AppProvider component with all state logic
	- useAppContext hook for consuming the context

	All state flows through React context to child components.
]]

local React = require("@pkg/react")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local constants = require(script.Parent.Parent.Parent.library.constants)
local flags = require(script.Parent.Parent.Parent.library.flags)
local runtime = require(script.Parent.Parent.Parent.library.runtime)
local utils = require(script.Parent.Parent.Parent.library.utils)

local e = React.createElement
local CONTEXT_BITS = constants.CONTEXT_BITS
local COLORS = constants.COLORS

local AppContext = React.createContext(nil)

-- Types
export type Settings = {
	host: string,
	port: string,
	defaultHost: string,
	defaultPort: string,
	autoConnect: boolean,
	verbose: boolean,
}

export type AppContextValue = {
	-- Connection state
	connected: boolean,
	isExecuting: boolean,
	status: string,

	-- Runtime context
	contextBitset: number,

	-- Settings
	settings: Settings,

	-- UI visibility
	settingsPanelEnabled: boolean,

	-- Setters
	setHost: (host: string) -> (),
	setPort: (port: string) -> (),
	setAutoConnect: (autoConnect: boolean) -> (),
	setVerbose: (verbose: boolean) -> (),

	-- Actions
	connect: () -> (),
	disconnect: () -> (),
}

export type AppProviderProps = {
	plugin: Plugin,
	initialSettings: {
		host: string?,
		port: number,
		autoConnect: boolean,
	},
	children: any,
}

-- Helper function to compute runtime context bitset
local function getContextBitset(): number
	local bitset = 0

	if RunService:IsStudio() then
		bitset = bit32.bor(bitset, bit32.lshift(1, CONTEXT_BITS.isStudio))
	end
	if RunService:IsServer() then
		bitset = bit32.bor(bitset, bit32.lshift(1, CONTEXT_BITS.isServer))
	end
	if RunService:IsClient() then
		bitset = bit32.bor(bitset, bit32.lshift(1, CONTEXT_BITS.isClient))
	end
	if RunService:IsEdit() then
		bitset = bit32.bor(bitset, bit32.lshift(1, CONTEXT_BITS.isEdit))
	end
	if RunService:IsRunning() then
		bitset = bit32.bor(bitset, bit32.lshift(1, CONTEXT_BITS.isRunning))
	end

	return bitset
end

-- Hook for consuming the context
local function useAppContext(): AppContextValue
	local context = React.useContext(AppContext)
	if not context then
		error("useAppContext must be used within AppProvider")
	end
	return context
end

-- local clients = {}
-- game:GetService("RunService").Heartbeat:Connect(function()
-- 	local x = {}
-- 	for _, client in clients do
-- 		table.insert(x, client.ConnectionState)
-- 	end
-- 	print(x)
-- end)

-- Provider component
local function AppProvider(props: AppProviderProps)
	-- Default values (used as placeholders and fallbacks)
	local defaultHost = props.initialSettings.host or flags.SETTINGS.host
	local defaultPort = tostring(props.initialSettings.port or flags.SETTINGS.port)

	-- Current override values (empty means use default)
	local currentHost, setCurrentHost = React.useState("")
	local currentPort, setCurrentPort = React.useState("")
	local autoConnect, setAutoConnect = React.useState(props.initialSettings.autoConnect)
	local verbose, setVerbose = React.useState(flags.VERBOSE)

	-- WebSocket state
	local wsUrl, setWsUrl = React.useState(nil :: string?)
	local connected, setConnected = React.useState(false)

	-- Execution state
	local isExecuting, setIsExecuting = React.useState(false)

	-- Derive status from connected + isExecuting (with rich text)
	local status = React.useMemo(function()
		if isExecuting then
			local hex = COLORS.executing:ToHex()
			return `<font color="#{hex}">Executing</font>`
		elseif connected then
			local hex = COLORS.success:ToHex()
			return `<font color="#{hex}">Connected</font>`
		else
			local hex = COLORS.error:ToHex()
			return `<font color="#{hex}">Disconnected</font>`
		end
	end, { isExecuting, connected }) :: string

	-- Store client in state so message handler effect can access it
	local client, setClient = React.useState(nil :: any)

	-- WebSocket client creation effect
	React.useEffect(function()
		if not wsUrl then
			setConnected(false)
			setClient(nil)
			return
		end

		local success, newClient = xpcall(function()
			return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
				Url = wsUrl,
			})
		end, function(err)
			warn("[rodeo] Error creating client:", err)
			setConnected(false)
		end)

		if not success then
			setWsUrl(nil)
			return
		end

		newClient.Opened:Connect(function()
			setConnected(true)

			-- Read session ID from workspace (if present, for "once" mode)
			local sessionId = workspace:GetAttribute("__RODEO_ONCE_EXECUTION_ID__")

			-- Send identification with optional session ID
			newClient:Send(HttpService:JSONEncode({
				clientType = "studio",
				contextBitset = getContextBitset(),
				sessionId = sessionId,
			}))
		end)

		newClient.Error:Connect(function(code: string, message: string)
			-- warn("[rodeo] Socket error:", code, message)
			setWsUrl(nil)
		end)

		newClient.Closed:Connect(function()
			setConnected(false)
			setWsUrl(nil)
			setClient(nil)
		end)

		setClient(newClient)

		return function()
			newClient:Close()
		end
	end, { wsUrl })

	-- Message handler effect (can depend on verbose without closing socket)
	React.useEffect(function()
		if not client then
			return
		end

		local connection = client.MessageReceived:Connect(function(message: string)
			local success, decoded = pcall(function()
				return HttpService:JSONDecode(message)
			end)

			if not success then
				if verbose then
					warn("[rodeo] Failed to decode message:", message)
				end
				return
			end

			if decoded.type == "exec" then
				setIsExecuting(true)

				local moduleScript = utils.createModuleScript(decoded.script, decoded.instancePath)
				local logFilter = decoded.logFilter or {
					enableWarn = true,
					enableError = true,
					enableInfo = true,
					enableOutput = true,
					enableLogs = true,
				}

				runtime.execute(moduleScript, {
					executionId = decoded.executionId,
					logFilter = logFilter,
					cacheRequires = decoded.cacheRequires,
					verbose = verbose,
				}, {
					onOutput = function(level, body)
						client:Send(HttpService:JSONEncode({
							type = "output",
							executionId = decoded.executionId,
							level = level,
							body = body,
						}))
					end,
					onComplete = function(result)
						client:Send(HttpService:JSONEncode({
							type = "done",
							executionId = decoded.executionId,
							result = result,
						}))
						setIsExecuting(false)
						moduleScript:Destroy()
					end,
				})
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { client, verbose })

	-- Port change handler with validation
	local function handlePortChange(newPort: string)
		local portNum = tonumber(newPort)
		if newPort == "" or (portNum and portNum > 0 and portNum < 65536) then
			setCurrentPort(newPort)
		end
	end

	-- Host change handler
	local function handleHostChange(newHost: string)
		setCurrentHost(newHost)
	end

	-- Auto-connect toggle handler
	local function handleAutoConnectToggle(newAutoConnect: boolean)
		setAutoConnect(newAutoConnect)
	end

	-- Verbose toggle handler
	local function handleVerboseToggle(newVerbose: boolean)
		setVerbose(newVerbose)
	end

	-- Connect handler uses current host:port (falls back to defaults if empty)
	local function handleConnect()
		local connectHost = if currentHost == "" then defaultHost else currentHost
		local portNum = tonumber(currentPort) or tonumber(defaultPort)
		setWsUrl(`ws://{connectHost}:{portNum}`)
	end

	-- Disconnect handler
	local function handleDisconnect()
		setAutoConnect(false)
		setWsUrl(nil)
	end

	-- Auto-reconnect when enabled and disconnected (retries every 1s)
	React.useEffect(function()
		-- Skip if: autoConnect is off, already connected, or already have a wsUrl (connection in progress)
		if not autoConnect or connected or wsUrl then
			return
		end

		-- Delay before attempting reconnect
		local shouldReconnect = true
		task.delay(1, function()
			if shouldReconnect then
				local connectHost = if currentHost == "" then defaultHost else currentHost
				local portNum = tonumber(currentPort) or tonumber(defaultPort)
				setWsUrl(`ws://{connectHost}:{portNum}`)
			end
		end)

		return function()
			shouldReconnect = false
		end
	end, { autoConnect, connected, wsUrl, currentHost, currentPort, defaultHost, defaultPort })

	-- Build context value (memoized)
	local contextValue = React.useMemo(function()
		return {
			-- Connection state
			connected = connected,
			isExecuting = isExecuting,
			status = status,

			-- Runtime context
			contextBitset = getContextBitset(),

			-- Settings
			settings = {
				host = currentHost,
				port = currentPort,
				defaultHost = defaultHost,
				defaultPort = defaultPort,
				autoConnect = autoConnect,
				verbose = verbose,
			},

			-- UI visibility
			settingsPanelEnabled = flags.SETTINGS_PANEL_ENABLED,

			-- Setters
			setHost = handleHostChange,
			setPort = handlePortChange,
			setAutoConnect = handleAutoConnectToggle,
			setVerbose = handleVerboseToggle,

			-- Actions
			connect = handleConnect,
			disconnect = handleDisconnect,
		}
	end, {
		connected,
		isExecuting,
		status,
		currentHost,
		currentPort,
		defaultHost,
		defaultPort,
		autoConnect,
		verbose,
		handleHostChange,
		handlePortChange,
		handleAutoConnectToggle,
		handleVerboseToggle,
		handleConnect,
		handleDisconnect,
	})

	return e(AppContext.Provider, {
		value = contextValue,
	}, props.children)
end

return {
	AppContext = AppContext,
	AppProvider = AppProvider,
	useAppContext = useAppContext,
}
