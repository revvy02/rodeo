--[[
	require_resolver.luau - Require resolution and uncacheable module traversal

	Handles converting require() paths to actual instances, cloning module trees
	to bypass Roblox's require cache, and cleaning up after execution.
]]

local utils = require(script.Parent.utils)

-- Noop logger for functions called without one
local noop = function() end
local noopLog = { debug = noop, info = noop, warn = noop, error = noop }

-- Find the topmost ModuleScript ancestor (root of the module tree)
local function findRootModule(module: ModuleScript): ModuleScript
	local ancestor = module:FindFirstAncestorOfClass("ModuleScript")
	if ancestor then
		return findRootModule(ancestor)
	end
	return module
end

-- Get absolute instance path from game using bracket notation
-- e.g. game["Workspace"]["Part"] or game["ReplicatedStorage"]["Modules"]["Utils"]
-- Returns nil if the instance is not a descendant of game
local function getAbsoluteInstancePath(instance: Instance): string?
	if instance == game then
		return "game"
	end

	local parts = {}
	local current = instance

	while current and current ~= game do
		table.insert(parts, 1, `["{current.Name}"]`)
		current = current.Parent
	end

	-- If we didn't reach game, the instance has no valid path
	if current ~= game then
		return nil
	end

	return "game" .. table.concat(parts, "")
end

-- Extract content from outermost parentheses, handling nested parens
-- Returns: content string and ending position, or nil if not found
local function extractParenthesisContent(str: string, startPos: number): (string?, number?)
	local openParenPos = string.find(str, "%(", startPos)
	if not openParenPos then
		return nil, nil
	end

	local depth = 0
	local pathStart = openParenPos + 1
	local pathEnd = nil

	for i = openParenPos, #str do
		local char = string.sub(str, i, i)
		if char == "(" then
			depth = depth + 1
		elseif char == ")" then
			depth = depth - 1
			if depth == 0 then
				pathEnd = i - 1
				return string.sub(str, pathStart, pathEnd), i
			end
		end
	end

	return nil, nil
end

-- Extract all require() calls from source code
local function extractRequires(source: string): { string }
	local requires = {}
	local pos = 1

	while true do
		-- Find next "require" keyword
		local requireStart = string.find(source, "require%s*%(", pos)
		if not requireStart then
			break
		end

		-- Check if this require is commented out (-- before require on same line)
		-- Find the start of the current line by searching backwards for newline
		local lineStart = 1
		for i = requireStart - 1, 1, -1 do
			if string.sub(source, i, i) == "\n" then
				lineStart = i + 1
				break
			end
		end
		local lineBeforeRequire = string.sub(source, lineStart, requireStart - 1)
		if string.find(lineBeforeRequire, "%-%-") then
			-- This require is in a comment, skip it
			pos = requireStart + 1
			continue
		end

		-- Extract the full require call with nested parentheses
		local content, endPos = extractParenthesisContent(source, requireStart)
		if content and endPos then
			-- Reconstruct the full require string
			local fullRequire = string.sub(source, requireStart, endPos)
			table.insert(requires, fullRequire)
			pos = endPos + 1
		else
			-- Skip this occurrence and continue
			pos = requireStart + 1
		end
	end

	return requires
end

-- Convert Roblox string path to instance
-- Handles @self, ./, ../
local function getRobloxStringPathInstance(rootInstance: Instance, pathString: string): ModuleScript?
	local current = rootInstance

	-- Remove quotes if present
	pathString = string.gsub(pathString, "^[\"']", "")
	pathString = string.gsub(pathString, "[\"']$", "")

	-- Handle @self prefix (means the script itself)
	if string.sub(pathString, 1, 5) == "@self" then
		current = rootInstance
		pathString = string.sub(pathString, 6) -- Remove "@self"
		if string.sub(pathString, 1, 1) == "/" then
			pathString = string.sub(pathString, 2) -- Remove leading /
		end
	else
		-- Require explicit ./ or ../ prefix (Luau spec compliance)
		-- ./ means script.Parent (sibling)
		-- ../ means go up one level (chainable)

		-- Start from script.Parent for relative paths
		current = rootInstance.Parent or rootInstance

		-- Must have ./ or ../ prefix
		if string.sub(pathString, 1, 2) == "./" then
			pathString = string.sub(pathString, 3) -- Remove "./"
		elseif string.sub(pathString, 1, 3) == "../" then
			-- Handle chained ../
			while string.sub(pathString, 1, 3) == "../" do
				current = current.Parent or current
				pathString = string.sub(pathString, 4) -- Remove "../"
			end
		else
			-- No valid prefix (./, ../, or @) - return nil per Luau spec
			return nil
		end
	end

	-- If path is now empty, return current
	if pathString == "" then
		if typeof(current) == "Instance" and current:IsA("ModuleScript") then
			return current
		end
		return nil
	end

	-- Split remaining path by / and navigate
	local parts = string.split(pathString, "/")
	for _, part in parts do
		if part ~= "" then
			local child = current:FindFirstChild(part)
			if not child then
				return nil
			end
			current = child
		end
	end

	-- Verify final result is a ModuleScript
	if typeof(current) == "Instance" and current:IsA("ModuleScript") then
		return current
	end

	return nil
end

