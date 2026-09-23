-- Exact portable curves/deltas and their deliberately separate Roblox preview.
local motion = {}

local function vectorMap(values, ids)
	if not values then
		return nil
	end
	local result = {}
	for i, value in values do
		result[ids[i]] = Vector3.new(unpack(value))
	end
	return result
end

function motion.importMorph(mesh, attributes, info)
	local result = { mesh = mesh, targets = {} }
	if info.tangents then
		result.tangents = {}
		for i, value in info.tangents do
			result.tangents[attributes.vertices[i]] = value
		end
	end
	for _, target in info.targets do
		table.insert(result.targets, {
			name = target.name,
			positions = vectorMap(target.positions, attributes.vertices),
			normals = vectorMap(target.normals, attributes.normals),
			tangents = vectorMap(target.tangents, attributes.vertices),
		})
	end
	-- Geometry remains the shared, editable base. Weights and deltas are
	-- authoritative data; export never has to undo a remembered preview pose.
	return result
end

function motion.exportMorph(morph, corners)
	local function vectors(values, ids, label)
		if not values then
			return nil
		end
		local result = {}
		for _, id in ids do
			local value = assert(
				values[id],
				`morph {label}: no delta for editable attribute {id}; update targets after topology edits`
			)
			table.insert(result, { value.X, value.Y, value.Z })
		end
		return result
	end
	local result = { targets = {} }
	if morph.tangents then
		result.tangents = {}
		for _, id in corners.vertices do
			local tangent = assert(morph.tangents[id], `missing base tangent for vertex {id}`)
			table.insert(result.tangents, tangent)
		end
	end
	for _, target in morph.targets do
		table.insert(result.targets, {
			name = target.name,
			positions = vectors(target.positions, corners.vertices, "positions"),
			normals = vectors(target.normals, corners.normals, "normals"),
			tangents = vectors(target.tangents, corners.vertices, "tangents"),
		})
	end
	return result
end

