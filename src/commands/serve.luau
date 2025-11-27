--!nonstrict

local net = require("@lune/net")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local colors = require("../utils/colors")
local ExecConnection = require("../utils/ExecConnection")
local StudioConnection = require("../utils/StudioConnection")
local VmPipeline = require("../utils/VmPipeline")
local constants = require("../utils/constants")
local output = require("../utils/output")

type StudioConnection = StudioConnection.StudioConnection
type ExecConnection = ExecConnection.ExecConnection
type VmPipeline = VmPipeline.VmPipeline

-- Nested map: bitset -> studioId -> VmPipeline
local pipelines: { [number]: { [string]: VmPipeline } } = {}

-- Pending executions waiting for a matching VM to connect
local pendingExecutions: { ExecConnection } = {}

local function generateId(): string
	local random = math.random
	return string.format("%08x-%04x-%04x-%04x-%012x", random(0, 0xffffffff), random(0, 0xffff), random(0, 0xffff), random(0, 0xffff), random(0, 0xffffffffffff))
end

type MatchingVm = {
	bitset: number,
	studioId: string,
	pipeline: VmPipeline,
}

local function findMatchingVmPipelines(filterBits: number, filterMask: number): { MatchingVm }
	local matches = {}
	for vmBitset, vmMap in pairs(pipelines) do
		if bit32.band(vmBitset, filterMask) == filterBits then
			for studioId, vmPipeline in pairs(vmMap) do
				table.insert(matches, {
					bitset = vmBitset,
					studioId = studioId,
					pipeline = vmPipeline,
				})
			end
		end
	end
	return matches
end

local function selectBestVmPipeline(matches: { MatchingVm }): MatchingVm?
	if #matches == 0 then
		return nil
	end

	-- Load balancing: select VM with shortest queue
	local best = matches[1]
	for i = 2, #matches do
		if matches[i].pipeline:getQueueLength() < best.pipeline:getQueueLength() then
			best = matches[i]
		end
	end

	return best
end

local function cleanupEmptyPipelines()
	for bitset, vmMap in pairs(pipelines) do
		local hasAnyVms = false
		for _ in pairs(vmMap) do
			hasAnyVms = true
			break
		end
		if not hasAnyVms then
			pipelines[bitset] = nil
		end
	end
end

local function removePipelineFromMap(bitset: number, studioId: string)
	-- Remove from pipeline map
	if pipelines[bitset] then
		pipelines[bitset][studioId] = nil
	end

	cleanupEmptyPipelines()
end

local function processPendingExecutions()
	-- Try to assign pending executions to newly connected VMs
	local i = 1
	while i <= #pendingExecutions do
		local exec = pendingExecutions[i]
		local matchingVms = findMatchingVmPipelines(exec.filterBits, exec.filterMask)

		if #matchingVms > 0 then
			-- Found a matching VM, remove from pending and enqueue
			table.remove(pendingExecutions, i)
			local bestVm = selectBestVmPipeline(matchingVms)
			if bestVm then
				stdio.write(colors.success(`Processing pending execution: {exec.executionId}`) .. "\n")
				bestVm.pipeline:enqueue(exec)
			end
		else
			-- Still no match, keep in pending
			i = i + 1
		end
	end
end

