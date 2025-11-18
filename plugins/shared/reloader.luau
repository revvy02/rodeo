--[[

]]

local LOG = false -- Set to false to disable reloader logging

local function log(message: string)
	if LOG then
		warn(message)
	end
end

-- Extract all require() calls from source code
local function extractRequires(source: string): { string }
	local requires = {}
	-- Match require(...) patterns
	for match in string.gmatch(source, "require%s*%([^)]+%)") do
		table.insert(requires, match)
	end
	return requires
end

-- Convert Roblox string path to instance
-- Handles @self, ./, ../
-- Will need to add support for aliases eventually
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
local function getRequireInstance(requireString: string, currentScript: Instance): ModuleScript?
	log(`[rir3-reloader] Resolving require: {requireString} from {currentScript:GetFullName()}`)

	-- Extract the path from require(path)
	local pathExpr = string.match(requireString, "require%s*%((.+)%)")
	if not pathExpr then
		log(`[rir3-reloader]   ✗ Failed to extract path from require string`)
		return nil
	end

	-- Phase 1: Try to evaluate as instance path (handles script.Parent.Module, game.ReplicatedStorage.Foo, etc.)
	local success, result = pcall(function()
		local env = {
			script = currentScript,
			game = game,
		}
		local fn = loadstring("return " .. pathExpr)
		if fn then
			setfenv(fn, env)
			return fn()
		end
	end)

	-- If loadstring succeeded and returned an Instance, use it
	if success and typeof(result) == "Instance" and result:IsA("ModuleScript") then
		log(`[rir3-reloader]   ✓ Phase 1 (loadstring): Resolved to {result:GetFullName()}`)
		return result
	end

	-- Phase 2: If loadstring failed or didn't return an instance, try string path conversion
	-- This handles "@self/path", "./relative", etc.
	log(`[rir3-reloader]   Phase 1 failed, trying Phase 2 (string conversion)`)
	local resolved = getRobloxStringPathInstance(currentScript, pathExpr)
	if resolved then
		log(`[rir3-reloader]   ✓ Phase 2: Resolved to {resolved:GetFullName()}`)
	else
		log(`[rir3-reloader]   ✗ Phase 2: Failed to resolve`)
	end
	return resolved
end

local function recurse(rootModule: ModuleScript, clonedModules: { [ModuleScript]: true }, disabledInstances)
	log(`[rir3-reloader] Processing module: {rootModule:GetFullName()}`)
	local source = rootModule.Source
	local requires = extractRequires(source)
	log(`[rir3-reloader]   Found {#requires} require() calls`)

	-- extract require calls
	-- for each require, convert path to instance
	for _, requirePath in requires do
		local requireModule = getRequireInstance(requirePath, rootModule) :: ModuleScript

		if clonedModules[requireModule] then
			log(`[rir3-reloader]   Skipping {requireModule:GetFullName()} (already cloned)`)
			continue
		end

		local requireModuleCopy = requireModule:Clone()
		clonedModules[requireModuleCopy] = true
		log(`[rir3-reloader]   Cloned: {requireModule:GetFullName()}`)

		-- Track all descendants of the original module
		local descendantCount = 0
		for _, descendant in requireModuleCopy:GetDescendants() do
			if descendant:IsA("ModuleScript") then
				clonedModules[descendant] = true
				descendantCount = descendantCount + 1
			end
		end
		if descendantCount > 0 then
			log(`[rir3-reloader]   Tracked {descendantCount} descendant modules`)
		end

		local name = requireModule.Name
		requireModule.Name = name .. ".rir3.ignore"
		requireModuleCopy.Parent = requireModule.Parent
		log(`[rir3-reloader]   Swapped: {name} <-> {requireModule.Name}`)

		table.insert(disabledInstances, requireModule)

		recurse(requireModuleCopy, clonedModules, disabledInstances)
	end
end

-- Idea is we start at source module, parse requires, get the instance for each require,
-- clone it, temporarily rename the original so requires pickup the clone, and recursively do that.
local function setupUncachableRequireModuleTraversal(rootInstance: ModuleScript)
	log(`[rir3-reloader] ━━━ Starting uncachable require setup for {rootInstance:GetFullName()} ━━━`)

	-- parse rootInstance Source
	local clonedModules = {}
	local disabledInstances = {}
	recurse(rootInstance, clonedModules, disabledInstances)

	-- Count cloned modules
	local cloneCount = 0
	for _ in clonedModules do
		cloneCount = cloneCount + 1
	end

	log(`[rir3-reloader] ✓ Setup complete: {cloneCount} modules tracked, {#disabledInstances} originals renamed`)

	return function()
		log(`[rir3-reloader] ━━━ Starting cleanup ━━━`)

		local restoredCount = 0
		for _, instance in disabledInstances do
			instance.Name = string.gsub(instance.Name, "%.rir3%.ignore$", "")
			restoredCount = restoredCount + 1
		end
		log(`[rir3-reloader]   Restored {restoredCount} original module names`)

		local destroyedCount = 0
		for module in clonedModules do
			module:Destroy()
			destroyedCount = destroyedCount + 1
		end
		log(`[rir3-reloader]   Destroyed {destroyedCount} cloned modules`)
		log(`[rir3-reloader] ✓ Cleanup complete`)
	end
end

return {
	setupUncachableRequireModuleTraversal = setupUncachableRequireModuleTraversal,
}
