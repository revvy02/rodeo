-- @rodeo/roblox API: load .rbxm files into Studio.
-- Returns a factory: (rpc, hostInfo, executionId) -> roblox module.

return function(rpc, hostInfo, executionId)
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

	return roblox
end
