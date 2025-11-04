local serde = require("@lune/serde")

export type StudioConnection = {
	ws: any,
	connected: boolean,
	activeExecutionId: string?,

	new: (ws: any) -> StudioConnection,
	send: (self: StudioConnection, data: string) -> (),
	close: (self: StudioConnection) -> (),
	isConnected: (self: StudioConnection) -> boolean,
}

local StudioConnection = {}
StudioConnection.__index = StudioConnection

function StudioConnection.new(ws: any): StudioConnection
	local self = setmetatable({}, StudioConnection)
	self.ws = ws
	self.connected = true
	self.activeExecutionId = nil
	return (self :: any) :: StudioConnection
end

function StudioConnection:send(data: string)
	pcall(function()
		self.ws:send(data)
	end)
end

function StudioConnection:close()
	self.connected = false
	pcall(function()
		self.ws:close()
	end)
end

function StudioConnection:isConnected(): boolean
	return self.connected
end

return StudioConnection
