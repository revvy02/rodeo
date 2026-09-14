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

	-- Editable image codecs. EditableImage/EditableMesh are runtime Objects
	-- with no file representation (SerializationService writes an
	-- Object-backed Content as an empty reference), so these move their pixels
	-- between files and Studio directly: PNG on the host side, RGBA8 buffers
	-- on the Studio side, streamed in chunks over the same fs/stream RPCs
	-- export/import use.

	local AssetService = game:GetService("AssetService")
	local nextImageId = 0

	function roblox.exportEditableImage(path: string, image: EditableImage)
		local okClass, className = pcall(function()
			return (image :: any).ClassName
		end)
		if not okClass or className ~= "EditableImage" then
			error("exportEditableImage: expected an EditableImage", 2)
		end
		local size = image.Size
		local width, height = size.X, size.Y
		local pixels = image:ReadPixelsBuffer(Vector2.zero, size)
		local expected = width * height * 4
		if buffer.len(pixels) ~= expected then
			error(`exportEditableImage: pixel buffer is {buffer.len(pixels)} bytes, expected {expected} for {width}x{height}`, 2)
		end
		local runtime = _G.__rodeo_runtime_proto
		local h = fs.open(path, "w")
		stream.writeBytes(h, pixels)
		-- Finalize in place of stream.close: consumes the handle, encodes PNG.
		rpc.call("roblox_image_encode", runtime.RobloxImageEncodeRequest.new({
			handle = h.__handle,
			width = width,
			height = height,
		}))
	end

	function roblox.importEditableImage(path: string): EditableImage
		local runtime = _G.__rodeo_runtime_proto
		nextImageId += 1
		local handle = { __handle = `image:{nextImageId}:{path}` }
		local res = rpc.call("roblox_image_decode", runtime.RobloxImageDecodeRequest.new({
			path = path,
			handle = handle.__handle,
		}))
		local pixels = stream.readBytes(handle)
		stream.close(handle)
		local width, height = res.width, res.height
		local expected = width * height * 4
		if buffer.len(pixels) ~= expected then
			error(`importEditableImage: received {buffer.len(pixels)} bytes, expected {expected} for {width}x{height}`, 2)
		end
		local okCreate, image = pcall(function()
			return AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })
		end)
		if not okCreate or not image then
			error(`importEditableImage: Studio refused an EditableImage of {width}x{height} ({path}): {tostring(image)}`, 2)
		end
		image:WritePixelsBuffer(Vector2.zero, image.Size, pixels)
		return image
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

	-- Host side of a capture. `handle` is an open FileWriter on the output
	-- path holding the frame's RGBA8 bytes (streamed via stream.writeBytes);
	-- consumed here in place of stream.close: verify the frame is a whole
	-- multiple of the viewport, resample to exactly width x height, encode
	-- PNG, write atomically.
	function roblox._captureFinalize(handle: string, sourceWidth: number, sourceHeight: number, width: number, height: number): (number, number)
		local runtime = _G.__rodeo_runtime_proto
		local res = rpc.call("roblox_capture_finalize", runtime.RobloxCaptureFinalizeRequest.new({
			handle = handle,
			sourceWidth = sourceWidth,
			sourceHeight = sourceHeight,
			width = width,
			height = height,
		}))
		return res.width, res.height
	end

	return roblox
end
