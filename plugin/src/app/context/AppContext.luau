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
local runtime = require(script.Parent.Parent.Parent.runtime)
local utils = require(script.Parent.Parent.Parent.utils)

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
	local connectionStatus, setConnectionStatus = React.useState({
		connected = false,
		message = "Disconnected",
	} :: ConnectionStatus)

	-- Execution state
	local isExecuting, setIsExecuting = React.useState(false)

	-- WebSocket lifecycle effect
	React.useEffect(function()
		if not wsUrl then
			setConnectionStatus({ connected = false, message = "Disconnected" })
			return
		end

		setConnectionStatus({ connected = false, message = "Connecting..." })

		local success, client = xpcall(function()
			return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
				Url = wsUrl,
			})
		end, function(err)
			warn(err)
			setConnectionStatus({ connected = false, message = err })
		end)

		if not success then
			return
		end

		client.Opened:Connect(function()
			setConnectionStatus({ connected = true, message = "Connected" })
			-- Send identification
			client:Send(HttpService:JSONEncode({
				clientType = "studio",
				contextBitset = getContextBitset(),
			}))
		end)

		client.Error:Connect(function(code: string, message: string)
			print("Error:", code, message)
		end)

		client.Closed:Connect(function()
			print("closed")
			setConnectionStatus({ connected = false, message = "Disconnected" })
		end)

		client.MessageReceived:Connect(function(message: string)
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
					end,
				})
			end
		end)

		return function()
			client:Close()
		end
	end, { wsUrl })

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
		setWsUrl(nil)
	end

	-- Auto-connect on mount if enabled
	React.useEffect(function()
		if props.initialSettings.autoConnect then
			local connectHost = if currentHost == "" then defaultHost else currentHost
			local portNum = tonumber(currentPort) or tonumber(defaultPort)
			setWsUrl(`ws://{connectHost}:{portNum}`)
		end
	end, {})

	-- Build context value (memoized)
	local contextValue = React.useMemo(function()
		return {
			-- Connection state
			connectionStatus = connectionStatus,
			isExecuting = isExecuting,

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
		connectionStatus,
		isExecuting,
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
