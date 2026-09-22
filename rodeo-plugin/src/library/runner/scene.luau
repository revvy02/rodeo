-- Scene assembly is separate from mesh/image codecs. All objects created by
-- import are caller-owned; failures destroy the entire partial result.
return function(roblox, rpc, fs, stream, runtime, meshToBlob, meshFromBlob)
	local AssetService = game:GetService("AssetService")
	local HttpService = game:GetService("HttpService")
	local mapProperties = {
		color = "ColorMapContent",
		normal = "NormalMapContent",
		roughness = "RoughnessMapContent",
		metalness = "MetalnessMapContent",
	}
	local nextId = 0
	local function cframe(values)
		return CFrame.new(unpack(values))
	end
	local function components(cf)
		return { cf:GetComponents() }
	end
	local function checkPath(path)
		local lower = string.lower(path)
		assert(
			string.sub(lower, -4) == ".glb" or string.sub(lower, -5) == ".gltf",
			"editable scenes require .gltf or .glb"
		)
	end
	local function matrix(cf, scale)
		local p, x, y, z = cf.Position, cf.XVector * scale.X, cf.YVector * scale.Y, cf.ZVector * scale.Z
		return { { x.X, x.Y, x.Z, 0 }, { y.X, y.Y, y.Z, 0 }, { z.X, z.Y, z.Z, 0 }, { p.X, p.Y, p.Z, 1 } }
	end
	local function decompose(m)
		local x = Vector3.new(unpack(m[1]))
		local y = Vector3.new(unpack(m[2]))
		local z = Vector3.new(unpack(m[3]))
		local scale = Vector3.new(x.Magnitude, y.Magnitude, z.Magnitude)
		return CFrame.fromMatrix(Vector3.new(unpack(m[4])), x.Unit, y.Unit, z.Unit), scale
	end
	local function cleanup(objects)
		for i = #objects, 1, -1 do
			objects[i]:Destroy()
		end
	end
	local function listAt(map, key, value)
		if key ~= nil then
			local list = map[key] or {}
			map[key] = list
			table.insert(list, value)
		end
	end

	function roblox.importEditableScene(path)
		checkPath(path)
		nextId += 1
		local handle = { __handle = `scene:{nextId}:{path}` }
		rpc.call("roblox_scene_decode", runtime.RobloxSceneDecodeRequest.new({ path = path, handle = handle.__handle }))
		local bytes = stream.readBytes(handle)
		stream.close(handle)
		local offset = 0
		local function chunk()
			local size = buffer.readu32(bytes, offset)
			offset += 4
			local result = buffer.create(size)
			buffer.copy(result, 0, bytes, offset, size)
			offset += size
			return result
		end
		local document = HttpService:JSONDecode(buffer.tostring(chunk()))
		local scene = {
			roots = {},
			meshes = {},
			images = {},
			warnings = document.warnings,
			sourceMap = { nodes = {}, primitives = {}, materials = {}, images = {}, joints = {} },
		}
		local owned = {}
		local function own(object)
			table.insert(owned, object)
			return object
		end
		local ok, result = pcall(function()
			local boneIds = {}
			for i in document.meshes do
				local mesh, ids = meshFromBlob(chunk(), path)
				scene.meshes[i], boneIds[i] = own(mesh), ids
			end
			for i, info in document.images do
				local image = own(
					assert(
						AssetService:CreateEditableImage({ Size = Vector2.new(info.width, info.height) }),
						`image {i}: editable image memory exhausted`
					)
				)
				image:WritePixelsBuffer(Vector2.zero, image.Size, chunk())
				scene.images[i] = image
				listAt(scene.sourceMap.images, info.sourceIndex, image)
			end
			assert(offset == buffer.len(bytes), "scene packet contains trailing data")
			local nodes = {}
			local jointToken = HttpService:GenerateGUID(false)
			local jointSources = {}
			for _, info in document.meshes do
				for _, source in info.jointNodes do
					jointSources[source] = true
				end
			end
			for i, node in document.nodes do
				local nodeFrame = cframe(node.transform)
				local nodeInstance
				if #node.parts ~= 1 then
					nodeInstance = own(Instance.new("Model"))
					nodeInstance.WorldPivot = nodeFrame
				end
				for _, binding in node.parts do
					local meshIndex = binding.mesh + 1
					local mesh = scene.meshes[meshIndex]
					local info = document.meshes[meshIndex]
					local localFrame, scale = decompose(binding.matrix)
					local center = mesh:GetCenter()
					local origin = nodeFrame * localFrame
					local part = own(
						AssetService:CreateMeshPartAsync(
							Content.fromObject(mesh),
							{ CollisionFidelity = Enum.CollisionFidelity.Box }
						)
					)
					part.Name = if #node.parts == 1 then node.name else `Primitive{info.primitiveIndex or 0}`
					part.Anchored = true
					part.Material = Enum.Material.SmoothPlastic
					part.Size *= scale
					part.CFrame = origin * CFrame.new(center * scale)
					part.PivotOffset = part.CFrame:ToObjectSpace(nodeFrame)
					if nodeInstance then
						part.Parent = nodeInstance
					else
						nodeInstance = part
					end
					if binding.material ~= nil then
						local material = document.materials[binding.material + 1]
						local color = Color3.new(material.color[1], material.color[2], material.color[3])
						part.Color = color
						part.Transparency = 1 - material.color[4]
						part.DoubleSided = material.doubleSided
						local appearance = own(Instance.new("SurfaceAppearance"))
						appearance.Name = material.name
						appearance.Color = color
						appearance.AlphaMode = Enum.AlphaMode.Transparency
						for channel, imageIndex in material.maps do
							appearance[mapProperties[channel]] = Content.fromObject(scene.images[imageIndex + 1])
						end
						appearance.Parent = part
						listAt(scene.sourceMap.materials, material.sourceIndex, appearance)
					end
					local bones, binds, poses = {}, {}, {}
					local indexOf = {}
					for j, id in boneIds[meshIndex] do
						indexOf[id] = j
					end
					for j, id in boneIds[meshIndex] do
						local bone = own(Instance.new("Bone"))
						bone.Name = mesh:GetBoneName(id)
						binds[j] = CFrame.new(-center) * mesh:GetBoneCFrame(id)
						poses[j] = if binding.poses[j] then CFrame.new(-center) * cframe(binding.poses[j]) else binds[j]
						local parentIndex = indexOf[mesh:GetBoneParent(id)]
						bone.CFrame = if parentIndex then binds[parentIndex]:ToObjectSpace(binds[j]) else binds[j]
						local pose = if parentIndex then poses[parentIndex]:ToObjectSpace(poses[j]) else poses[j]
						bone.Transform = bone.CFrame:ToObjectSpace(pose)
						bone.Parent = if parentIndex then bones[parentIndex] else part
						bones[j] = bone
						local source = info.jointNodes[j]
						if source ~= nil then
							bone:SetAttribute("RodeoSceneJoint", `{jointToken}:{source}`)
							listAt(
								scene.sourceMap.joints,
								source,
								{ mesh = mesh, boneId = id, bone = bone, part = part }
							)
						end
					end
					table.insert(scene.sourceMap.primitives, {
						nodeIndex = node.sourceIndex,
						meshIndex = info.meshIndex,
						primitiveIndex = info.primitiveIndex,
						skinIndex = info.skinIndex,
						materialIndex = if binding.material ~= nil
							then document.materials[binding.material + 1].sourceIndex
							else nil,
						mesh = mesh,
						part = part,
					})
				end
				nodeInstance.Name = node.name
				if node.sourceIndex ~= nil then
					scene.sourceMap.nodes[node.sourceIndex] = nodeInstance
					if jointSources[node.sourceIndex] then
						nodeInstance:SetAttribute("RodeoSceneJoint", `{jointToken}:{node.sourceIndex}`)
					end
				end
				nodes[i] = nodeInstance
			end
			for i, node in document.nodes do
				for _, child in node.children do
					nodes[child + 1].Parent = nodes[i]
				end
			end
			for _, root in document.roots do
				table.insert(scene.roots, nodes[root + 1])
			end
			return scene
		end)
		if not ok then
			cleanup(owned)
			error(`importEditableScene: {path}: {tostring(result)}`, 2)
		end
		return result
	end

	local function boxMesh(part)
		assert(
			part:IsA("Part") and part.Shape == Enum.PartType.Block,
			`{part:GetFullName()}: unsupported geometry {part.ClassName}; convert it to a MeshPart`
		)
		local mesh = assert(AssetService:CreateEditableMesh(), "editable mesh memory exhausted")
		local vertices = {}
		for _, p in
			{
				Vector3.new(-0.5, -0.5, -0.5),
				Vector3.new(0.5, -0.5, -0.5),
				Vector3.new(0.5, 0.5, -0.5),
				Vector3.new(-0.5, 0.5, -0.5),
				Vector3.new(-0.5, -0.5, 0.5),
				Vector3.new(0.5, -0.5, 0.5),
				Vector3.new(0.5, 0.5, 0.5),
				Vector3.new(-0.5, 0.5, 0.5),
			}
		do
			table.insert(vertices, mesh:AddVertex(p))
		end
		for _, face in
			{ { 1, 4, 3, 2 }, { 5, 6, 7, 8 }, { 1, 5, 8, 4 }, { 2, 3, 7, 6 }, { 1, 2, 6, 5 }, { 4, 8, 7, 3 } }
		do
			local a, b, c =
				mesh:GetPosition(vertices[face[1]]),
				mesh:GetPosition(vertices[face[2]]),
				mesh:GetPosition(vertices[face[3]])
			local normal = mesh:AddNormal((b - a):Cross(c - a).Unit)
			local first = mesh:AddTriangle(vertices[face[1]], vertices[face[2]], vertices[face[3]])
			local second = mesh:AddTriangle(vertices[face[1]], vertices[face[3]], vertices[face[4]])
			mesh:SetFaceNormals(first, { normal, normal, normal })
			mesh:SetFaceNormals(second, { normal, normal, normal })
		end
		return mesh
	end

	function roblox.exportEditableScene(path, roots)
		checkPath(path)
		local document = { roots = {}, nodes = {}, meshes = {}, images = {}, materials = {}, warnings = {} }
		local meshBlobs, imageBlobs, temporary = {}, {}, {}
		local meshIds, imageIds, seen = {}, {}, {}
		local materialIds, loadedMeshes = {}, {}
		local jointNodes, skinBindings = {}, {}
		local function warning(instance, feature)
			table.insert(document.warnings, `{instance:GetFullName()}: {feature}`)
		end
		local function imageFor(content)
			if content.SourceType == Enum.ContentSourceType.None then
				return nil
			end
			local key = if content.SourceType == Enum.ContentSourceType.Object then content.Object else content
			if imageIds[key] ~= nil then
				return imageIds[key]
			end
			local editable
			if content.SourceType == Enum.ContentSourceType.Object then
				editable = content.Object
			else
				editable = assert(AssetService:CreateEditableImageAsync(content), "image memory exhausted")
				table.insert(temporary, editable)
			end
			assert(editable:IsA("EditableImage"), "image content does not reference an EditableImage")
			local id = #document.images
			table.insert(document.images, { width = editable.Size.X, height = editable.Size.Y })
			table.insert(imageBlobs, editable:ReadPixelsBuffer(Vector2.zero, editable.Size))
			imageIds[key] = id
			return id
		end
		local function materialFor(part)
			local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
			local color = if appearance then appearance.Color else part.Color
			local material = {
				name = if appearance then appearance.Name else part.Name,
				color = { color.R, color.G, color.B, 1 - part.Transparency },
				doubleSided = part:IsA("MeshPart") and part.DoubleSided,
				alphaMode = "BLEND",
			}
			local maps = {}
			if appearance then
				for channel, property in mapProperties do
					maps[channel] = imageFor(appearance[property])
				end
				if appearance.AlphaMode == Enum.AlphaMode.Overlay then
					warning(appearance, "Overlay alpha compositing is unsupported; exported as transparency")
				end
				if appearance.EmissiveMaskContent.SourceType ~= Enum.ContentSourceType.None then
					warning(appearance, "emissive channels are unsupported")
				end
			elseif part:IsA("MeshPart") then
				maps.color = imageFor(part.TextureContent)
			end
			if next(maps) then
				material.maps = maps
			end
			if not appearance then
				warning(
					part,
					"native Roblox material shading is approximated with base color and default glTF PBR values"
				)
			elseif maps.roughness == nil then
				warning(appearance, "no roughness map; exported with glTF roughness 1")
			end
			local keyParts =
				{ tostring(color), tostring(part.Transparency), tostring(material.doubleSided), material.alphaMode }
			for _, channel in { "color", "normal", "roughness", "metalness" } do
				table.insert(keyParts, tostring(maps[channel]))
			end
			local key = table.concat(keyParts, "|")
			if materialIds[key] ~= nil then
				return materialIds[key]
			end
			local id = #document.materials
			materialIds[key] = id
			table.insert(document.materials, material)
			return id
		end
		local function geometryFor(part)
			local editable
			if part:IsA("MeshPart") then
				local content = part.MeshContent
				if content.SourceType == Enum.ContentSourceType.Object then
					editable = content.Object
				else
					local key = content
					editable = loadedMeshes[key]
					if not editable then
						editable = assert(
							AssetService:CreateEditableMeshAsync(content),
							`{part:GetFullName()}: mesh memory exhausted`
						)
						loadedMeshes[key] = editable
						table.insert(temporary, editable)
					end
				end
			else
				editable = boxMesh(part)
				table.insert(temporary, editable)
			end
			assert(
				editable:IsA("EditableMesh"),
				`{part:GetFullName()}: mesh content does not reference an EditableMesh`
			)
			local id = meshIds[editable]
			if id == nil then
				id = #document.meshes
				table.insert(document.meshes, { jointNodes = {} })
				table.insert(meshBlobs, meshToBlob(editable))
				meshIds[editable] = id
			end
			local native = if part:IsA("MeshPart") then part.MeshSize else Vector3.one
			local scale = Vector3.new(
				if native.X > 0 then part.Size.X / native.X else 1,
				if native.Y > 0 then part.Size.Y / native.Y else 1,
				if native.Z > 0 then part.Size.Z / native.Z else 1
			)
			local origin = part.CFrame * CFrame.new(-editable:GetCenter() * scale)
			local binding = {
				mesh = id,
				material = materialFor(part),
				matrix = matrix(part:GetPivot():ToObjectSpace(origin), scale),
				poses = {},
			}
			local ids = editable:GetBones()
			if #ids > 0 then
				assert((scale - Vector3.one).Magnitude < 1e-4, `{part:GetFullName()}: scaled skins are unsupported`)
				local bones = {}
				for _, descendant in part:GetDescendants() do
					if descendant:IsA("Bone") and descendant:FindFirstAncestorWhichIsA("MeshPart") == part then
						assert(
							not bones[descendant.Name],
							`{part:GetFullName()}: duplicate Bone name {descendant.Name}`
						)
						bones[descendant.Name] = descendant
					end
				end
				-- Match meshToBlob's parent-first order, which is stable even when
				-- the engine's bone IDs are sparse or returned in another order.
				local present, placed, ordered = {}, {}, {}
				for _, id in ids do
					present[id] = true
				end
				while #ordered < #ids do
					local before = #ordered
					for _, id in ids do
						local parent = editable:GetBoneParent(id)
						if not placed[id] and (not present[parent] or placed[parent]) then
							placed[id] = true
							table.insert(ordered, id)
						end
					end
					assert(#ordered > before, "bone hierarchy contains a cycle")
				end
				local bound = {}
				for _, id in ordered do
					local bone = bones[editable:GetBoneName(id)]
					table.insert(
						binding.poses,
						if bone
							then components(origin:ToObjectSpace(bone.TransformedWorldCFrame))
							else components(editable:GetBoneCFrame(id))
					)
					table.insert(bound, bone or false)
				end
				table.insert(skinBindings, { binding = binding, bones = bound })
			end
			return binding
		end
		local function visit(instance, parentFrame)
			assert(not seen[instance], `exportEditableScene: roots overlap at {instance:GetFullName()}`)
			seen[instance] = true
			local frame = parentFrame
			if instance:IsA("Model") or instance:IsA("BasePart") then
				frame = instance:GetPivot()
			elseif instance:IsA("Attachment") then
				frame = instance.WorldCFrame
			elseif not instance:IsA("Folder") then
				warning(instance, `{instance.ClassName} behavior is unsupported; exported hierarchy only`)
			end
			local index = #document.nodes
			local node = { name = instance.Name, transform = components(frame), children = {}, parts = {} }
			table.insert(document.nodes, node)
			local jointKey = instance:GetAttribute("RodeoSceneJoint")
			if jointKey then
				jointNodes[jointKey] = index
			end
			if instance:IsA("BasePart") then
				table.insert(node.parts, geometryFor(instance))
			end
			for _, child in instance:GetChildren() do
				if child:IsA("SurfaceAppearance") or child:IsA("Bone") then
					continue
				end
				table.insert(node.children, visit(child, frame))
			end
			return index
		end
		local ok, result = pcall(function()
			for _, root in roots do
				table.insert(document.roots, visit(root, CFrame.identity))
			end
			local assignedJointPoses = {}
			for _, record in skinBindings do
				local nodes, poses = {}, {}
				for _, bone in record.bones do
					local key = bone and bone:GetAttribute("RodeoSceneJoint")
					local index = key and jointNodes[key]
					if index == nil then
						break
					end
					local pose = bone.TransformedWorldCFrame
					local assigned = assignedJointPoses[index]
					-- Shared imported skeletons may be edited independently after
					-- cloning a part. Give divergent poses separate glTF joints.
					if
						assigned
						and (
							(assigned.Position - pose.Position).Magnitude > 1e-4
							or assigned.XVector:Dot(pose.XVector) < 0.99999
							or assigned.YVector:Dot(pose.YVector) < 0.99999
						)
					then
						break
					end
					table.insert(nodes, index)
					table.insert(poses, pose)
				end
				if #nodes == #record.bones then
					record.binding.jointNodes = nodes
					for i, index in nodes do
						assignedJointPoses[index] = poses[i]
						document.nodes[index + 1].transform = components(poses[i])
					end
				end
			end

			local chunks = { buffer.fromstring(HttpService:JSONEncode(document)) }
			for _, blob in meshBlobs do
				table.insert(chunks, blob)
			end
			for _, blob in imageBlobs do
				table.insert(chunks, blob)
			end
			local handle = fs.open(path, "w")
			for _, blob in chunks do
				local length = buffer.create(4)
				buffer.writeu32(length, 0, buffer.len(blob))
				stream.writeBytes(handle, length)
				stream.writeBytes(handle, blob)
			end
			rpc.call("roblox_scene_encode", runtime.RobloxSceneEncodeRequest.new({ handle = handle.__handle }))
			return document.warnings
		end)
		cleanup(temporary)
		if not ok then
			error(`exportEditableScene: {path}: {tostring(result)}`, 2)
		end
		return result
	end
end
