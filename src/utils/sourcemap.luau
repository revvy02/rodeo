local fs = require("@lune/fs")
local serde = require("@lune/serde")

local function loadSourcemap(path: string)
	if not fs.isFile(path) then
		return nil, `Sourcemap file not found: {path}`
	end

	local content = fs.readFile(path)
	local success, result = pcall(serde.decode, "json", content)

	if not success then
		return nil, `Failed to parse sourcemap: {result}`
	end

	return result, nil
end

local function findInstancePath(sourcemap: any, filePath: string): string?
	local normalizedPath = filePath:gsub("\\", "/")

	local function searchNode(node: any, currentPath: string): string?
		if node.filePaths then
			for _, file in node.filePaths do
				if file == normalizedPath or file:find(normalizedPath, 1, true) then
					return currentPath
				end
			end
		end

		if node.children then
			for _, child in node.children do
				local childPath = if currentPath == "game"
					then `game["{child.name}"]`
					else `{currentPath}["{child.name}"]`

				local found = searchNode(child, childPath)
				if found then
					return found
				end
			end
		end

		return nil
	end

	return searchNode(sourcemap, "game")
end

return {
	loadSourcemap = loadSourcemap,
	findInstancePath = findInstancePath,
}
