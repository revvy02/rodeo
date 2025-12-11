local SOURCE_TEMPLATE = script.sourceModule.Source
local terminal = require(script.Parent.terminal)

-- Debug logging (verbose flag passed per-execution)
local VERBOSE = true

-- Registry: module instance → { fenv, execute }
local registry = {}

-- Require that checks registry first, falls back to normal require
-- If module is registered, executes it and returns the result
local function requireFromRegistry(module: ModuleScript)
	local entry = registry[module]
	if entry then
		return entry.execute()
	end
	return require(module)
end

local function log(message: string)
	if VERBOSE then
		local source, line, name = debug.info(2, "sln")
		local formattedSource = terminal.style.gray(source)
		local formattedLine = terminal.style.red(tostring(line))
		local formattedName = terminal.style.green(name or "?")
		print(`[{formattedSource}:{formattedLine} {formattedName}] {message}`)
	end
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

-- Helper: Create input module proxy for fenv
local function createInputModule(upvalues)
	return function(set, get)
		return setmetatable({}, {
			__newindex = function(_, k, v)
				if upvalues[k] == nil then
					error(`"{k}" is not a defined upvalue`, 2)
				end
				set(k, v)
			end,
			__index = function(_, k)
				if upvalues[k] == nil then
					error(`"{k}" is not a defined upvalue`, 2)
				end
				return get(k)
			end,
		})
	end
end

-- Generate "local a, b, c" from upvalue keys
local function generateUpvalueLocals(upvalues: { [string]: any }): string
	local keys = {}
	for k in upvalues do
		table.insert(keys, k)
	end
	if #keys == 0 then
		return ""
	end
	return "local " .. table.concat(keys, ", ")
end

-- Generate if-chain for setter: if k == "a" then a = v elseif k == "b" then b = v end
local function generateSetterChain(upvalues: { [string]: any }): string
	local parts = {}
	local first = true
	for k in upvalues do
		if first then
			table.insert(parts, `if k == "{k}" then {k} = v`)
			first = false
		else
			table.insert(parts, `elseif k == "{k}" then {k} = v`)
		end
	end
	if #parts == 0 then
		return ""
	end
	table.insert(parts, "end")
	return table.concat(parts, " ")
end

-- Generate if-chain for getter: if k == "a" then return a elseif k == "b" then return b end
local function generateGetterChain(upvalues: { [string]: any }): string
	local parts = {}
	local first = true
	for k in upvalues do
		if first then
			table.insert(parts, `if k == "{k}" then return {k}`)
			first = false
		else
			table.insert(parts, `elseif k == "{k}" then return {k}`)
		end
	end
	if #parts == 0 then
		return ""
	end
	table.insert(parts, "end")
	return table.concat(parts, " ")
end

-- Build rodeo module, require it, setup fenv/execute, and register in registry
local function fromSourceCached(src: string, params: { name: string?, parent: Instance?, upvalues: { [string]: any }? }?)
	local p = params or {}
	local upvalues = p.upvalues or {}
	log(`fromSourceCached: name={p.name}, parent={p.parent and p.parent:GetFullName() or "nil"}`)

	-- Generate source with upvalue machinery
	local generatedSource = SOURCE_TEMPLATE
	generatedSource = string.gsub(generatedSource, "%-%-%[%[RODEO_UPVALUES%]%]", generateUpvalueLocals(upvalues), 1)
	generatedSource = string.gsub(generatedSource, "%-%-%[%[RODEO_SET_UPVALUE%]%]", generateSetterChain(upvalues), 1)
	generatedSource = string.gsub(generatedSource, "%-%-%[%[RODEO_GET_UPVALUE%]%]", generateGetterChain(upvalues), 1)
	generatedSource = string.gsub(generatedSource, "%-%-%[%[SOURCE%]%]", function()
		return src
	end, 1)
	log(`Generated source length: {#generatedSource}`)

	-- Create ModuleScript
	local sourceModule = Instance.new("ModuleScript")
	sourceModule.Source = generatedSource
	if p.name then
		sourceModule.Name = p.name
	end
	if p.parent then
		sourceModule.Parent = p.parent
	end

	-- Require and setup fenv/execute
	log(`Requiring module...`)
	local setup = require(sourceModule)
	local fenv, executor = setup(createInputModule(upvalues))

	-- Inject upvalues
	for k, v in upvalues do
		fenv[k] = v
	end
	log(`Setup complete`)

	local function execute(...)
		local success, result = executor(...)
		if success then
			return unpack(result)
		else
			error(result, 0)
		end
	end

	-- Register in registry
	registry[sourceModule] = {
		fenv = fenv,
		execute = execute,
	}
	log(`Registered in registry`)

	return {
		module = sourceModule,
		execute = execute,
		cleanup = function()
			registry[sourceModule] = nil
			sourceModule:Destroy()
		end,
		fenv = fenv,
	}
