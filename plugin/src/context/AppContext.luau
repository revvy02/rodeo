local React = require(script.Parent.Parent.Parent.packages.react)
local constants = require(script.Parent.Parent.constants)
local assets = require(script.Parent.Parent.assets)

local AppContext = React.createContext(nil)

export type ConnectionStatus = {
	connected: boolean,
	message: string,
}

export type Settings = {
	host: string,
	port: string,
	autoConnect: boolean,
}

export type AppContextValue = {
	-- Connection state
	connectionStatus: ConnectionStatus,
	isExecuting: boolean,

	-- Settings
	settings: Settings,

	-- UI visibility
	settingsPanelEnabled: boolean,

	-- Setters
	setHost: (host: string) -> (),
	setPort: (port: string) -> (),
	setAutoConnect: (autoConnect: boolean) -> (),

	-- Actions
	connect: () -> (),
	disconnect: () -> (),

	-- Assets/constants
	COLORS: typeof(constants.COLORS),
	assets: typeof(assets),
}

local function useAppContext(): AppContextValue
	local context = React.useContext(AppContext)
	if not context then
		error("useAppContext must be used within AppProvider")
	end
	return context
end

return {
	AppContext = AppContext,
	useAppContext = useAppContext,
}
