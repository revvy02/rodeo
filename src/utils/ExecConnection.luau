export type ExecConnection = {
	ws: any,
	executionId: string,

	new: (ws: any, executionId: string) -> ExecConnection,
	send: (self: ExecConnection, data: string) -> (),
	close: (self: ExecConnection) -> (),
}

local ExecConnection = {}
ExecConnection.__index = ExecConnection

function ExecConnection.new(ws: any, executionId: string): ExecConnection
	local self = setmetatable({}, ExecConnection)
	self.ws = ws
	self.executionId = executionId
	return (self :: any) :: ExecConnection
end

function ExecConnection:send(data: string)
	pcall(function()
		self.ws:send(data)
	end)
end

function ExecConnection:close()
	pcall(function()
		self.ws:close()
	end)
end

return ExecConnection
