-- @rodeo/roblox API: import / export model files via SerializationService.
-- Returns a factory: (rpc, fs, stream) -> roblox module.

return function(rpc, fs, stream)
	local roblox = {}
	local SerializationService = game:GetService("SerializationService")

	function roblox.import(path: string): { Instance }
		local h = fs.open(path, "r")
		local data = stream.readBytes(h)
		stream.close(h)
		return SerializationService:DeserializeInstancesAsync(data)
	end

	function roblox.export(path: string, instances: { Instance })
		local buf = SerializationService:SerializeInstancesAsync(instances)
		local runtime = _G.__rodeo_runtime_proto
		rpc.call("roblox_export", runtime.RobloxExportRequest.new({ path = path, data = buf }))
	end

	return roblox
end
