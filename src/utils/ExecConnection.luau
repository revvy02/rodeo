export type LogFilter = {
	enableWarn: boolean,
	enableError: boolean,
	enableInfo: boolean,
	enableOutput: boolean,
	enableLogs: boolean,
}

export type ExecConnection = {
	ws: any,
	executionId: string,
	script: string,
	instancePath: string?,
	filterBits: number,
	filterMask: number,
	logFilter: LogFilter,
	cacheRequires: boolean?,
	queuedAt: number,

	new: (
		ws: any,
		executionId: string,
		script: string,
		instancePath: string?,
		filterBits: number,
		filterMask: number,
		logFilter: LogFilter,
		cacheRequires: boolean?
	) -> ExecConnection,
	send: (self: ExecConnection, data: string) -> (),
	close: (self: ExecConnection) -> (),
}

local ExecConnection = {}
ExecConnection.__index = ExecConnection

function ExecConnection.new(
	ws: any,
	executionId: string,
	script: string,
	instancePath: string?,
	filterBits: number,
	filterMask: number,
	logFilter: LogFilter,
	cacheRequires: boolean?
): ExecConnection
	local self = setmetatable({}, ExecConnection)
	self.ws = ws
	self.executionId = executionId
	self.script = script
	self.instancePath = instancePath
	self.filterBits = filterBits
	self.filterMask = filterMask
	self.logFilter = logFilter
	self.cacheRequires = cacheRequires
	self.queuedAt = os.time()
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
