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
		local h = fs.open(path, "w")
		stream.writeBytes(h, buf)
		-- Finalize in place of stream.close: consumes the handle, converts to
		-- XML when the extension is .rbxmx/.rbxlx, writes atomically.
		local runtime = _G.__rodeo_runtime_proto
		rpc.call("roblox_export", runtime.RobloxExportRequest.new({ handle = h.__handle }))
	end

	return roblox
end
