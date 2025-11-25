local React = require(script.Parent.Parent.Parent.packages.react)
local AppContext = require(script.Parent.Parent.context.AppContext).AppContext
local constants = require(script.Parent.Parent.constants)
local assets = require(script.Parent.Parent.assets)

local e = React.createElement

export type Props = {
	plugin: Plugin,
	initialSettings: { port: number, autoConnect: boolean },
	callbacks: {
		onConnect: (port: number) -> (),
		onDisconnect: () -> (),
		onSettingsChanged: (settings: { port: number, autoConnect: boolean }) -> (),
	},
	connectionStatusRef: any,
	children: any,
}

local function AppProvider(props: Props)
	local connectionStatus, setConnectionStatus = React.useState({
		connected = false,
		message = "Disconnected",
	})

	local host, setHost = React.useState("localhost")
	local port, setPort = React.useState(tostring(props.initialSettings.port))
	local autoConnect, setAutoConnect = React.useState(props.initialSettings.autoConnect)

	React.useImperativeHandle(props.connectionStatusRef, function()
		return {
			setConnectionStatus = function(connected: boolean, message: string?)
				setConnectionStatus({
					connected = connected,
					message = message or if connected then "Connected" else "Disconnected",
				})
			end,
		}
	end, {})

	local handleHostChange = React.useCallback(function(newHost: string)
		setHost(newHost)
	end, {})

	local handlePortChange = React.useCallback(function(newPort: string)
		local portNum = tonumber(newPort)
		if portNum and portNum > 0 and portNum < 65536 then
			setPort(newPort)
			props.callbacks.onSettingsChanged({
				port = portNum,
				autoConnect = autoConnect,
			})
		else
			-- Revert to previous valid port
			setPort(tostring(props.initialSettings.port))
		end
	end, { autoConnect, props.callbacks, props.initialSettings.port })

	local handleAutoConnectToggle = React.useCallback(function()
		local newAutoConnect = not autoConnect
		setAutoConnect(newAutoConnect)
		props.callbacks.onSettingsChanged({
			port = tonumber(port) or props.initialSettings.port,
			autoConnect = newAutoConnect,
		})
	end, { autoConnect, port, props.callbacks, props.initialSettings.port })

	local handleConnect = React.useCallback(function()
		local portNum = tonumber(port) or props.initialSettings.port
		props.callbacks.onConnect(portNum)
	end, { port, props.callbacks, props.initialSettings.port })

	local handleDisconnect = React.useCallback(function()
		props.callbacks.onDisconnect()
	end, { props.callbacks })

	local contextValue = React.useMemo(function()
		return {
			connectionStatus = connectionStatus,
			settings = {
				host = host,
				port = port,
				autoConnect = autoConnect,
			},
			setHost = handleHostChange,
			setPort = handlePortChange,
			setAutoConnect = handleAutoConnectToggle,
			handleConnect = handleConnect,
			handleDisconnect = handleDisconnect,
			COLORS = constants.COLORS,
			assets = assets,
		}
	end, { connectionStatus, host, port, autoConnect, handleHostChange, handlePortChange, handleAutoConnectToggle, handleConnect, handleDisconnect })

	return e(AppContext.Provider, {
		value = contextValue,
	}, props.children)
end

return AppProvider
