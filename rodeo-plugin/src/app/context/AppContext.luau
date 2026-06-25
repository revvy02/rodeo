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
local MessageHandler = require(script.Parent.MessageHandler)
local rodeoProto = require(script.Parent.Parent.Parent.Parent.proto.rodeo)
local constants = require(script.Parent.Parent.Parent.library.constants)
local studio = require(script.Parent.Parent.Parent.library.studio)

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

export type ProcessEntry = MessageHandler.ProcessEntry

export type AppContextValue = {
	-- Connection state
	connected: boolean,
	isExecuting: boolean,
	status: string,

	-- Runtime context
	contextBitset: number,

	-- Active processes
	activeProcesses: { [string]: ProcessEntry },

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
	local defaultHost = props.initialSettings.host or constants.DEFAULT_HOST
	local defaultPort = tostring(props.initialSettings.port or constants.DEFAULT_PORT)

	-- Current override values (empty means use default)
	local currentHost, setCurrentHost = React.useState("")
	local currentPort, setCurrentPort = React.useState("")
	local autoConnect, setAutoConnect = React.useState(props.initialSettings.autoConnect)
	local verbose, setVerbose = React.useState(constants.VERBOSE)

	-- WebSocket state
	local wsUrl, setWsUrl = React.useState(nil :: string?)
	local connected, setConnected = React.useState(false)

	-- Execution state
	local isExecuting, setIsExecuting = React.useState(false)
	local activeProcesses, setActiveProcesses = React.useState({} :: { [string]: ProcessEntry })

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
			setActiveProcesses({})
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

		local disconnectStudioStateListener

		newClient.Opened:Connect(function()
			setConnected(true)

			-- Send state on connect and on every change
			local function sendState()
				local state = studio.getState()
				if not state then return end
				local msg = rodeoProto.PluginMessage.new({
					msg = { type = "studioState", value = rodeoProto.StudioStateMsg.new({
						vmId = state.vmId,
						mcpStudioId = state.mcpStudioId,
						isServer = state.isServer,
						isClient = state.isClient,
						isRunning = state.isRunning,
						isEdit = state.isEdit,
						mode = state.mode,
						dom = state.dom,
						gameName = state.gameName,
						placeId = state.placeId,
						gameId = state.gameId,
						clientInfo = state.clientInfo and rodeoProto.ClientInfo.new({
							name = state.clientInfo.name,
							userId = state.clientInfo.userId,
						}) or nil,
						-- Rodeo session identity, written by the launch's RunScript
						-- bootstrap as the `rodeoSession` Workspace attribute. Read at
						-- send time (always after connect, so the bootstrap has run);
						-- nil for a manual Studio. Master matches it to its
						-- StudioInstanceInfo and stamps VmConnection.session_guid on the
						-- first message.
						sessionGuid = game:GetService("Workspace"):GetAttribute("rodeoSession"),
					}) },
				})
				newClient:Send(HttpService:JSONEncode(msg:jsonEncode()))
			end
			sendState()
			disconnectStudioStateListener = studio.listen(sendState)
		end)

		newClient.Error:Connect(function(code: string, message: string)
			-- warn("[rodeo] Socket error:", code, message)
			setWsUrl(nil)
		end)

		newClient.Closed:Connect(function()
			setConnected(false)
			setWsUrl(nil)
			setClient(nil)
			setActiveProcesses({})
		end)

		setClient(newClient)

		return function()
			if disconnectStudioStateListener then
				disconnectStudioStateListener()
			end
			newClient:Close()
		end
	end, { wsUrl })

	-- Message handler effect (can depend on verbose without closing socket)
	React.useEffect(function()
		if not client then
			return
		end

		local cleanup = MessageHandler.createHandler({
			client = client,
			verbose = verbose,
			setIsExecuting = setIsExecuting,
			setActiveProcesses = setActiveProcesses,
		})

		return cleanup
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

	-- Auto-connect toggle handler (persists across plugin reloads)
	local function handleAutoConnectToggle(newAutoConnect: boolean)
		setAutoConnect(newAutoConnect)
		props.plugin:SetSetting("autoConnect", newAutoConnect)
	end

	-- Verbose toggle handler
	local function handleVerboseToggle(newVerbose: boolean)
		setVerbose(newVerbose)
	end

	-- Connect handler uses current host:port (falls back to the launch's
	-- rodeoPort attribute, then the default, if no manual override).
	local function handleConnect()
		local connectHost = if currentHost == "" then defaultHost else currentHost
		local bootstrapPort = game:GetService("Workspace"):GetAttribute("rodeoPort")
		local portNum = tonumber(currentPort) or bootstrapPort or tonumber(defaultPort)
		setWsUrl(`ws://{connectHost}:{portNum}`)
	end

	-- Disconnect handler
	local function handleDisconnect()
		setAutoConnect(false)
		props.plugin:SetSetting("autoConnect", false)
		setWsUrl(nil)
	end

	-- Auto-reconnect when enabled and disconnected (retries every 1s)
	React.useEffect(function()
		-- Skip if: autoConnect is off, already connected, or already have a wsUrl (connection in progress)
		if not autoConnect or connected or wsUrl then
			return
		end

		-- Delay before attempting reconnect. The 1s wait also guarantees a
		-- rodeo launch's RunScript bootstrap has already stamped `rodeoPort`
		-- (worst-case it lands ~200ms after the plugin mounts), so a plain read
		-- here picks up the launch's port with no ordering dance.
		local shouldReconnect = true
		task.delay(1, function()
			if shouldReconnect then
				local connectHost = if currentHost == "" then defaultHost else currentHost
				local bootstrapPort = game:GetService("Workspace"):GetAttribute("rodeoPort")
				local portNum = tonumber(currentPort) or bootstrapPort or tonumber(defaultPort)
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

			-- Active processes
			activeProcesses = activeProcesses,

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
			settingsPanelEnabled = true,

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
		activeProcesses,
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
