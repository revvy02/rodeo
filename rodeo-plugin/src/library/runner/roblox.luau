-- @rodeo/roblox API: load .rbxm files into Studio
-- Returns a factory: (rpc, hostInfo, executionId) -> roblox module

return function(rpc, hostInfo, executionId, process, stream)
	local roblox = {}
	local contentPath = hostInfo.studioContentPath
	local cwd = hostInfo.cwd

	function roblox.load(path: string): { Instance }
		-- Resolve absolute source path
		local src = if path:sub(1, 1) == "/" then path else cwd .. "/" .. path

		-- Compute dest in content folder
		local tempDir = contentPath .. "/rodeo-temp/" .. executionId
		local filename = path:match("[^/]+$") -- basename
		local dest = tempDir .. "/" .. filename

		-- Copy file via existing fs RPCs
		local runtime = _G.__rodeo_runtime_proto
		rpc.call("fs_mkdir", runtime.FsMkdirRequest.new({ path = tempDir }))
		rpc.call("fs_copy", runtime.FsCopyRequest.new({ src = src, dest = dest }))

		-- Load via Roblox API
		return game:GetObjects("rbxasset://rodeo-temp/" .. executionId .. "/" .. filename)
	end

	-- MCP: wraps StudioMCP via process.create + piped stdio
	roblox.mcp = {}

	local HttpService = game:GetService("HttpService")
	local mcpProc = nil
	local mcpNextId = 1

	local function mcpSend(msg)
		stream.write(mcpProc.stdin, HttpService:JSONEncode(msg) .. "\n")
	end

	local function mcpRecv()
		return HttpService:JSONDecode(stream.read(mcpProc.stdout))
	end

	local mcpReady = false

	local function ensureMcp()
		if mcpProc then
			return
		end
		mcpProc = process.create({ "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP" }, { stdio = "piped" })
		stream.write(mcpProc.stdin, '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"rodeo","version":"0.1"}}}\n')
		mcpRecv()
		stream.write(mcpProc.stdin, '{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
	end

	local function waitForStudio()
		if mcpReady then
			return
		end
		for _ = 1, 10 do
			mcpNextId += 1
			mcpSend({ jsonrpc = "2.0", id = mcpNextId, method = "tools/call", params = { name = "execute_luau", arguments = { code = "return 'ok'" } } })
			local response = mcpRecv()
			local text = response.result and response.result.content and response.result.content[1] and response.result.content[1].text
			if text == "ok" then
				mcpReady = true
				return
			end
			task.wait(1)
		end
		error("Studio MCP not connected. Enable 'MCP Server' in Studio's AI Assistant settings.")
	end

	function roblox.mcp.call(tool: string, arguments: { [string]: any }?)
		ensureMcp()
		waitForStudio()
		local id = mcpNextId
		mcpNextId += 1
		mcpSend({ jsonrpc = "2.0", id = id, method = "tools/call", params = { name = tool, arguments = arguments or {} } })
		while true do
			local response = mcpRecv()
			if response.id == id or tostring(response.id) == tostring(id) then
				return response
			end
		end
	end

	return roblox
end