local function handleExecClient(ws: any)
	local clientExecutionId = nil
	local execConnection = nil

	while true do
		local success, message = pcall(function()
			return ws:next()
		end)

		if not success then
			-- Connection reset or closed unexpectedly
			if clientExecutionId then
				stdio.write(colors.grey(`Execution cancelled: {clientExecutionId}`) .. "\n")
			end
			break
		end

		if not message then
			break
		end

		local decoded = serde.decode("json", message)

		if decoded.type == "submit" then
			clientExecutionId = decoded.executionId
			local filterBits = decoded.filterBits or 0
			local filterMask = decoded.filterMask or 0
			local logFilter = decoded.logFilter or {
				enableWarn = true,
				enableError = true,
				enableInfo = true,
				enableOutput = true,
				enableLogs = true,
			}
			execConnection = ExecConnection.new(ws, clientExecutionId, decoded.script, decoded.instancePath, filterBits, filterMask, logFilter, decoded.cacheRequires)

			-- Find matching VM pipelines
			local matchingVms = findMatchingVmPipelines(filterBits, filterMask)

			if #matchingVms == 0 then
				-- No matching VMs - add to pending queue
				table.insert(pendingExecutions, execConnection)
				stdio.write(`Waiting for VM: [{output.formatBitset(filterBits, filterMask)}]\n`)
			else
				-- Use load balancing to select best VM
				local bestVm = selectBestVmPipeline(matchingVms)
				if bestVm then
					bestVm.pipeline:enqueue(execConnection)
				end
			end
		end
	end

	-- Cleanup: remove from pending queue if still there
	if execConnection and clientExecutionId then
		for i, pending in ipairs(pendingExecutions) do
			if pending.executionId == clientExecutionId then
				table.remove(pendingExecutions, i)
				break
			end
		end
	end
	ws:close()
end

local function handleStudioClient(ws: any, vmBitset: number)
	local studioId = generateId()
	local studioConnection = StudioConnection.new(ws, vmBitset)

	-- Create VmPipeline for this Studio
	local vmPipeline = VmPipeline.new(vmBitset, studioId, studioConnection)

	-- Add to nested pipeline map
	if not pipelines[vmBitset] then
		pipelines[vmBitset] = {}
	end
	pipelines[vmBitset][studioId] = vmPipeline

	stdio.write(`VM connected: {colors.grey('[id:')} {studioId}{colors.grey('] [')} {output.formatBitset(vmBitset)}{colors.grey(']')}\n`)

	-- Process any pending executions that might match this new VM
	processPendingExecutions()

	print("[handleStudioClient] entering message loop")
	while true do
		local success, message = pcall(function()
			return ws:next()
		end)

		if not success then
			-- Connection reset or closed unexpectedly
			print("[handleStudioClient] ws:next() failed, breaking loop")
			break
		end

		if not message then
			print("[handleStudioClient] ws:next() returned nil, breaking loop")
			break
		end

		local decoded = serde.decode("json", message)

		-- Forward output to exec client
		vmPipeline:forwardOutput(decoded.executionId, message)

		if decoded.type == "done" then
			vmPipeline:completeExecution(decoded.executionId)
		end
	end

	-- Handle disconnect
	print("[handleStudioClient] calling vmPipeline:disconnect()")
	vmPipeline:disconnect()
	print("[handleStudioClient] calling removePipelineFromMap")
	removePipelineFromMap(vmBitset, studioId)
	print("[handleStudioClient] done")
end

local function main(args: any)
	local port = args.port
	stdio.write(colors.cyan(`Starting server on port {port}`) .. "\n")
	stdio.write(colors.cyan(`Waiting for Studio plugin to connect...`) .. "\n")

	local _server = net.serve(port, {
		handleRequest = function(request)
			if request.path == "/health" then
				local contextStatus = {}
				local totalVms = 0
				local totalQueued = 0

				for bitset, vmMap in pairs(pipelines) do
					local vms = {}
					local contextQueued = 0

					for studioId, vmPipeline in pairs(vmMap) do
						local queueLength = vmPipeline:getQueueLength()
						table.insert(vms, {
							studioId = studioId,
							queueLength = queueLength,
							isIdle = vmPipeline:isIdle(),
						})
						contextQueued = contextQueued + queueLength
						totalVms = totalVms + 1
					end

					table.insert(contextStatus, {
						bitset = bitset,
						vmCount = #vms,
						totalQueued = contextQueued,
						vms = vms,
					})
					totalQueued = totalQueued + contextQueued
				end

				return {
					status = 200,
					headers = {
						["Content-Type"] = "application/json",
					},
					body = serde.encode("json", {
						contextCount = #contextStatus,
						totalVms = totalVms,
						totalQueued = totalQueued,
						contexts = contextStatus,
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
				local vmBitset = decoded.contextBitset or 0
				handleStudioClient(socket, vmBitset)
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