end

--- This function is supposed to guarantee that if you require the module,
--- any requires in its dependency graph will not be cached
local createUncachedTraversalEnvironment
do
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
	local function extractRequiresFromSource(source: string): { string }
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
	local function getInstanceFromStringPath(rootInstance: Instance, pathString: string): ModuleScript?
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

	-- Find the topmost ModuleScript ancestor (root of the module tree)
	local function findRootModule(module: ModuleScript): ModuleScript
		local ancestor = module:FindFirstAncestorOfClass("ModuleScript")
		if ancestor then
			return findRootModule(ancestor)
		end
		return module
	end

	-- Resolve a require path to an actual instance
	-- Two-phase resolution: try eval first, then string path conversion
	local function getInstanceFromRequireTarget(requireString: string, currentScript: Instance): ModuleScript?
		log(`Resolving require: {requireString} from {currentScript:GetFullName()}`)

		-- Extract the path from require(path) using helper function
		local pathExpr, _ = extractParenthesisContent(requireString, 1)
		if not pathExpr then
			log(`  Failed to extract path from require string`)
			return nil
		end

		-- Strip quotes and whitespace from the path expression
		pathExpr = string.gsub(pathExpr, "^%s*[\"']?", "") -- Remove leading whitespace and quotes
		pathExpr = string.gsub(pathExpr, "[\"']?%s*$", "") -- Remove trailing quotes and whitespace

		-- Phase 1: Evaluate path using fromCachedSource
		local success, result = pcall(function()
			local exec = fromSourceCached(`return {pathExpr}`, {
				name = "__RODEO_PATH_RESOLVER__",
				parent = currentScript.Parent,
				upvalues = {
					script = currentScript,
				},
			})
			local value = exec.execute()
			exec.cleanup()
			return value
		end)

		-- If eval succeeded and returned a ModuleScript, use it
		if success and typeof(result) == "Instance" and result:IsA("ModuleScript") then
			log(`  Phase 1 (eval): Resolved to {result:GetFullName()}`)
			return result
		end

		-- Phase 2: If eval failed or didn't return an instance, try string path conversion
		-- This handles "@self/path", "./relative", etc.
		log(`  Phase 1 failed, trying Phase 2 (string conversion)`)
		local resolved = getInstanceFromStringPath(currentScript, pathExpr)
		if resolved then
			log(`  Phase 2: Resolved to {resolved:GetFullName()}`)
		else
			log(`  Phase 2: Failed to resolve`)
		end
		return resolved
	end

	local function recurse(currentModule: ModuleScript, clonedModules: { [ModuleScript]: true }, clonedRoots: { ModuleScript }, disabledInstances: { ModuleScript })
		log(`Processing module: {currentModule:GetFullName()}`)
		local source = currentModule.Source
		local requires = extractRequiresFromSource(source)
		log(`  Found {#requires} require() calls`)

		for _, requirePath in requires do
			local requireModule = getInstanceFromRequireTarget(requirePath, currentModule)

			if not requireModule then
				log(`  Failed to resolve require, skipping`)
				continue
			end

			-- Skip if this module is already part of a cloned subtree
			if clonedModules[requireModule] then
				log(`  Skipping {requireModule:GetFullName()} (already in cloned subtree)`)
				continue
			end

			-- Find root ancestor of this module
			local moduleRoot = findRootModule(requireModule)

			-- Clone entire root subtree
			local rootCopy = moduleRoot:Clone()
			table.insert(clonedRoots, rootCopy)
			clonedModules[rootCopy] = true
			log(`  Cloned root: {moduleRoot:GetFullName()}`)

			-- Track all descendant ModuleScripts for skip checking
			for _, descendant in rootCopy:GetDescendants() do
				if descendant:IsA("ModuleScript") then
					clonedModules[descendant] = true
				end
			end

			-- Swap: rename original root, insert clone as sibling
			local name = moduleRoot.Name
			moduleRoot.Name = name .. ".rodeo.ignore"
			rootCopy.Parent = moduleRoot.Parent
			log(`  Swapped: {name} <-> {moduleRoot.Name}`)

			table.insert(disabledInstances, moduleRoot)

			-- Recurse into cloned root
			recurse(rootCopy, clonedModules, clonedRoots, disabledInstances)
		end
	end

	-- Persistent traversal environment with activate/deactivate
	createUncachedTraversalEnvironment = function(rootModule: ModuleScript)
		log(`[createUncachedTraversalEnvironment] Starting for rootModule: {rootModule:GetFullName()}`)
		local clonedModules = {}
		local clonedRoots = {}
		local disabledInstances = {}
		local rootParents = {}

		-- Recurse does clone + swap (temporarily in activated state)
		log(`[createUncachedTraversalEnvironment] Starting recurse...`)
		recurse(rootModule, clonedModules, clonedRoots, disabledInstances)
		log(`[createUncachedTraversalEnvironment] Recurse complete. clonedRoots={#clonedRoots}, disabledInstances={#disabledInstances}`)

		-- Store parents before deactivating
		for _, root in clonedRoots do
			rootParents[root] = root.Parent
			log(`[createUncachedTraversalEnvironment] Stored parent for {root.Name}: {root.Parent and root.Parent:GetFullName() or "nil"}`)
		end

		-- Immediately deactivate: restore names, unparent clones
		log(`[createUncachedTraversalEnvironment] Deactivating (restoring names, unparenting clones)...`)
		for _, instance in disabledInstances do
			instance.Name = string.gsub(instance.Name, "%.rodeo%.ignore$", "")
		end
		for _, root in clonedRoots do
			root.Parent = nil
		end
		log(`[createUncachedTraversalEnvironment] Initial deactivation complete`)

		local active = false

		local function activate()
			if active then
				log(`[traversal.activate] Already active, skipping`)
				return
			end
			log(`[traversal.activate] Activating traversal environment...`)
			for _, instance in disabledInstances do
				log(`[traversal.activate] Renaming {instance:GetFullName()} -> {instance.Name}.rodeo.ignore`)
				instance.Name = instance.Name .. ".rodeo.ignore"
			end
			for _, root in clonedRoots do
				log(`[traversal.activate] Parenting clone {root.Name} to {rootParents[root] and rootParents[root]:GetFullName() or "nil"}`)
				root.Parent = rootParents[root]
			end
			active = true
			log(`[traversal.activate] Activation complete`)
		end

		local function deactivate()
			if not active then
				log(`[traversal.deactivate] Already inactive, skipping`)
				return
			end
			log(`[traversal.deactivate] Deactivating traversal environment...`)
			for _, instance in disabledInstances do
				instance.Name = string.gsub(instance.Name, "%.rodeo%.ignore$", "")
			end
			for _, root in clonedRoots do
				root.Parent = nil
			end
			active = false
			log(`[traversal.deactivate] Deactivation complete`)
		end

		local function cleanup()
			log(`[traversal.cleanup] Cleaning up traversal environment...`)
			deactivate()
			for _, root in clonedRoots do
				log(`[traversal.cleanup] Destroying clone: {root.Name}`)
				root:Destroy()
			end
			log(`[traversal.cleanup] Cleanup complete`)
		end

		log(`[createUncachedTraversalEnvironment] Setup complete, returning`)
		return {
			activate = activate,
			deactivate = deactivate,
			cleanup = cleanup,
		}
	end
