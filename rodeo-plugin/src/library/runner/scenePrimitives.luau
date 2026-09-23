-- Unit geometry in Roblox part-local axes. Surface detail on curved primitives
-- is a tessellation approximation; part Size applies the final axis scaling.
local V = Vector3.new
local function kind(part)
	local legacy = part:FindFirstChildWhichIsA("DataModelMesh")
	if legacy then
		local shape = if legacy:IsA("BlockMesh")
			then "Block"
			elseif legacy:IsA("CylinderMesh") then "Cylinder"
			elseif legacy:IsA("SpecialMesh") then (
				{ Brick = "Block", Sphere = "Ball", Cylinder = "Cylinder", Wedge = "Wedge" }
			)[legacy.MeshType.Name]
			else nil
		assert(shape, `{part:GetFullName()}: unsupported legacy mesh; convert it to a MeshPart`)
		assert(
			legacy.Scale.X > 0 and legacy.Scale.Y > 0 and legacy.Scale.Z > 0,
			"reflected legacy meshes require baking first"
		)
		return shape, legacy
	end
	if part:IsA("Part") then
		return part.Shape.Name
	end
	if part:IsA("WedgePart") then
		return "Wedge"
	end
	if part:IsA("CornerWedgePart") then
		return "CornerWedge"
	end
	error(`{part:GetFullName()}: unsupported geometry {part.ClassName}; convert it to a MeshPart`)
end
local function create(shape)
	local mesh = assert(game:GetService("AssetService"):CreateEditableMesh(), "editable mesh memory exhausted")
	local function polygon(points)
		-- Each convex solid contains the origin; orient faces outwards.
		local n = (points[2] - points[1]):Cross(points[3] - points[1]).Unit
		local center = Vector3.zero
		for _, point in points do
			center += point
		end
		if n:Dot(center) < 0 then
			local reversed = {}
			for i = #points, 1, -1 do
				table.insert(reversed, points[i])
			end
			points, n = reversed, -n
		end
		local normal, ids = mesh:AddNormal(n), {}
		for _, point in points do
			table.insert(ids, mesh:AddVertex(point))
		end
		for i = 2, #ids - 1 do
			local face = mesh:AddTriangle(ids[1], ids[i], ids[i + 1])
			mesh:SetFaceNormals(face, { normal, normal, normal })
		end
	end
	local function vertex(point, normal)
		return { mesh:AddVertex(point), mesh:AddNormal(normal) }
	end
	local function triangle(a, b, c)
		local pa, pb, pc = mesh:GetPosition(a[1]), mesh:GetPosition(b[1]), mesh:GetPosition(c[1])
		if (pb - pa):Cross(pc - pa):Dot(pa + pb + pc) < 0 then
			b, c = c, b
		end
		local face = mesh:AddTriangle(a[1], b[1], c[1])
		mesh:SetFaceNormals(face, { a[2], b[2], c[2] })
	end
	local h, segments, rings = 0.5, 24, 16
	if shape == "Ball" then
		local top, bottom = vertex(V(0, h, 0), Vector3.yAxis), vertex(V(0, -h, 0), -Vector3.yAxis)
		local rows = {}
		for i = 1, rings - 1 do
			local row, phi = {}, math.pi * i / rings
			for j = 0, segments - 1 do
				local theta = 2 * math.pi * j / segments
				local normal = V(math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta))
				table.insert(row, vertex(normal * h, normal))
			end
			table.insert(rows, row)
		end
		for j = 1, segments do
			local k = j % segments + 1
			triangle(top, rows[1][j], rows[1][k])
			triangle(bottom, rows[#rows][j], rows[#rows][k])
			for i = 1, #rows - 1 do
				triangle(rows[i][j], rows[i + 1][j], rows[i][k])
				triangle(rows[i][k], rows[i + 1][j], rows[i + 1][k])
			end
		end
	elseif shape == "Cylinder" then
		local left, right = {}, {}
		for j = 0, segments - 1 do
			local angle = 2 * math.pi * j / segments
			local normal = V(0, math.cos(angle), math.sin(angle))
			table.insert(left, vertex(V(-h, normal.Y * h, normal.Z * h), normal))
			table.insert(right, vertex(V(h, normal.Y * h, normal.Z * h), normal))
		end
		for j = 1, segments do
			local k = j % segments + 1
			triangle(left[j], right[j], left[k])
			triangle(left[k], right[j], right[k])
		end
		for _, x in { -h, h } do
			local points = {}
			for j = 0, segments - 1 do
				local a = 2 * math.pi * j / segments
				table.insert(points, V(x, h * math.cos(a), h * math.sin(a)))
			end
			polygon(points)
		end
	else
		local a, b, c, d = V(-h, -h, -h), V(h, -h, -h), V(h, -h, h), V(-h, -h, h)
		local e, f, g, k = V(-h, h, -h), V(h, h, -h), V(h, h, h), V(-h, h, h)
		local faces
		if shape == "Block" then
			faces = { { a, b, c, d }, { e, k, g, f }, { a, e, f, b }, { d, c, g, k }, { a, d, k, e }, { b, f, g, c } }
		elseif shape == "Wedge" then
			faces = { { a, b, c, d }, { d, c, g, k }, { a, k, g, b }, { a, d, k }, { b, g, c } }
		elseif shape == "CornerWedge" then
			faces = { { a, b, c, d }, { b, f, c }, { a, f, b }, { a, d, f }, { d, c, f } }
		else
			error(`unsupported primitive {shape}`)
		end
		for _, points in faces do
			polygon(points)
		end
	end
	return mesh
end
return { kind = kind, create = create }
