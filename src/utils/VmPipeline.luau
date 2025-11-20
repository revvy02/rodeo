local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local colors = require("./colors")
local ExecConnection = require("./ExecConnection")
local StudioConnection = require("./StudioConnection")
local output = require("./output")

type StudioConnection = StudioConnection.StudioConnection
type ExecConnection = ExecConnection.ExecConnection

export type VmPipeline = {
	bitset: number,
	studioId: string,
	studio: StudioConnection,
	execQueue: { ExecConnection },
	activeExecution: ExecConnection?,
	completedExecutions: { [string]: { connection: ExecConnection, timestamp: number } },

	new: (bitset: number, studioId: string, studio: StudioConnection) -> VmPipeline,
	enqueue: (self: VmPipeline, exec: ExecConnection) -> (),
	completeExecution: (self: VmPipeline, executionId: string) -> (),
	forwardOutput: (self: VmPipeline, executionId: string, message: string) -> (),
	disconnect: (self: VmPipeline) -> (),
	getQueueLength: (self: VmPipeline) -> number,
	isIdle: (self: VmPipeline) -> boolean,
}

local VmPipeline = {}
VmPipeline.__index = VmPipeline

function VmPipeline.new(bitset: number, studioId: string, studio: StudioConnection): VmPipeline
	local self = setmetatable({}, VmPipeline)
	self.bitset = bitset
	self.studioId = studioId
	self.studio = studio
	self.execQueue = {}
	self.activeExecution = nil
	self.completedExecutions = {}
	return (self :: any) :: VmPipeline
end

local function processQueue(self: VmPipeline)
	if #self.execQueue == 0 then
		return
	end

	-- Check if Studio is idle
	if not self.studio:isConnected() or self.activeExecution then
		return
	end

	-- Get first exec from queue
	local exec = self.execQueue[1]
	table.remove(self.execQueue, 1)

	-- Set as active execution
	self.activeExecution = exec

	stdio.write(`Execution started: {output.formatShortLog(self.studioId, self.bitset, exec.executionId)}\n`)

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

	self.studio:send(serde.encode("json", message))
end

function VmPipeline:enqueue(exec: ExecConnection)
	table.insert(self.execQueue, exec)

	exec:send(serde.encode("json", {
		type = "queued",
		executionId = exec.executionId,
		position = #self.execQueue,
	}))

	stdio.write(`Queued execution: {output.formatShortLog(self.studioId, self.bitset, exec.executionId)}\n`)

	-- Try to process immediately
	processQueue(self)
end

function VmPipeline:completeExecution(executionId: string)
	if not self.activeExecution or self.activeExecution.executionId ~= executionId then
		return
	end

	stdio.write(`Execution complete: {output.formatShortLog(self.studioId, self.bitset, executionId)}\n`)

	-- Store completed execution for late-arriving messages
	local currentTime = os.time()
	self.completedExecutions[executionId] = {
		connection = self.activeExecution,
		timestamp = currentTime,
	}

	-- Clear active execution
	self.activeExecution = nil

	-- Clean up old completed executions (older than 2 seconds)
	for id, data in pairs(self.completedExecutions) do
		if currentTime - data.timestamp > 2 then
			self.completedExecutions[id] = nil
		end
	end

	-- Process next in queue
	processQueue(self)
end

function VmPipeline:forwardOutput(executionId: string, message: string)
	-- Check if this is the active execution
	if self.activeExecution and self.activeExecution.executionId == executionId then
		local e = self.activeExecution :: ExecConnection
		e:send(message)
		return
	end

	-- Check if this is a recently completed execution (late-arriving output)
	local completed = self.completedExecutions[executionId]
	if completed then
		completed.connection:send(message)
	end
end

function VmPipeline:disconnect()
	stdio.write(`{colors.grey('VM disconnected: [id:')} {self.studioId}{colors.grey('] [')} {output.formatBitset(self.bitset)}{colors.grey(']')}\n`)

	self.studio:close()

	-- Notify active execution if any
	if self.activeExecution then
		local exec = self.activeExecution :: ExecConnection
		exec:send(serde.encode("json", {
			type = "disconnect",
			executionId = exec.executionId,
		}))
		exec:close()
	end

	-- Notify all queued executions
	for _, exec in ipairs(self.execQueue) do
		local e = exec :: ExecConnection
		e:send(serde.encode("json", {
			type = "disconnect",
			executionId = e.executionId,
		}))
		e:close()
	end
end

function VmPipeline:getQueueLength(): number
	return #self.execQueue
end

function VmPipeline:isIdle(): boolean
	return self.studio:isConnected() and not self.activeExecution
end

return VmPipeline
