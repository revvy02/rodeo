local React = require(script.Parent.Parent.Parent.packages.react)

local AppContext = React.createContext(nil)

export type AppContextValue = {
	connectionStatus: { connected: boolean, message: string },
	settings: { port: string, autoConnect: boolean },
	setPort: (string) -> (),
	setAutoConnect: (boolean) -> (),
	handleConnect: () -> (),
	handleDisconnect: () -> (),
	COLORS: any,
	assets: any,
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
