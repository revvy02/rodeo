local serde = require("@lune/serde")

local config = require("./config")
local log = require("./log")
local output = require("./output")

local colors = config.CLI_LOG_COLORS

export type LogFilter = {
	enableWarn: boolean,
	enableError: boolean,
	enableInfo: boolean,
	enableOutput: boolean,
	enableLogs: boolean,
}

export type ExecRequest = {
	ws: any,
	executionId: string,
	script: string,
	instancePath: string?,
	filterBits: number,
	filterMask: number,
	logFilter: LogFilter,
	cacheRequires: boolean?,
	queuedAt: number,
}

export type VmPipeline = {
	bitset: number,
	studioId: string,
	studioWs: any,
	studioConnected: boolean,
	connectedAt: number,
	execQueue: { ExecRequest },
	activeExecution: ExecRequest?,

	new: (bitset: number, studioId: string, studioWs: any) -> VmPipeline,
	enqueue: (self: VmPipeline, exec: ExecRequest) -> (),
	completeExecution: (self: VmPipeline, executionId: string) -> (),
	forwardOutput: (self: VmPipeline, executionId: string, message: string) -> (),
	disconnect: (self: VmPipeline) -> (),
	getQueueLength: (self: VmPipeline) -> number,
	isIdle: (self: VmPipeline) -> boolean,
}

local VmPipeline = {}
VmPipeline.__index = VmPipeline

function VmPipeline.new(bitset: number, studioId: string, studioWs: any): VmPipeline
	local self = setmetatable({}, VmPipeline)
	self.bitset = bitset
	self.studioId = studioId
	self.studioWs = studioWs
	self.studioConnected = true
	self.connectedAt = os.time()
	self.execQueue = {}
	self.activeExecution = nil
	return (self :: any) :: VmPipeline
end

local function processQueue(self: VmPipeline)
	if #self.execQueue == 0 then
		return
	end

	-- Check if Studio is idle
	if not self.studioConnected or self.activeExecution then
		return
	end

	-- Get first exec from queue
	local exec = self.execQueue[1]
	table.remove(self.execQueue, 1)

	-- Set as active execution
	self.activeExecution = exec

	log.write(`Execution started: {output.formatShortLog(self.studioId, self.bitset, exec.executionId)}\n`)

	-- Send to Studio
	local message: any = {
		type = "exec",
		executionId = exec.executionId,
		script = exec.script,
		logFilter = exec.logFilter,
		cacheRequires = exec.cacheRequires,
	}

	if exec.instancePath then
		message.instancePath = exec.instancePath
	end

	self.studioWs:send(serde.encode("json", message))
end

function VmPipeline:enqueue(exec: ExecRequest)
	table.insert(self.execQueue, exec)

	exec.ws:send(serde.encode("json", {
		type = "queued",
		executionId = exec.executionId,
		position = #self.execQueue,
	}))

	log.write(`Queued execution: {output.formatShortLog(self.studioId, self.bitset, exec.executionId)}\n`)

	-- Try to process immediately
	processQueue(self)
end

function VmPipeline:completeExecution(executionId: string)
	if not self.activeExecution or self.activeExecution.executionId ~= executionId then
		return
	end

	log.write(`Execution complete: {output.formatShortLog(self.studioId, self.bitset, executionId)}\n`)

	-- Clear active execution
	self.activeExecution = nil

	-- Process next in queue
	processQueue(self)
end

function VmPipeline:forwardOutput(executionId: string, message: string)
	-- Check if this is the active execution
	if self.activeExecution and self.activeExecution.executionId == executionId then
		self.activeExecution.ws:send(message)
	end
end

function VmPipeline:disconnect()
	log.write(`{colors.debug('VM disconnected: [id:')} {self.studioId}{colors.debug('] [')} {output.formatBitset(self.bitset)}{colors.debug(']')}\n`)

	self.studioConnected = false
	pcall(function()
		self.studioWs:close()
	end)

	-- Notify active execution if any
	if self.activeExecution then
		local exec = self.activeExecution
		exec.ws:send(serde.encode("json", {
			type = "disconnect",
			executionId = exec.executionId,
		}))
		exec.ws:close()
	end

	-- Notify all queued executions
	for _, exec in ipairs(self.execQueue) do
		exec.ws:send(serde.encode("json", {
			type = "disconnect",
			executionId = exec.executionId,
		}))
		exec.ws:close()
	end
end

function VmPipeline:getQueueLength(): number
	return #self.execQueue
end

function VmPipeline:isIdle(): boolean
	return self.studioConnected and not self.activeExecution
end

return VmPipeline
