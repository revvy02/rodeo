local net = require("@lune/net")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local COLORS = require("../utils/colors")
local output = require("../utils/output")
local constants = require("../utils/constants")
local StudioConnection = require("../utils/StudioConnection")
local ExecConnection = require("../utils/ExecConnection")

type StudioConnection = StudioConnection.StudioConnection
type ExecConnection = ExecConnection.ExecConnection

type QueueItem = {
	executionId: string,
	script: string,
	instancePath: string?,
	queuedAt: number,
}

type State = {
	studioConnection: StudioConnection?,
	execConnections: { [string]: ExecConnection },
	queue: { QueueItem },
}

local state: State = {
	studioConnection = nil,
	execConnections = {},
	queue = {},
}

local function processQueue()
	if not state.studioConnection or not state.studioConnection:isConnected() then
		return
	end

	if state.studioConnection.activeExecutionId or #state.queue == 0 then
		return
	end

	local item = state.queue[1]
	state.studioConnection.activeExecutionId = item.executionId

	stdio.write(`[serve] Starting execution: {item.executionId}\n`)

	local message: any = {
		type = "exec",
		executionId = item.executionId,
		script = item.script,
	}

	if item.instancePath then
		message.instancePath = item.instancePath
	end

	state.studioConnection:send(serde.encode("json", message))
end

local function notifyExecClient(executionId: string, messageType: string)
	local execConnection = state.execConnections[executionId]
	if not execConnection then
		return
	end

	execConnection:send(serde.encode("json", {
		type = messageType,
		executionId = executionId,
	}))

	execConnection:close()
end

local function cleanupExecution(executionId: string)
	state.execConnections[executionId] = nil
end

local function queueExecution(execConnection: ExecConnection, script: string, instancePath: string?)
	local executionId = execConnection.executionId
	state.execConnections[executionId] = execConnection

	table.insert(state.queue, {
		executionId = executionId,
		script = script,
		instancePath = instancePath,
		queuedAt = os.time(),
	} :: QueueItem)

	execConnection:send(serde.encode("json", {
		type = "queued",
		executionId = executionId,
		position = #state.queue,
	}))

	stdio.write(`[serve] Queued execution: {executionId} (position {#state.queue})\n`)

	processQueue()
end

local function handleExecClient(ws: any)
	local clientExecutionId = nil

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)

		if decoded.type == "submit" then
			clientExecutionId = decoded.executionId
			local execConnection = ExecConnection.new(ws, clientExecutionId)
			queueExecution(execConnection, decoded.script, decoded.instancePath)
		end
	end

	if clientExecutionId then
		cleanupExecution(clientExecutionId)
	end
end

local function completeExecution(executionId: string)
	stdio.write(`[serve] Execution complete: {executionId}\n`)

	if state.studioConnection then
		state.studioConnection.activeExecutionId = nil
	end
	table.remove(state.queue, 1)

	processQueue()
end

local function handleStudioDisconnect(studioConnection: StudioConnection)
	stdio.write(`[serve] Studio plugin disconnected\n`)

	studioConnection:close()
	state.studioConnection = nil

	if studioConnection.activeExecutionId then
		notifyExecClient(studioConnection.activeExecutionId, "disconnect")
	end
end

local function handleStudioClient(ws: any)
	if state.studioConnection and state.studioConnection:isConnected() then
		stdio.write(`[serve] Rejected connection: Studio already connected\n`)
		pcall(function()
			ws:send(serde.encode("json", {
				type = "error",
				message = "Another Studio instance is already connected to this server"
			}))
			ws:close()
		end)
		return
	end

	local studioConnection = StudioConnection.new(ws)
	state.studioConnection = studioConnection
	stdio.write(`[serve] Studio plugin connected\n`)

	processQueue()

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)

		local execConnection = state.execConnections[decoded.executionId]
		if execConnection then
			execConnection:send(message)
		end

		if decoded.type == "done" then
			completeExecution(decoded.executionId)
		end
	end

	handleStudioDisconnect(studioConnection)
end

local function main(_args: any)
	output.printColored(`Starting server on port {constants.SERVE_PORT}`, COLORS.Info)
	output.printColored(`Waiting for Studio plugin to connect...`, COLORS.Info)

	local _server = net.serve(constants.SERVE_PORT, {
		handleRequest = function(request)
			if request.path == "/health" then
				local studioConnected = state.studioConnection ~= nil and state.studioConnection:isConnected()
				local activeExecution = if state.studioConnection then state.studioConnection.activeExecutionId else nil

				return {
					status = 200,
					headers = {
						["Content-Type"] = "application/json",
					},
					body = serde.encode("json", {
						studioConnected = studioConnected,
						queueLength = #state.queue,
						activeExecution = activeExecution,
					}),
				}
			end

			return {
				status = 404,
				body = "Not Found",
			}
		end,

		handleWebSocket = function(socket)
			local firstMessage = socket:next()
			if not firstMessage then
				socket:close()
				return
			end

			local success, decoded = pcall(serde.decode, "json", firstMessage)
			if not success or not decoded.clientType then
				socket:close()
				return
			end

			if decoded.clientType == "studio" then
				handleStudioClient(socket)
			elseif decoded.clientType == "exec" then
				handleExecClient(socket)
			else
				socket:close()
			end
		end,
	})

	stdio.write(`[serve] Server started.\n`)

	while true do
		task.wait(1)
	end
end

return main
