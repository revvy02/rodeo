-- Status command: Check if rodeo serve is running

local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local colors = require("../utils/colors")
local constants = require("../utils/constants")
local output = require("../utils/output")

local function checkServerStatus(port: number): (boolean, any?)
	local success, response = pcall(function()
		return net.request({
			url = `http://localhost:{port}/health`,
			method = "GET",
		})
	end)

	if not success then
		return false, nil
	end

	if not response.ok then
		return false, nil
	end

	local healthData = serde.decode("json", response.body)
	return true, healthData
end

local function formatStatus(healthData: any, port: number)
	stdio.write(colors.success("rodeo serve is running") .. "\n")
	stdio.write(colors.cyan(`Port: {port}`) .. "\n")
	stdio.write(colors.cyan(`Total VMs: {healthData.totalVms}`) .. "\n")
	stdio.write(colors.cyan(`Total Queued: {healthData.totalQueued}`) .. "\n")
	stdio.write(colors.cyan(`Context Groups: {healthData.contextCount}`) .. "\n")

	if healthData.contextCount > 0 then
		print("")
		stdio.write(colors.cyan("Connected Studios:") .. "\n")
		for _, context in ipairs(healthData.contexts) do
			local bitsetFormatted = output.formatBitsetShort(context.bitset)
			stdio.write(colors.grey(`  Context [{bitsetFormatted}]: {context.vmCount} VM(s), {context.totalQueued} queued`) .. "\n")

			for _, vm in ipairs(context.vms) do
				local studioIdShort = vm.studioId:sub(1, 8)
				local idleStatus = vm.isIdle and "idle" or "busy"
				local idleColorFn = vm.isIdle and colors.success or colors.warning
				stdio.write(`{colors.grey(`    - {studioIdShort}: {vm.queueLength} in queue, `)}{idleColorFn(idleStatus)}\n`)
			end
		end
	end
end

local function main(args: any)
	local port = args.port
	local isRunning, healthData = checkServerStatus(port)

	if not isRunning then
		stdio.write(colors.error(`Error: rodeo serve is not running on port {port}`) .. "\n")
		process.exit(1)
	end

	formatStatus(healthData, port)
	process.exit(0)
end

return main
