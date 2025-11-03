-- Serve command: Persistent WebSocket server routing exec requests to Studio

local net = require("@lune/net")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local COLORS = require("../utils/colors")
local output = require("../utils/output")

type Config = {
	port: number,
}

type QueueItem = {
	executionId: string,
	script: string,
	queuedAt: number,
	timeout: number,
}

type State = {
	studioWs: any?,
	studioConnected: boolean,
	execClients: { [string]: any },
	queue: { QueueItem },
	activeExecutionId: string?,
	timeoutTasks: { [string]: thread },
}

local DEFAULT_PORT = 34872

local state: State = {
	studioWs = nil,
	studioConnected = false,
	execClients = {},
	queue = {},
	activeExecutionId = nil,
	timeoutTasks = {},
}

local function parseArguments(args: any): Config
	return {
		port = args.port or DEFAULT_PORT,
	}
end

local function safeSend(ws: any, data: string)
	pcall(function()
		ws:send(data)
	end)
end

local function cancelTimeout(executionId: string)
	local timeoutTask = state.timeoutTasks[executionId]
	if timeoutTask then
		task.cancel(timeoutTask)
		state.timeoutTasks[executionId] = nil
	end
end

local function processQueue()
	if not state.studioConnected or state.activeExecutionId or #state.queue == 0 then
		return
	end

	local item = state.queue[1]
	state.activeExecutionId = item.executionId

	stdio.write(`[serve] Starting execution: {item.executionId}\n`)

	-- Send to Studio
	safeSend(
		state.studioWs,
		serde.encode("json", {
			type = "exec",
			executionId = item.executionId,
			script = item.script,
		})
	)
end

local function notifyExecClient(executionId: string, messageType: string)
	local execClient = state.execClients[executionId]
	if not execClient then
		return
	end

	safeSend(
		execClient,
		serde.encode("json", {
			type = messageType,
			executionId = executionId,
		})
	)

	pcall(function()
		execClient:close()
	end)
end

local function removeFromQueue(executionId: string)
	for i, item in state.queue do
		if item.executionId == executionId then
			table.remove(state.queue, i)
			return
		end
	end
end

local function cleanupExecution(executionId: string)
	state.execClients[executionId] = nil
	cancelTimeout(executionId)
end

local function handleTimeout(executionId: string)
	stdio.write(`[serve] Execution timed out: {executionId}\n`)

	notifyExecClient(executionId, "timeout")
	removeFromQueue(executionId)

	if state.activeExecutionId == executionId then
		state.activeExecutionId = nil
		processQueue()
	end

	cleanupExecution(executionId)
end

local function queueExecution(ws: any, executionId: string, script: string, timeoutSeconds: number)
	state.execClients[executionId] = ws

	table.insert(state.queue, {
		executionId = executionId,
		script = script,
		queuedAt = os.time(),
		timeout = timeoutSeconds,
	} :: QueueItem)

	safeSend(
		ws,
		serde.encode("json", {
			type = "queued",
			executionId = executionId,
			position = #state.queue,
		})
	)

	stdio.write(`[serve] Queued execution: {executionId} (position {#state.queue})\n`)

	state.timeoutTasks[executionId] = task.delay(timeoutSeconds, function()
		handleTimeout(executionId)
	end)

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
			local timeoutSeconds = decoded.timeout or 300

			queueExecution(ws, clientExecutionId, decoded.script, timeoutSeconds)
		end
	end

	if clientExecutionId then
		cleanupExecution(clientExecutionId)
	end
end

local function completeExecution(executionId: string)
	stdio.write(`[serve] Execution complete: {executionId}\n`)

	state.activeExecutionId = nil
	cancelTimeout(executionId)
	table.remove(state.queue, 1)

	processQueue()
end

local function handleStudioDisconnect()
	stdio.write(`[serve] Studio plugin disconnected\n`)

	state.studioConnected = false
	state.studioWs = nil

	if state.activeExecutionId then
		notifyExecClient(state.activeExecutionId, "disconnect")
		state.activeExecutionId = nil
	end
end

local function handleStudioClient(ws: any)
	state.studioWs = ws
	state.studioConnected = true
	stdio.write(`[serve] Studio plugin connected\n`)

	processQueue()

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)

		local execClient = state.execClients[decoded.executionId]
		if execClient then
			safeSend(execClient, message)
		end

		if decoded.type == "done" then
			completeExecution(decoded.executionId)
		end
	end

	handleStudioDisconnect()
end

local function main(args: any)
	local config = parseArguments(args)

	output.printColored(`Starting server on port {config.port}`, COLORS.Info)
	output.printColored(`Waiting for Studio plugin to connect...`, COLORS.Info)

	local _server = net.serve(config.port, {
		handleRequest = function(request)
			if request.path == "/health" then
				return {
					status = 200,
					headers = {
						["Content-Type"] = "application/json",
					},
					body = serde.encode("json", {
						studioConnected = state.studioConnected,
						queueLength = #state.queue,
						activeExecution = state.activeExecutionId,
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