end

--[[
    Problem:

    I try to run a module that requires an ancestor in its dependency graph in uncached mode. It clones the ancestor, so the original module doesnt resolve to the uncached ancestor.
    We need to create a link via path, where the link module is guaranteed to resolve to the cloned module. This way, we can run/require the link, and if uncached traversal is setup,
    it will go to the cloned module.
 ]]
local function fromModule(targetModule: ModuleScript, params: { upvalues: { [string]: any }?, cache: boolean? }?)
	params = params or {}
	local upvalues = params.upvalues or {}
	log(`Target: {targetModule:GetFullName()}, cache={params.cache}`)

	local path = assert(getAbsoluteInstancePath(targetModule), "Module must be descendant of game")
	log(`Resolved path: {path}`)

	-- Rename original so path resolves to our fenv-wrapped module
	local originalName = targetModule.Name
	targetModule.Name = originalName .. ".rodeo.ignore"
	log(`Renamed original to: {targetModule.Name}`)

	-- Create rodeoModule executable (registers in registry)
	log(`Creating rodeoModule executable...`)
	local rodeoExecutable = fromSourceCached(targetModule.Source, {
		upvalues = upvalues,
		name = originalName,
		parent = targetModule.Parent,
	})
	local rodeoModule = rodeoExecutable.module

	if params.cache then
		log(`Using CACHED mode`)
		return {
			module = rodeoModule,
			execute = rodeoExecutable.execute,
			cleanup = function()
				targetModule.Name = originalName
				rodeoExecutable.cleanup()
			end,
			fenv = rodeoExecutable.fenv,
		}
	end

	-- Uncached: use persistent traversal environment
	log(`Using UNCACHED mode`)

	-- Create link with requireFromRegistry injected as 'require'
	log(`Creating link executable with path: {path}`)
	local linkExecutable = fromSourceCached(`return require({path})`, {
		name = "__RODEO_LINK__",
		parent = script,
		upvalues = { require = requireFromRegistry },
	})
	log(`Link executable created`)

	log(`Creating uncached traversal environment...`)
	local traversal = createUncachedTraversalEnvironment(linkExecutable.module)
	log(`Traversal environment created`)

	local function execute(...)
		traversal.activate()
		local result = { linkExecutable.execute(...) }
		traversal.deactivate()
		return unpack(result)
	end

	return {
		module = rodeoModule,
		execute = execute,
		cleanup = function()
			traversal.cleanup()
			targetModule.Name = originalName
			rodeoExecutable.cleanup()
			linkExecutable.cleanup()
		end,
		fenv = rodeoExecutable.fenv,
	}
end

local function fromSource(source: string, params: { upvalues: { [string]: any }?, cache: boolean?, name: string?, parent: Instance? }?)
	params = params or {}
	log(`source length={#source}, name={params.name}, parent={params.parent and params.parent:GetFullName() or "nil"}, cache={params.cache}`)

	-- For source strings, we just use fromSourceCached directly
	-- (no game module to rename/swap, no uncached traversal needed)
	local result = fromSourceCached(source, {
		upvalues = params.upvalues,
		name = params.name,
		parent = params.parent,
	})

	log(`Done, returning result`)
	return result
end

local function execSource(source: string, params: { name: string?, parent: Instance?, upvalues: { [string]: any }?, cache: boolean? }?, ...)
	local executable = fromSource(source, params)
	local results = { executable.execute(...) }
	executable.cleanup()
	return unpack(results)
end

local function execModule(targetModule: ModuleScript, params: { upvalues: { [string]: any }?, cache: boolean? }?, ...)
	local executable = fromModule(targetModule, params)
	local results = { executable.execute(...) }
	executable.cleanup()
	return unpack(results)
end

return {
	execSource = execSource,
	execModule = execModule,
	fromSource = fromSource,
	fromModule = fromModule,
}
