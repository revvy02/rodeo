-- Bake native clips through Roblox's evaluator. A private clone prevents
-- export from stopping tracks or changing the caller's current pose.
local function frame(instance)
	return if instance:IsA("Bone") then instance.WorldCFrame else instance:GetPivot()
end

local function quaternion(cf)
	local axis, angle = cf:ToAxisAngle()
	local sine = math.sin(angle / 2)
	return { axis.X * sine, axis.Y * sine, axis.Z * sine, math.cos(angle / 2) }
end

local function clipTimes(clip, rate)
	local times, duration = { [0] = true }, 0
	for _, child in clip:GetDescendants() do
		if child:IsA("Keyframe") then
			times[child.Time] = true
			duration = math.max(duration, child.Time)
		elseif child:IsA("FloatCurve") or child:IsA("RotationCurve") then
			for _, key in child:GetKeys() do
				times[key.Time] = true
				duration = math.max(duration, key.Time)
			end
		elseif child:IsA("NumberPose") then
			error("native animation export does not support NumberPose/facial tracks")
		end
	end
	for i = 1, math.ceil(duration * rate) - 1 do
		times[i / rate] = true
	end
	times[duration] = true
	local ordered = {}
	for time in times do
		assert(time >= 0 and time < math.huge, "animation times must be finite and nonnegative")
		table.insert(ordered, time)
	end
	table.sort(ordered)
	return ordered, duration
end

