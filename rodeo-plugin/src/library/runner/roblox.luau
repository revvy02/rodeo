-- @rodeo/roblox API: import / export model files via SerializationService,
-- plus bake (Luau-source data files).
-- Returns a factory: (rpc, fs, stream, normalize, serializeToLuau) -> roblox module.

return function(rpc, fs, stream, normalize, serializeToLuau)
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

	-- Write `value` to `path` as a Luau module (`return <value>`), so the data
	-- can be required straight back into Studio. Roblox types round-trip via
	-- their constructors (vectors, CFrames, colors, enums, …); anything with no
	-- source representation (Instances, functions) becomes its `tostring`.
	--
	-- This is the same normalize → serialize → write path `--return <file>.luau`
	-- uses; that flag calls straight through here.
	function roblox.bake(path: string, value: any)
		local source = serializeToLuau(normalize(value))
		local parent = path:match("^(.+)[/\\][^/\\]+$")
		if parent and not fs.exists(parent) then
			fs.mkdir(parent)
		end
		local h = fs.open(path, "w")
		stream.write(h, source)
		stream.close(h)
	end

	-- Internal plumbing for the roblox.capture shim (rodeo-pkg/rodeo/shims/
	-- roblox.luau), which composes these with the fs/process API. Not part of
	-- the typed public surface.

	-- Ask the plugin to select a simulator preset and/or a custom desktop device
	-- at width x height for this execution. Returns the resulting
	-- Camera.ViewportSize.
	function roblox._simulatorApply(device: string?, width: number?, height: number?): (number, number)
		local runtime = _G.__rodeo_runtime_proto
		local res = rpc.call("roblox_simulator_apply", runtime.RobloxSimulatorApplyRequest.new({
			device = device,
			width = width,
			height = height,
		}))
		return res.width, res.height
	end

	function roblox._simulatorRestore()
		local runtime = _G.__rodeo_runtime_proto
		rpc.call("roblox_simulator_restore", runtime.RobloxSimulatorRestoreRequest.new({}))
	end

	-- Host side of a capture: verify the engine's frame against the viewport,
	-- resample to exactly width x height, write output, delete source.
	function roblox._captureFinalize(source: string, output: string, width: number, height: number): (number, number)
		local runtime = _G.__rodeo_runtime_proto
		local res = rpc.call("roblox_capture_finalize", runtime.RobloxCaptureFinalizeRequest.new({
			source = source,
			output = output,
			width = width,
			height = height,
		}))
		return res.width, res.height
	end

	return roblox
end
