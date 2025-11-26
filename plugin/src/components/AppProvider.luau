--[[
	AppProvider - Central state management for the Rodeo plugin

	This provider is the single source of truth for all app state:
	- Connection status and WebSocket management
	- Settings (host, port, autoConnect)
	- Script execution state

	All state flows through React context to child components.
]]

local React = require(script.Parent.Parent.Parent.packages.react)
local HttpService = game:GetService("HttpService")
local AppContext = require(script.Parent.Parent.context.AppContext).AppContext
local constants = require(script.Parent.Parent.constants)
local assets = require(script.Parent.Parent.assets)
local flags = require(script.Parent.Parent.flags)
local useWebSocket = require(script.Parent.Parent.hooks.useWebSocket)
local useExecution = require(script.Parent.Parent.hooks.useExecution)

local e = React.createElement

export type Props = {
	plugin: Plugin,
	initialSettings: {
		host: string?,
		port: number,
		autoConnect: boolean,
	},
	children: any,
}

local function AppProvider(props: Props)
	-- Settings state
	local host, setHost = React.useState(props.initialSettings.host or "localhost")
	local port, setPort = React.useState(tostring(props.initialSettings.port))
	local autoConnect, setAutoConnect = React.useState(props.initialSettings.autoConnect)

	-- Ref to hold execution hook (needed for circular dependency with webSocket)
	local executionRef = React.useRef(nil :: any)

	-- WebSocket hook
	local webSocket = useWebSocket({
		autoRetry = flags.SETTINGS.autoConnect,
		onMessage = function(message: string)
			local success, decoded = pcall(function()
				return HttpService:JSONDecode(message)
			end)

			if not success then
				if _G.RODEO_DEBUG then
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
		if portNum and portNum > 0 and portNum < 65536 then
			setPort(newPort)
		end
	end, {})

	-- Host change handler
	local handleHostChange = React.useCallback(function(newHost: string)
		setHost(newHost)
	end, {})

	-- Auto-connect toggle handler
	local handleAutoConnectToggle = React.useCallback(function(newAutoConnect: boolean)
		setAutoConnect(newAutoConnect)
	end, {})

	-- Connect handler uses current host:port
	local handleConnect = React.useCallback(function()
		local portNum = tonumber(port) or props.initialSettings.port
		webSocket.connect(host, portNum)
	end, { host, port, webSocket.connect, props.initialSettings.port })

	-- Auto-connect on mount if enabled
	React.useEffect(function()
		if props.initialSettings.autoConnect then
			local portNum = tonumber(port) or props.initialSettings.port
			webSocket.connect(host, portNum)
		end
	end, {}) -- Run once on mount

	-- Build context value (memoized)
	local contextValue = React.useMemo(function()
		return {
			-- Connection state
			connectionStatus = webSocket.connectionStatus,
			isExecuting = execution.isExecuting,

			-- Settings
			settings = {
				host = host,
				port = port,
				autoConnect = autoConnect,
			},

			-- UI visibility
			settingsPanelEnabled = flags.SETTINGS_PANEL_ENABLED,

			-- Setters
			setHost = handleHostChange,
			setPort = handlePortChange,
			setAutoConnect = handleAutoConnectToggle,

			-- Actions
			connect = handleConnect,
			disconnect = webSocket.disconnect,

			-- Assets/constants
			COLORS = constants.COLORS,
			assets = assets,
		}
	end, {
		webSocket.connectionStatus,
		execution.isExecuting,
		host,
		port,
		autoConnect,
		handleHostChange,
		handlePortChange,
		handleAutoConnectToggle,
		handleConnect,
		webSocket.disconnect,
	})

	return e(AppContext.Provider, {
		value = contextValue,
	}, props.children)
end

return AppProvider