local function cloneMap(source, clone, map)
	map[source] = clone
	local a, b = source:GetChildren(), clone:GetChildren()
	assert(#a == #b, "native animation export requires an Archivable rig and descendants")
	for i, child in a do
		assert(child.ClassName == b[i].ClassName and child.Name == b[i].Name, "rig clone hierarchy differs")
		cloneMap(child, b[i], map)
	end
end

return function(document, seen, skinBindings, clips, rate, matrix, warning)
	assert(rate > 0 and rate <= 1000, "animationSampleRate must be between 0 and 1000")
	local parents, original = {}, {}
	for i, node in document.nodes do
		original[i - 1] = CFrame.new(unpack(node.transform))
		for _, child in node.children do
			parents[child] = i - 1
		end
	end
	local function ensure(instance)
		local index = seen[instance]
		if index ~= nil then
			return index
		end
		local parent = instance.Parent
		while parent and seen[parent] == nil and not parent:IsA("Bone") and not parent:IsA("BasePart") do
			parent = parent.Parent
		end
		assert(parent, `animation target {instance:GetFullName()} is outside the exported roots`)
		local parentIndex = ensure(parent)
		index = #document.nodes
		seen[instance], parents[index] = index, parentIndex
		original[index] = frame(instance)
		table.insert(document.nodes, { name = instance.Name, children = {}, parts = {} })
		return index
	end
	local driven, contexts = {}, {}
	for _, entry in clips do
		local rig, clip = entry.rig, entry.clip
		assert(rig:IsA("Model") and seen[rig] ~= nil, "animationClips.rig must be an exported Model")
		assert(
			clip:IsA("KeyframeSequence") or clip:IsA("CurveAnimation"),
			"animationClips.clip must be a KeyframeSequence or CurveAnimation"
		)
		if contexts[rig] then
			continue
		end
		local joints = {}
		contexts[rig] = joints
		local function add(child, parent, driver, before, after)
			assert(child:IsDescendantOf(rig) and parent:IsDescendantOf(rig), "animation joint crosses the rig boundary")
			local index, parentIndex = ensure(child), ensure(parent)
			assert(not driven[index], `multiple animation joints drive {child:GetFullName()}`)
			local record = { index = index, driver = driver, before = before, after = after }
			driven[index], parents[index] = record, parentIndex
			table.insert(joints, record)
		end
		for _, child in rig:GetDescendants() do
			if child:IsA("Motor6D") or child:IsA("Weld") then
				if child.Enabled and child.Part0 and child.Part1 then
					add(
						child.Part1,
						child.Part0,
						if child:IsA("Motor6D") then child else nil,
						child.Part0.PivotOffset:Inverse() * child.C0,
						child.C1:Inverse() * child.Part1.PivotOffset
					)
				end
			elseif child:IsA("AnimationConstraint") then
				if child.Enabled and child.Attachment0 and child.Attachment1 then
					assert(child.IsKinematic, "non-kinematic AnimationConstraint physics cannot be exported as a clip")
					local a, b = child.Attachment0, child.Attachment1
					assert(
						a.Parent:IsA("BasePart") and b.Parent:IsA("BasePart"),
						"animation attachments must belong to BaseParts"
					)
					add(
						b.Parent,
						a.Parent,
						child,
						a.Parent.PivotOffset:Inverse() * a.CFrame,
						b.CFrame:Inverse() * b.Parent.PivotOffset
					)
				end
			elseif child:IsA("WeldConstraint") then
				if child.Enabled and child.Part0 and child.Part1 then
					add(
						child.Part1,
						child.Part0,
						nil,
						frame(child.Part0):ToObjectSpace(frame(child.Part1)),
						CFrame.identity
					)
				end
			elseif child:IsA("Bone") then
				assert(
					child.Parent:IsA("Bone") or child.Parent:IsA("BasePart"),
					"animated Bones must belong to a Bone or BasePart"
				)
				local pivot = if child.Parent:IsA("BasePart")
					then child.Parent.PivotOffset:Inverse()
					else CFrame.identity
				add(child, child.Parent, child, pivot * child.CFrame, CFrame.identity)
			end
		end
		assert(#joints > 0, `animation rig {rig.Name} has no supported joints`)
	end
	-- Convert the Instance tree to the mechanical joint tree. Non-joint children
	-- retain their original parent-local frame (attachments, geometry, folders).
	local worlds, visiting = {}, {}
	local function world(index)
		if worlds[index] then
			return worlds[index]
		end
		assert(not visiting[index], "animation rig contains a joint cycle")
		visiting[index] = true
		local parent, record = parents[index], driven[index]
		local localFrame = if record
			then record.before * record.after
			elseif parent ~= nil then original[parent]:ToObjectSpace(original[index])
			else original[index]
		local result = if parent ~= nil then world(parent) * localFrame else localFrame
		worlds[index], visiting[index] = result, nil
		return result
	end
	document.roots = {}
	for i, node in document.nodes do
		local cf = world(i - 1)
		node.transform, node.world, node.children = { cf:GetComponents() }, matrix(cf, Vector3.one), {}
		assert(
			not node.localScale or Vector3.new(unpack(node.localScale)) == Vector3.one,
			"native animation export requires unscaled rig frames"
		)
	end
	for i in document.nodes do
		local parent = parents[i - 1]
		table.insert(if parent ~= nil then document.nodes[parent + 1].children else document.roots, i - 1)
	end
	for _, record in skinBindings do
		local nodes = {}
		for _, bone in record.bones do
			if not bone or seen[bone] == nil then
				break
			end
			table.insert(nodes, seen[bone])
		end
		for rig in contexts do
			if record.part:IsDescendantOf(rig) then
				assert(#nodes == #record.bones, "native clip export requires a live Bone for every mesh bone")
			end
		end
		if #nodes == #record.bones then
			record.binding.jointNodes = nodes
		end
	end
	document.animations = document.animations or {}
	for _, entry in clips do
		local rig, clip = entry.rig, entry.clip
		local times, duration = clipTimes(clip, rate)

		warning(
			clip,
			`native clip {clip.Name} is baked as full rig poses at {rate} Hz plus source key times; interpolation between samples approximates Roblox easing`
		)
		local clone = assert(rig:Clone(), "native animation export requires an Archivable rig")
		local animation, track, playable
		local ok, result = pcall(function()
			local map = {}
			cloneMap(rig, clone, map)
			for _, child in clone:GetDescendants() do
				if child:IsA("BaseScript") then
					child.Enabled = false
				end
				if child:IsA("BasePart") then
					child.Anchored = true
				end
				if child:IsA("Animator") then
					child:Destroy()
				end
				if child:IsA("Motor6D") or child:IsA("Bone") or child:IsA("AnimationConstraint") then
					child.Transform = CFrame.identity
				end
			end
			clone.Parent = workspace
			local controller = clone:FindFirstChildOfClass("Humanoid")
				or clone:FindFirstChildOfClass("AnimationController")
			if not controller then
				controller = Instance.new("AnimationController")
				controller.Parent = clone
			end
			local animator = Instance.new("Animator")
			animator.Parent = controller
			animation = Instance.new("Animation")
			-- A zero-duration clip is a static pose. Extend a private copy so
			-- Animator can load it, while exporting only its original t=0 key.
			playable = assert(clip:Clone(), "native animation export requires an Archivable clip")
			if duration == 0 then
				local extended = false
				for _, child in playable:GetDescendants() do
					if child:IsA("Keyframe") then
						local key = child:Clone()
						key.Time = 1
						key.Parent = playable
						extended = true
					elseif child:IsA("FloatCurve") or child:IsA("RotationCurve") then
						local keys = child:GetKeys()
						if #keys > 0 then
							local key = if child:IsA("FloatCurve")
								then FloatCurveKey.new(1, keys[#keys].Value, Enum.KeyInterpolationMode.Constant)
								else RotationCurveKey.new(1, keys[#keys].Value, Enum.KeyInterpolationMode.Constant)
							child:InsertKey(key)
							extended = true
						end
					end
				end
				assert(extended, "native animation clip has no keys")
			end
			animation.AnimationId = game:GetService("AnimationClipProvider"):RegisterAnimationClip(playable)
			track = animator:LoadAnimation(animation)
			track.Looped = false
			track:Play(0, 1, 0)
			local deadline = os.clock() + 10
			while track.Length == 0 and os.clock() < deadline do
				task.wait()
			end
			assert(track.Length > 0, "native animation did not load within 10 seconds")
			local channels, joints = {}, contexts[rig]
			for _, joint in joints do
				if joint.driver then
					for _, path in { "translation", "rotation" } do
						table.insert(
							channels,
							{ node = joint.index, path = path, interpolation = "LINEAR", times = times, values = {} }
						)
					end
				end
			end
			local lastYield = os.clock()
			for _, time in times do
				if not track.IsPlaying then
					track:Play(0, 1, 0)
				end
				track.TimePosition = time
				animator:StepAnimations(0)
				local channel = 1
				for _, joint in joints do
					if not joint.driver then
						continue
					end
					local pose = joint.before * map[joint.driver].Transform * joint.after
					for _, value in { pose.X, pose.Y, pose.Z } do
						table.insert(channels[channel].values, value)
					end
					for _, value in quaternion(pose) do
						table.insert(channels[channel + 1].values, value)
					end
					channel += 2
				end
				if os.clock() - lastYield > 0.05 then
					task.wait()
					lastYield = os.clock()
				end
			end
			-- Full-pose baking keys unanimated joints too. Keep constant
			-- channels compact without shortening the clip.
			for _, channel in channels do
				local width = if channel.path == "rotation" then 4 else 3
				local constant = true
				for i = width + 1, #channel.values do
					if channel.values[i] ~= channel.values[(i - 1) % width + 1] then
						constant = false
						break
					end
				end
				if constant and #times > 2 then
					channel.times = { 0, duration }
					local values = {}
					for i = 1, width * 2 do
						table.insert(values, channel.values[(i - 1) % width + 1])
					end
					channel.values = values
				end
			end
			local markers, keyframes = {}, {}
			for _, child in clip:GetDescendants() do
				if child:IsA("KeyframeMarker") then
					table.insert(markers, { time = child.Parent.Time, name = child.Name, value = child.Value })
				elseif child:IsA("Keyframe") and child.Name ~= "Keyframe" then
					table.insert(keyframes, { time = child.Time, name = child.Name })
				end
			end
			table.sort(markers, function(a, b)
				return a.time < b.time
			end)
			table.sort(keyframes, function(a, b)
				return a.time < b.time
			end)
			table.insert(document.animations, {
				name = clip.Name,
				channels = channels,
				metadata = {
					loop = clip.Loop,
					priority = clip.Priority.Name,
					sampleRate = rate,
					markers = if #markers > 0 then markers else nil,
					keyframes = if #keyframes > 0 then keyframes else nil,
				},
			})
		end)
		if track then
			track:Destroy()
		end
		if animation then
			animation:Destroy()
		end
		if playable then
			playable:Destroy()
		end
		clone:Destroy()
		if not ok then
			error(result, 0)
		end
	end
end
