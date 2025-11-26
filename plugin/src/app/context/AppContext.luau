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
local constants = require(script.Parent.Parent.Parent.constants)
local flags = require(script.Parent.Parent.Parent.flags)
local useWebSocket = require(script.Parent.hooks.useWebSocket)
local useExecution = require(script.Parent.hooks.useExecution)

local e = React.createElement
local CONTEXT_BITS = constants.CONTEXT_BITS

local AppContext = React.createContext(nil)

-- Types
export type ConnectionStatus = {
	connected: boolean,
	message: string,
}

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
	connectionStatus: ConnectionStatus,
	isExecuting: boolean,

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

	-- Ref to hold execution hook (needed for circular dependency with webSocket)
	local executionRef = React.useRef(nil :: any)

	-- WebSocket hook
	local webSocket = useWebSocket({
		autoRetry = flags.SETTINGS.autoConnect,
		verbose = verbose,
		onConnect = function(send)
			-- Send initial identification
			send(HttpService:JSONEncode({
				clientType = "studio",
				contextBitset = getContextBitset(),
			}))
		end,
		onMessage = function(message: string)
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
				if executionRef.current then
					executionRef.current.executeScript({
						script = decoded.script,
						executionId = decoded.executionId,
						instancePath = decoded.instancePath,
						logFilter = decoded.logFilter or {
							enableWarn = true,
							enableError = true,
							enableInfo = true,
							enableOutput = true,
							enableLogs = true,
						},
						cacheRequires = decoded.cacheRequires,
					})
				end
			end
		end,
	})

	-- Execution hook
	local execution = useExecution({
		verbose = verbose,
		sendMessage = function(messageType: string, executionId: string, additionalData: { [string]: any }?)
			local message = {
				type = messageType,
				executionId = executionId,
			}

			if additionalData then
				for key, value in additionalData do
					message[key] = value
				end
			end

			webSocket.send(HttpService:JSONEncode(message))
		end,
		onExecutionComplete = function()
			-- In autoConnect mode (once), close connection after execution
			if flags.SETTINGS.autoConnect then
				task.delay(0.1, function()
					webSocket.disconnect()
				end)
			end
		end,
	})

	-- Store execution ref for webSocket callback
	executionRef.current = execution

	-- Port change handler with validation
	local handlePortChange = React.useCallback(function(newPort: string)
		local portNum = tonumber(newPort)
		if newPort == "" or (portNum and portNum > 0 and portNum < 65536) then
			setCurrentPort(newPort)
		end
	end, {})

	-- Host change handler
	local handleHostChange = React.useCallback(function(newHost: string)
		setCurrentHost(newHost)
	end, {})

	-- Auto-connect toggle handler
	local handleAutoConnectToggle = React.useCallback(function(newAutoConnect: boolean)
		setAutoConnect(newAutoConnect)
	end, {})

	-- Verbose toggle handler
	local handleVerboseToggle = React.useCallback(function(newVerbose: boolean)
		setVerbose(newVerbose)
	end, {})

	-- Connect handler uses current host:port (falls back to defaults if empty)
	local handleConnect = React.useCallback(function()
		local connectHost = if currentHost == "" then defaultHost else currentHost
		local portNum = tonumber(currentPort) or tonumber(defaultPort)
		webSocket.connect(connectHost, portNum)
	end, { currentHost, currentPort, defaultHost, defaultPort, webSocket.connect })

	-- Auto-connect on mount if enabled
	React.useEffect(function()
		if props.initialSettings.autoConnect then
			local connectHost = if currentHost == "" then defaultHost else currentHost
			local portNum = tonumber(currentPort) or tonumber(defaultPort)
			webSocket.connect(connectHost, portNum)
		end
	end, {}) -- Run once on mount

	-- Build context value (memoized)
	local contextValue = React.useMemo(function()
		return {
			-- Connection state
			connectionStatus = webSocket.connectionStatus,
			isExecuting = execution.isExecuting,

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
			disconnect = webSocket.disconnect,
		}
	end, {
		webSocket.connectionStatus,
		execution.isExecuting,
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
		webSocket.disconnect,
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
