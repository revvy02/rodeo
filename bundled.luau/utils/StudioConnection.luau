local serde = require("@lune/serde")

export type StudioConnection = {
	ws: any,
	connected: boolean,
	bitset: number,
	connectedAt: number,

	new: (ws: any, bitset: number) -> StudioConnection,
	send: (self: StudioConnection, data: string) -> (),
	close: (self: StudioConnection) -> (),
	isConnected: (self: StudioConnection) -> boolean,
}

local StudioConnection = {}
StudioConnection.__index = StudioConnection

function StudioConnection.new(ws: any, bitset: number): StudioConnection
	local self = setmetatable({}, StudioConnection)
	self.ws = ws
	self.connected = true
	self.bitset = bitset
	self.connectedAt = os.time()
	return (self :: any) :: StudioConnection
end

function StudioConnection:send(data: string)
	self.ws:send(data)
end

function StudioConnection:close()
	self.connected = false
	self.ws:close()
end

function StudioConnection:isConnected(): boolean
	return self.connected
end

return StudioConnection