-- Resolve a require path to an actual instance
-- Two-phase resolution: try loadstring first, then string path conversion
local function getRequireInstance(requireString: string, currentScript: Instance, log: any?): ModuleScript?
	local l = log or noopLog
	l.debug(`Resolving require: {requireString} from {currentScript:GetFullName()}`)

	-- Extract the path from require(path) using helper function
	local pathExpr, _ = extractParenthesisContent(requireString, 1)
	if not pathExpr then
		l.debug(`Failed to extract path from require string`)
		return nil
	end

	-- Strip quotes and whitespace from the path expression
	pathExpr = string.gsub(pathExpr, "^%s*[\"']?", "") -- Remove leading whitespace and quotes
	pathExpr = string.gsub(pathExpr, "[\"']?%s*$", "") -- Remove trailing quotes and whitespace

	-- Phase 1: Evaluate path using temp module (avoids loadstring/setfenv VM de-optimization)
	local success, result = pcall(function()
		local tempModule = Instance.new("ModuleScript")
		tempModule.Name = "__rodeo_resolver"
		-- Assign script to currentScript so child paths like script.SomeChild work
		tempModule.Source = 'local ok, r = pcall(function()\nscript = script.Parent and script.Parent["' .. currentScript.Name .. '"]\nreturn ' .. pathExpr .. '\nend)\nreturn ok and r or nil'
		tempModule.Parent = currentScript.Parent
		local resolved = require(tempModule)
		tempModule:Destroy()
		return resolved
	end)

	-- If temp module succeeded and returned a ModuleScript, use it
	if success and typeof(result) == "Instance" and result:IsA("ModuleScript") then
		l.debug(`Phase 1 (temp module): Resolved to {result:GetFullName()}`)
		return result
	end

	-- Phase 2: If loadstring failed or didn't return an instance, try string path conversion
	-- This handles "@self/path", "./relative", etc.
	l.debug(`Phase 1 failed, trying Phase 2 (string conversion)`)
	local resolved = getRobloxStringPathInstance(currentScript, pathExpr)
	if resolved then
		l.debug(`Phase 2: Resolved to {resolved:GetFullName()}`)
	else
		l.debug(`Phase 2: Failed to resolve`)
	end
	return resolved
end

local function recurse(currentModule: ModuleScript, clonedModules: { [ModuleScript]: true }, clonedRoots: { ModuleScript }, disabledInstances, visited: { [ModuleScript]: true }, suffix: string, log: any)
	if visited[currentModule] then
		return
	end
	visited[currentModule] = true

	log.debug(`Processing: {currentModule:GetFullName()}`)
	local source = currentModule.Source
	local requires = extractRequires(source)
	log.debug(`Found {#requires} require() calls`)

	for _, requirePath in requires do
		log.debug(`Resolving: {requirePath}`)
		local requireModule = getRequireInstance(requirePath, currentModule, log)

		if not requireModule then
			log.debug(`Failed to resolve, skipping`)
			continue
		end

		log.debug(`Resolved to: {requireModule:GetFullName()}`)

		-- If already cloned, still recurse to discover external deps
		if clonedModules[requireModule] then
			log.debug(`Already in cloned subtree, recursing for external deps`)
			recurse(requireModule, clonedModules, clonedRoots, disabledInstances, visited, suffix, log)
			continue
		end

		-- Find root ancestor of this module (topmost ModuleScript)
		local moduleRoot = findRootModule(requireModule)
		log.debug(`Root module: {moduleRoot:GetFullName()}`)

		-- Clone entire root subtree
		local rootCopy = moduleRoot:Clone()
		table.insert(clonedRoots, rootCopy)
		clonedModules[rootCopy] = true
		log.debug(`Cloned root: {moduleRoot.Name}`)

		-- Track all descendant ModuleScripts for skip checking
		for _, descendant in rootCopy:GetDescendants() do
			if descendant:IsA("ModuleScript") then
				clonedModules[descendant] = true
			end
		end

		-- Swap: rename original root, insert clone as sibling
		local name = moduleRoot.Name
		moduleRoot.Name = name .. suffix
		rootCopy.Parent = moduleRoot.Parent
		log.debug(`Swapped: {name} <-> {moduleRoot.Name}`)

		table.insert(disabledInstances, moduleRoot)

		-- Recurse into cloned root
		recurse(rootCopy, clonedModules, clonedRoots, disabledInstances, visited, suffix, log)
	end
end

-- Setup uncachable requires by cloning and renaming modules
local function setupUncachableRequireModuleTraversal(rootInstance: ModuleScript, executionId: string?, log: any?): () -> ()
	local l = log or noopLog
	l.debug(`START for {rootInstance:GetFullName()}`)

	-- Process-scoped suffix so concurrent processes don't collide
	local eid = if executionId and executionId ~= "" then executionId else ""
	local suffix = utils.makeIgnoreSuffix(eid)
	local suffixPattern = utils.makeIgnoreSuffixPattern(eid)

	local clonedModules = {}
	local clonedRoots = {}
	local disabledInstances = {}
	recurse(rootInstance, clonedModules, clonedRoots, disabledInstances, {}, suffix, l)

	l.debug(`COMPLETE: {#clonedRoots} roots cloned, {#disabledInstances} originals renamed`)

	return function()
		l.debug(`Cleanup START`)

		-- PHASE 1: Restore original names
		l.debug(`Restoring {#disabledInstances} original names`)
		for _, instance in disabledInstances do
			instance.Name = string.gsub(instance.Name, suffixPattern, "")
		end

		-- PHASE 2: Destroy only the root clones (children are destroyed automatically)
		l.debug(`Destroying {#clonedRoots} root clones`)
		for _, root in clonedRoots do
			l.debug(`  Destroying root: {root.Name}`)
			root:Destroy()
		end

		l.debug(`Cleanup END`)
	end
end

return {
	getAbsoluteInstancePath = getAbsoluteInstancePath,
	setupUncachableRequireModuleTraversal = setupUncachableRequireModuleTraversal,
	extractRequires = extractRequires,
	extractParenthesisContent = extractParenthesisContent,
	getRobloxStringPathInstance = getRobloxStringPathInstance,
	getRequireInstance = getRequireInstance,
}
