-- @rodeo/roblox API: load .rbxm files into Studio, import/export via
-- SerializationService.
-- Returns a factory: (rpc, hostInfo, executionId, fs, stream) -> roblox module.

return function(rpc, hostInfo, executionId, fs, stream)
	local roblox = {}
	local contentPath = hostInfo.studioContentPath
	local cwd = hostInfo.cwd
	local SerializationService = game:GetService("SerializationService")

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

	function roblox.import(path: string): { Instance }
		local h = fs.open(path, "r")
		local data = stream.readBytes(h)
		stream.close(h)
		return SerializationService:DeserializeInstancesAsync(data)
	end

	function roblox.export(path: string, instances: { Instance })
		local buf = SerializationService:SerializeInstancesAsync(instances)
		local h = fs.open(path, "w")
		stream.writeBytes(h, buf)
		stream.close(h)
	end

	return roblox
end
