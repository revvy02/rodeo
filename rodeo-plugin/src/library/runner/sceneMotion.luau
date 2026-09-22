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

function motion.importMorph(mesh, attributes, info, weights)
	local result = { mesh = mesh, targets = {}, _offsets = {}, _normals = {}, _posedNormals = {} }
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
	-- Render the node's initial morph pose. Export subtracts only this applied
	-- offset, so subsequent live position edits still change the base geometry.
	for i, target in result.targets do
		local weight = weights[i]
		for id, delta in target.positions or {} do
			result._offsets[id] = (result._offsets[id] or Vector3.zero) + delta * weight
		end
	end
	for id, offset in result._offsets do
		mesh:SetPosition(id, mesh:GetPosition(id) + offset)
	end
	for _, id in attributes.normals do
		local base = mesh:GetNormal(id)
		local normal = base
		for i, target in result.targets do
			normal += ((target.normals and target.normals[id]) or Vector3.zero) * weights[i]
		end
		if normal.Magnitude > 1e-8 then
			normal = normal.Unit
		end
		result._normals[id], result._posedNormals[id] = base, normal
		mesh:SetNormal(id, normal)
	end
	return result
end

function motion.baseOverrides(morph)
	local result = { positions = {}, normals = {} }
	for _, id in morph.mesh:GetVertices() do
		result.positions[id] = morph.mesh:GetPosition(id) - ((morph._offsets and morph._offsets[id]) or Vector3.zero)
	end
	for _, id in morph.mesh:GetNormals() do
		-- Keep the authored normal when the preview is unchanged. An explicitly
		-- edited normal becomes the new base normal (normalization is not invertible).
		local current = morph.mesh:GetNormal(id)
		if morph._posedNormals and current == morph._posedNormals[id] then
			result.normals[id] = morph._normals[id]
		end
	end
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
		local clip = { name = animation.name, sourceIndex = animation.sourceIndex, channels = {} }
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

function motion.buildRig(scene, document, nodes, own, sampleRate)
	assert(
		type(sampleRate) == "number" and sampleRate > 0 and sampleRate <= 240,
		"animationSampleRate must be between 0 and 240"
	)
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
	local rig = own(Instance.new("Model"))
	rig.Name = "Scene"
	rig:SetAttribute("RodeoSceneRig", true)
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
		local frame = node:GetPivot()
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
	for _, root in scene.roots do
		root.Parent = rig
	end
	scene.roots = { rig }
	scene.animationRig, scene.animator = rig, animator
	local boneSources = {}
	for source, bindings in scene.sourceMap.joints do
		for _, binding in bindings do
			boneSources[binding.bone] = indexOf[scene.sourceMap.nodes[source]]
		end
	end
	for _, clip in scene.animations do
		local animated = {}
		for _, channel in clip.channels do
			if channel.path == "translation" or channel.path == "rotation" then
				animated[indexOf[channel.node]] = true
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
		local sequence = own(Instance.new("KeyframeSequence"))
		sequence.Name, sequence.Loop = clip.name, false
		local duration, times = 0, { [0] = true }
		for _, channel in clip.channels do
			duration = math.max(duration, channel.times[#channel.times])
			for _, t in channel.times do
				times[t] = true
				if channel.interpolation == "STEP" and t > 0 then
					times[math.max(0, t - 0.00001)] = true
				end
			end
		end
		for step = 0, math.ceil(duration * sampleRate) do
			times[math.min(duration, step / sampleRate)] = true
		end
		local ordered = {}
		for time in times do
			table.insert(ordered, time)
		end
		table.sort(ordered)
		local ok, err = pcall(function()
			for _, time in ordered do
				local localTrs, worlds, frames = {}, {}, {}
				for i, node in document.nodes do
					localTrs[i] = table.clone(node.rest)
				end
				for _, channel in clip.channels do
					-- Native Animator cannot scale parts or drive arbitrary vertex
					-- deltas. Keep those channels exact in clip.channels and warn.
					if channel.path == "translation" or channel.path == "rotation" then
						localTrs[indexOf[channel.node]][channel.path] =
							motion.sample(channel, time, if channel.path == "rotation" then 4 else 3)
					end
				end
				-- Document order is parent-first, established by the host traversal.
				for i, trs in localTrs do
					worlds[i] = multiply(if parentOf[i] then worlds[parentOf[i]] else identity, trsMatrix(trs))
					frames[i] = rigid(worlds[i])
				end
				local key = Instance.new("Keyframe")
				key.Time = time
				key.Parent = sequence
				local poses = {}
				local function poseOf(instance)
					if poses[instance] then
						return poses[instance]
					end
					local pose = Instance.new("Pose")
					pose.Name = instance.Name
					pose.Weight = 0
					pose.EasingStyle = Enum.PoseEasingStyle.Linear
					poses[instance] = pose
					pose.Parent = if instance == rootPart
						then key
						elseif instance:IsA("Bone") then poseOf(instance.Parent)
						else poseOf(motors[instance].Part0)
					return pose
				end
				for i, part in anchors do
					-- Unrelated channels must remain unweighted so independent clips
					-- can play together without resetting each other's joints.
					if not animated[i] then
						continue
					end
					local parentFrame = if parentOf[i] then frames[parentOf[i]] else CFrame.identity
					local pose = poseOf(part)
					pose.CFrame = motors[part].C0:ToObjectSpace(parentFrame:ToObjectSpace(frames[i]))
					pose.Weight = 1
				end
				for bone, source in boneSources do
					local meshPart = bone:FindFirstAncestorWhichIsA("MeshPart")
					if not affected(source) and not affected(partNodes[meshPart]) then
						continue
					end
					local parent = bone.Parent
					local parentFrame = if parent:IsA("Bone")
						then frames[boneSources[parent]]
						else frames[partNodes[parent]] * partOffsets[parent]
					local pose = poseOf(bone)
					pose.CFrame = bone.CFrame:ToObjectSpace(parentFrame:ToObjectSpace(frames[source]))
					pose.Weight = 1
				end
			end
			local animation = helper("Animation", clip.name, clips)
			animation.AnimationId = game:GetService("AnimationClipProvider"):RegisterAnimationClip(sequence)
			sequence.Parent = animation
			clip.sequence, clip.animation = sequence, animation
		end)
		if not ok then
			sequence:Destroy()
			table.insert(
				scene.warnings,
				`animation {clip.name}: native preview unavailable: {tostring(err)}; original channels retained`
			)
		else
			table.insert(
				scene.warnings,
				`animation {clip.name}: Roblox preview sampled at {sampleRate} Hz; original interpolation retained for export`
			)
		end
	end
end

return motion