function motion.exportAnimations(scene, nodeIds)
	local result = {}
	for _, animation in scene.animations or {} do
		local clip =
			{ name = animation.name, sourceIndex = animation.sourceIndex, metadata = animation.metadata, channels = {} }
		for _, channel in animation.channels do
			local targets = { channel.node }
			if channel.path == "weights" then
				targets = {}
				for _, binding in scene.morphWeights or {} do
					if binding.node == channel.node then
						table.insert(targets, binding.part)
					end
				end
				assert(#targets > 0, "weight animation has no morph bindings")
			end
			for _, target in targets do
				local id = assert(
					nodeIds[target],
					"animation target is outside the exported roots; remove or retarget its channel"
				)
				table.insert(clip.channels, {
					node = id,
					path = channel.path,
					interpolation = channel.interpolation,
					times = channel.times,
					values = channel.values,
				})
			end
		end
		table.insert(result, clip)
	end
	return result
end

local function quaternion(values)
	return CFrame.new(0, 0, 0, values[1], values[2], values[3], values[4])
end

-- glTF's cubic tangent units are value/second, so multiply by segment duration.
-- Quaternion LINEAR is shortest-path slerp; cubic is componentwise Hermite,
-- normalized afterward without flipping either endpoint or its tangents.
function motion.sample(channel, time, components)
	local times, values = channel.times, channel.values
	local cubic = channel.interpolation == "CUBICSPLINE"
	local stride = components * (if cubic then 3 else 1)
	local function value(key, section)
		local result = {}
		local offset = (key - 1) * stride + (if cubic then section * components else 0)
		for i = 1, components do
			result[i] = values[offset + i]
		end
		return result
	end
	if time <= times[1] then
		return value(1, 1)
	end
	if time >= times[#times] then
		return value(#times, 1)
	end
	local lo, hi = 1, #times
	while lo + 1 < hi do
		local mid = (lo + hi) // 2
		if times[mid] <= time then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = value(lo, 1), value(hi, 1)
	if channel.interpolation == "STEP" then
		return a
	end
	local duration = times[hi] - times[lo]
	local t = (time - times[lo]) / duration
	local result = {}
	if cubic then
		local outgoing, incoming = value(lo, 2), value(hi, 0)
		local t2, t3 = t * t, t * t * t
		for i = 1, components do
			result[i] = (2 * t3 - 3 * t2 + 1) * a[i]
				+ (t3 - 2 * t2 + t) * duration * outgoing[i]
				+ (-2 * t3 + 3 * t2) * b[i]
				+ (t3 - t2) * duration * incoming[i]
		end
	elseif channel.path == "rotation" then
		local dot = 0
		for i = 1, 4 do
			dot += a[i] * b[i]
		end
		if dot < 0 then
			for i = 1, 4 do
				b[i] = -b[i]
			end
			dot = -dot
		end
		local left, right = 1 - t, t
		if dot < 0.9995 then
			local angle = math.acos(math.clamp(dot, -1, 1))
			left, right = math.sin((1 - t) * angle) / math.sin(angle), math.sin(t * angle) / math.sin(angle)
		end
		for i = 1, 4 do
			result[i] = left * a[i] + right * b[i]
		end
	else
		for i = 1, components do
			result[i] = (1 - t) * a[i] + t * b[i]
		end
	end
	if channel.path == "rotation" then
		local length = 0
		for i = 1, 4 do
			length += result[i] ^ 2
		end
		assert(length > 1e-12, "animation cubic quaternion evaluates to zero")
		for i = 1, 4 do
			result[i] /= math.sqrt(length)
		end
	end
	return result
end

local function multiply(a, b)
	local out = {}
	for col = 1, 4 do
		out[col] = {}
		for row = 1, 4 do
			local value = 0
			for k = 1, 4 do
				value += a[k][row] * b[col][k]
			end
			out[col][row] = value
		end
	end
	return out
end
local identity = { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } }
local function trsMatrix(trs)
	local cf = quaternion(trs.rotation) + Vector3.new(unpack(trs.translation))
	local x, y, z = cf.XVector * trs.scale[1], cf.YVector * trs.scale[2], cf.ZVector * trs.scale[3]
	return { { x.X, x.Y, x.Z, 0 }, { y.X, y.Y, y.Z, 0 }, { z.X, z.Y, z.Z, 0 }, { cf.X, cf.Y, cf.Z, 1 } }
end
local function rigid(m)
	local x, y, z = Vector3.new(unpack(m[1])), Vector3.new(unpack(m[2])), Vector3.new(unpack(m[3]))
	assert(math.min(x.Magnitude, y.Magnitude, z.Magnitude) > 1e-8, "sampled node has zero scale")
	x, y, z = x.Unit, y.Unit, z.Unit
	assert(math.max(math.abs(x:Dot(y)), math.abs(y:Dot(z)), math.abs(z:Dot(x))) < 1e-4, "sampled node contains shear")
	if x:Dot(y:Cross(z)) < 0 then
		x = -x
	end
	return CFrame.fromMatrix(Vector3.new(unpack(m[4])), x, y, z)
end

function motion.buildRig(scene, document, nodes, own)
	local hasTransforms = false
	for _, clip in scene.animations do
		local unsupported = {}
		for _, channel in clip.channels do
			if channel.path == "translation" or channel.path == "rotation" then
				hasTransforms = true
			else
				unsupported[channel.path] = true
			end
		end
		for path in unsupported do
			table.insert(
				scene.warnings,
				`animation {clip.name}: {path} channels preserved but not played by the Roblox preview`
			)
		end
	end
	if not hasTransforms then
		return
	end
	local names = {}
	for _, root in scene.roots do
		names[root.Name] = true
		for _, descendant in root:GetDescendants() do
			names[descendant.Name] = true
		end
	end
	local function unique(name)
		while names[name] do
			name ..= "_"
		end
		names[name] = true
		return name
	end
	local function helper(class, name, parent)
		local instance = own(Instance.new(class))
		instance.Name, instance.Parent = name, parent
		instance:SetAttribute("RodeoSceneHelper", true)
		return instance
	end
	local rig = scene.roots[1]
	local function anchor(name, frame, parent)
		local part = helper("Part", name, parent)
		part.Size, part.CFrame = Vector3.one, frame
		part.Transparency, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow =
			1, false, false, false, false
		part.Massless = true
		return part
	end
	local rootPart = anchor(unique("__RodeoRoot"), CFrame.identity, rig)
	rootPart.Anchored = true
	rig.PrimaryPart = rootPart
	local controller = helper("AnimationController", "AnimationController", rig)
	local animator = helper("Animator", "Animator", controller)
	local clips = helper("Folder", "Animations", rig)
	local parentOf, indexOf = {}, {}
	for i, node in nodes do
		indexOf[node] = i
	end
	for i, node in document.nodes do
		for _, child in node.children do
			parentOf[child + 1] = i
		end
	end
	local anchors, motors, partOffsets, partNodes = {}, {}, {}, {}
	local function joint(part, parent)
		local motor = helper("Motor6D", part.Name, parent)
		motor.Part0, motor.Part1 = parent, part
		motor.C0 = parent.CFrame:ToObjectSpace(part.CFrame)
		motors[part] = motor
		part.Anchored = false
	end
	for i, node in nodes do
		local frame = if node:IsA("Attachment") then node.WorldCFrame else node:GetPivot()
		-- Keep generated names distinct from arbitrary imported mesh names.
		local name = unique("__RodeoNode" .. i)
		anchors[i] = anchor(name, frame, if node:IsA("Model") then node else rig)
		if node:IsA("Model") then
			node.PrimaryPart = anchors[i]
		end
	end
	for i, part in anchors do
		joint(part, if parentOf[i] then anchors[parentOf[i]] else rootPart)
	end
	for _, binding in scene.sourceMap.primitives do
		local i = indexOf[scene.sourceMap.nodes[binding.nodeIndex]]
		local part = binding.part
		partOffsets[part] = anchors[i].CFrame:ToObjectSpace(part.CFrame)
		partNodes[part] = i
		joint(part, anchors[i])
	end
	scene.animationRig, scene.animator = rig, animator
	local boneSources = {}
	for source, bindings in scene.sourceMap.joints do
		for _, binding in bindings do
			boneSources[binding.bone] = indexOf[scene.sourceMap.nodes[source]]
		end
	end
	local function uniformAncestors(index)
		while index do
			local s = document.nodes[index].rest.scale
			if s[1] <= 0 or math.abs(s[1] - s[2]) > 1e-6 or math.abs(s[1] - s[3]) > 1e-6 then
				return false
			end
			index = parentOf[index]
		end
		return true
	end
	for _, clip in scene.animations do
		local animated, channels = {}, {}
		for _, channel in clip.channels do
			if channel.path == "translation" or channel.path == "rotation" then
				local index = indexOf[channel.node]
				animated[index] = true
				channels[index] = channels[index] or {}
				channels[index][channel.path] = channel
			end
		end
		if next(animated) == nil then
			continue
		end
		local function affected(index)
			while index do
				if animated[index] then
					return true
				end
				index = parentOf[index]
			end
			return false
		end
		local function relativeStatic(a, b)
			local ancestors = {}
			local index = a
			while index do
				ancestors[index] = true
				index = parentOf[index]
			end
			index = b
			while index and not ancestors[index] do
				if animated[index] then
					return false
				end
				index = parentOf[index]
			end
			local common = index
			index = a
			while index ~= common do
				if animated[index] then
					return false
				end
				index = parentOf[index]
			end
			return true
		end

		local native = own(Instance.new("CurveAnimation"))
		native.Name, native.Loop = clip.name, type(clip.metadata) == "table" and clip.metadata.loop == true
		if type(clip.metadata) == "table" and clip.metadata.priority then
			for _, priority in Enum.AnimationPriority:GetEnumItems() do
				if priority.Name == clip.metadata.priority then
					native.Priority = priority
					break
				end
			end
		end
		local approximated, quantized = false, false
		local ok, err = xpcall(function()
			for index in animated do
				assert(not nodes[index]:IsA("Attachment"), "Attachment-targeted animation is not supported by Animator")
			end
			local function framesAt(time, override, value)
				local localTrs, worlds, frames = {}, {}, {}
				for i, node in document.nodes do
					localTrs[i] = table.clone(node.rest)
				end
				if time ~= nil then
					for _, channel in clip.channels do
						if channel.path == "translation" or channel.path == "rotation" then
							localTrs[indexOf[channel.node]][channel.path] =
								motion.sample(channel, time, if channel.path == "rotation" then 4 else 3)
						end
					end
				end
				if override then
					localTrs[indexOf[override.node]][override.path] = value
				end
				for i, trs in localTrs do
					worlds[i] = multiply(if parentOf[i] then worlds[parentOf[i]] else identity, trsMatrix(trs))
					frames[i] = rigid(worlds[i])
				end
				return frames
			end
			local function poseFrame(instance, source, frames)
				if not instance:IsA("Bone") then
					local parentFrame = if parentOf[source] then frames[parentOf[source]] else CFrame.identity
					return motors[instance].C0:ToObjectSpace(parentFrame:ToObjectSpace(frames[source]))
				end
				local parent = instance.Parent
				local parentFrame = if parent:IsA("Bone")
					then frames[boneSources[parent]]
					else frames[partNodes[parent]] * partOffsets[parent]
				return instance.CFrame:ToObjectSpace(parentFrame:ToObjectSpace(frames[source]))
			end
			local folders = {}
			local function folderOf(instance)
				if folders[instance] then
					return folders[instance]
				end
				local folder = Instance.new("Folder")
				folder.Name = instance.Name
				folders[instance] = folder
				folder.Parent = if instance == rootPart
					then native
					elseif instance:IsA("Bone") then folderOf(instance.Parent)
					else folderOf(motors[instance].Part0)
				return folder
			end
			local modes = {
				STEP = Enum.KeyInterpolationMode.Constant,
				LINEAR = Enum.KeyInterpolationMode.Linear,
				CUBICSPLINE = Enum.KeyInterpolationMode.Cubic,
			}
			local function checkKeys(expected, actual)
				assert(#actual == #expected, "native key times collide at Studio's clock resolution")
				for i, key in actual do
					if math.abs(key.Time - expected[i].Time) > 1e-6 then
						quantized = true
					end
				end
			end

			local function vectorCurve(parent, keys)
				local curve = Instance.new("Vector3Curve")
				curve.Name, curve.Parent = "Position", parent
				for axis, floatCurve in { curve:X(), curve:Y(), curve:Z() } do
					floatCurve:SetKeys(keys[axis])
					checkKeys(keys[axis], floatCurve:GetKeys())
				end
			end
			local function rotationCurve(parent, keys)
				local curve = Instance.new("RotationCurve")
				curve.Name, curve.Parent = "Rotation", parent
				-- Studio currently rejects RotationCurveKey arrays in SetKeys
				-- (Variant cast failed); InsertKey accepts the same keys.
				for _, key in keys do
					curve:InsertKey(key)
				end
				checkKeys(keys, curve:GetKeys())
			end
			local function exactCurve(instance, source, channel)
				local rotation = channel.path == "rotation"
				local count = if rotation then 4 else 3
				local cubic = channel.interpolation == "CUBICSPLINE"
				local stride = count * (if cubic then 3 else 1)
				local function values(key, section)
					local out = {}
					for i = 1, count do
						out[i] = channel.values[(key - 1) * stride + (if cubic then section * count else 0) + i]
					end
					return out
				end
				local function transform(value)
					return poseFrame(instance, source, framesAt(nil, channel, value))
				end
				local keys = if rotation then {} else { {}, {}, {} }
				for i, time in channel.times do
					local value = values(i, 1)
					local frame = transform(value)
					if rotation then
						table.insert(keys, RotationCurveKey.new(time, frame, modes[channel.interpolation]))
					else
						local left, right
						if cubic then
							local a, b = values(i, 0), values(i, 2)
							for j = 1, 3 do
								a[j] += value[j]
								b[j] += value[j]
							end
							-- Translation is affine under a fixed joint frame. Its
							-- linear part maps glTF tangents in units per second.
							left = transform(a).Position - frame.Position
							right = transform(b).Position - frame.Position
						end
						for axis, component in { "X", "Y", "Z" } do
							local key = FloatCurveKey.new(time, frame.Position[component], modes[channel.interpolation])
							if cubic then
								key.LeftTangent = left[component]
								key.RightTangent = right[component]
							end
							table.insert(keys[axis], key)
						end
					end
				end
				if rotation then
					rotationCurve(folderOf(instance), keys)
				else
					vectorCurve(folderOf(instance), keys)
				end
			end
			local function adaptiveCurves(instance, source, position, rotation)
				approximated = true
				local function sample(time)
					return poseFrame(instance, source, framesAt(time))
				end
				local times, steps = { [0] = true }, {}
				for _, channel in clip.channels do
					if channel.path == "translation" or channel.path == "rotation" then
						for _, time in channel.times do
							times[time] = true
							if channel.interpolation == "STEP" and time > 0 then
								times[math.max(0, time - 1 / 1200)] = true
								steps[time] = true
							end
						end
					end
				end
				local ordered = {}
				for time in times do
					table.insert(ordered, time)
				end
				table.sort(ordered)
				local samples = { { time = ordered[1], frame = sample(ordered[1]) } }
				local function refine(a, b, fa, fb, depth)
					-- Native keys use a 1/2400-second clock. An epsilon key
					-- would merge with the jump and turn STEP into a ramp.
					if steps[b] and b - a <= 1 / 1200 + 1e-7 then
						samples[#samples].step = true
						table.insert(samples, { time = b, frame = fb })
						return
					end
					local accurate = true
					for _, t in { 0.25, 0.5, 0.75 } do
						local expected = sample(a + (b - a) * t)
						local actual = fa:Lerp(fb, t)
						local _, angle = actual:ToObjectSpace(expected):ToAxisAngle()
						if
							(position and (actual.Position - expected.Position).Magnitude > 1e-4)
							or (rotation and math.abs(angle) > 1e-4)
						then
							accurate = false
							break
						end
					end
					if accurate or b - a <= 1e-6 then
						table.insert(samples, { time = b, frame = fb })
						return
					end
					assert(depth < 14, "native curve approximation exceeded its refinement limit")
					local m = math.round((a + b) * 0.5 * 2400) / 2400
					if m <= a or m >= b then
						quantized = true
						table.insert(samples, { time = b, frame = fb })
						return
					end
					local fm = sample(m)
					refine(a, m, fa, fm, depth + 1)
					refine(m, b, fm, fb, depth + 1)
				end
				for i = 2, #ordered do
					refine(ordered[i - 1], ordered[i], samples[#samples].frame, sample(ordered[i]), 0)
				end
				-- Evaluate at the engine's actual key times. Adaptive samples
				-- closer than one clock tick cannot be distinct native keys.
				local clockSamples = {}
				for _, record in samples do
					local time = math.round(record.time * 2400) / 2400
					if math.abs(time - record.time) > 1e-6 then
						quantized = true
					end
					local last = clockSamples[#clockSamples]
					local entry = { time = time, frame = sample(time), step = record.step }
					if last and last.time == time then
						entry.step = entry.step or last.step
						clockSamples[#clockSamples] = entry
					else
						table.insert(clockSamples, entry)
					end
				end
				samples = clockSamples

				local positions, rotations = { {}, {}, {} }, {}
				for _, record in samples do
					if position then
						for axis, component in { "X", "Y", "Z" } do
							table.insert(
								positions[axis],
								FloatCurveKey.new(
									record.time,
									record.frame.Position[component],
									if record.step
										then Enum.KeyInterpolationMode.Constant
										else Enum.KeyInterpolationMode.Linear
								)
							)
						end
					end
					if rotation then
						table.insert(
							rotations,
							RotationCurveKey.new(
								record.time,
								record.frame,
								if record.step
									then Enum.KeyInterpolationMode.Constant
									else Enum.KeyInterpolationMode.Linear
							)
						)
					end
				end
				if position then
					vectorCurve(folderOf(instance), positions)
				end
				if rotation then
					rotationCurve(folderOf(instance), rotations)
				end
			end
			local function convert(instance, source, direct)
				local sourceChannels = channels[source] or {}
				if direct and uniformAncestors(source) then
					if sourceChannels.translation then
						exactCurve(instance, source, sourceChannels.translation)
					end
					local rotation = sourceChannels.rotation
					if rotation then
						if rotation.interpolation == "CUBICSPLINE" then
							adaptiveCurves(instance, source, false, true)
						else
							exactCurve(instance, source, rotation)
						end
					end
				else
					adaptiveCurves(instance, source, true, true)
				end
			end
			for i, part in anchors do
				if animated[i] then
					convert(part, i, true)
				end
			end
			for bone, source in boneSources do
				local meshPart = bone:FindFirstAncestorWhichIsA("MeshPart")
				if affected(source) or affected(partNodes[meshPart]) then
					local parent = bone.Parent
					local parentSource = if parent:IsA("Bone") then boneSources[parent] else partNodes[parent]
					convert(
						bone,
						source,
						relativeStatic(parentOf[source], parentSource) and uniformAncestors(parentSource)
					)
				end
			end
			local animationId = game:GetService("AnimationClipProvider"):RegisterAnimationClip(native)
			local animation = helper("Animation", clip.name, clips)
			animation.AnimationId = animationId
			native.Parent = animation
			clip.clip, clip.animation = native, animation
		end, debug.traceback)
		if not ok then
			native:Destroy()
			table.insert(
				scene.warnings,
				`animation {clip.name}: native playback unavailable: {tostring(err)}; original channels retained`
			)
		elseif approximated then
			table.insert(
				scene.warnings,
				"native playback approximates quaternion cubic or composed transforms with adaptive linear curves; original interpolation retained for export"
			)
		end
		if ok and quantized then
			table.insert(
				scene.warnings,
				"native playback key times were quantized to Studio's clock; original timestamps retained for export"
			)
		end
	end
end

return motion
