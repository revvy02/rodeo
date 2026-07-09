-- Shared utilities for rodeo plugins

local constants = require(script.Parent.constants)

local function resolveInstancePath(path: string): Instance?
	local resolver = Instance.new("ModuleScript")
	resolver.Name = "__rodeo_path_resolver"
	resolver.Source = "return " .. path
	resolver.Parent = game:GetService("ReplicatedStorage")

	local success, result = pcall(function()
		return require(resolver)
	end)

	resolver:Destroy()

	if success and typeof(result) == "Instance" then
		return result
	end
	return nil
end

local function makeIgnoreSuffix(executionId: string): string
	return constants.IGNORE_SUFFIX .. executionId
end

local function makeIgnoreSuffixPattern(executionId: string): string
	local suffix = makeIgnoreSuffix(executionId)
	return string.gsub(string.gsub(suffix, "%.", "%%."), "%-", "%%-") .. "$"
end

export type RunContext = "server" | "client" | "plugin" | "elevated"

-- i cloned because for some reason runner loses children and .rpc errors, this is an attempt to fully preserve
-- runner template for what seems to be an edge case from plugin hot reloading
local runnerTemplate = script.Parent:WaitForChild("runner"):Clone()
export type ExecutionContext = {
	runner: ModuleScript,
	shim: (Script | LocalScript)?,
	module: ModuleScript,
	originalInstance: ModuleScript?,
	resultsEvent: BindableEvent,
	incomingEvent: BindableEvent,
	outgoingEvent: BindableEvent,
	cleanup: () -> (),
}

local function createExecutionContext(source: string, context: RunContext, executionId: string, instancePath: string?, scriptPath: string?): ExecutionContext
	-- Determine module name for stack traces
	-- Priority: instancePath → scriptPath → source
	local moduleName = source
	if instancePath then
		local lastSegment = string.match(instancePath, '%["([^"]+)"%]$')
		if lastSegment then
			moduleName = lastSegment
		end
	elseif scriptPath then
		moduleName = scriptPath
	end

	-- Create or clone user module
	local module: ModuleScript
	local originalInstance: ModuleScript? = nil
	if instancePath then
		local resolved = resolveInstancePath(instancePath)
		if resolved and resolved:IsA("ModuleScript") then
			originalInstance = resolved
			module = originalInstance:Clone()

			-- Rename original so clone takes precedence in require resolution
			originalInstance.Name = originalInstance.Name .. makeIgnoreSuffix(executionId)
			module.Parent = originalInstance.Parent
		else
			module = Instance.new("ModuleScript")
			module.Name = moduleName
			module.Source = source
		end
	else
		module = Instance.new("ModuleScript")
		module.Name = moduleName
		module.Source = source
	end

	-- Create nil-parented runner module from template
	local runner = Instance.new("ModuleScript")
	runner.Name = "@rodeo/runner"
	runner.Source = runnerTemplate.Source

	-- BindableEvents as children of runner (init.luau accesses via script.results etc.)
	local resultsEvent = Instance.new("BindableEvent")
	resultsEvent.Name = "results"
	resultsEvent.Parent = runner

	local incomingEvent = Instance.new("BindableEvent")
	incomingEvent.Name = "incoming"
	incomingEvent.Parent = runner

	local outgoingEvent = Instance.new("BindableEvent")
	outgoingEvent.Name = "outgoing"
	outgoingEvent.Parent = runner

	-- Clone and nil-parent each dependency module with @rodeo/ names for clean stack traces
	local sharedRoot = script.Parent.Parent.Parent.shared

	-- Set proto types globally so nil-parented factories can access them
	if not _G.__rodeo_runtime_proto then
		_G.__rodeo_runtime_proto = require(sharedRoot.proto.runtime)
	end

	local depModules = {}
	local function cloneDep(template: ModuleScript, name: string): ModuleScript
		local m = template:Clone()
		m.Name = name
		table.insert(depModules, m)
		return m
	end

	local rpcMod = cloneDep(sharedRoot.rpc, "@rodeo/rpc")
	local limitsMod = cloneDep(sharedRoot.limits, "@rodeo/limits")
	local loggingMod = cloneDep(sharedRoot.logging, "@rodeo/logging")
	local normalizeMod = cloneDep(sharedRoot.normalize, "@rodeo/normalize")
	local serializeMod = cloneDep(sharedRoot.serialize, "@rodeo/serialize")
	local fsMod = cloneDep(sharedRoot.fs, "@rodeo/fs")
	local ioMod = cloneDep(sharedRoot.io, "@rodeo/io")
	local processMod = cloneDep(sharedRoot.process, "@rodeo/process")
	local streamMod = cloneDep(sharedRoot.stream, "@rodeo/stream")
	local robloxMod = cloneDep(runnerTemplate.roblox, "@rodeo/roblox")

	-- Build refs Folder with ObjectValues (runner init.luau resolves deps via script.refs)
	local refs = Instance.new("Folder")
	refs.Name = "refs"
	refs.Parent = runner

	local function addRef(name: string, value: Instance)
		local ov = Instance.new("ObjectValue")
		ov.Name = name
		ov.Value = value
		ov.Parent = refs
	end

	-- Clone the entire proto folder so its ModuleScripts are cross-VM reachable.
	-- Plugin-tree ModuleScripts aren't requirable from the server VM; cloned instances
	-- (parented to the runner, which is nil-parented) cross VM boundaries via ObjectValue.
	-- We clone the whole folder because runtime.luau uses `script.Parent.proto` to reach
	-- its sibling proto/ helpers folder — cloning runtime.luau alone would break that.
	local protoFolder = sharedRoot.proto:Clone()
	protoFolder.Parent = runner

	addRef("module", module)
	addRef("rpc", rpcMod)
	addRef("limits", limitsMod)
	addRef("runtimeProto", protoFolder.runtime)
	addRef("logging", loggingMod)
	addRef("normalize", normalizeMod)
	addRef("serialize", serializeMod)
	addRef("fs", fsMod)
	addRef("io", ioMod)
	addRef("process", processMod)
	addRef("stream", streamMod)
	addRef("roblox", robloxMod)

	-- Create thin shim Script/LocalScript for server/client (must be parented to trigger execution)
	local shim: (Script | LocalScript)? = nil
	if context == "server" or context == "client" then
		shim = Instance.new(if context == "server" then "Script" else "LocalScript")
		shim.Name = "__rodeo_runner_" .. executionId
		shim.Source = "require(script.refs.runner.Value)"
		local shimRefs = Instance.new("Folder")
		shimRefs.Name = "refs"
		shimRefs.Parent = shim
		local runnerOV = Instance.new("ObjectValue")
		runnerOV.Name = "runner"
		runnerOV.Value = runner
		runnerOV.Parent = shimRefs
	end

	local cleanup = function()
		module:Destroy()
		runner:Destroy()
		for _, dep in depModules do
			dep:Destroy()
		end
		if shim then
			shim:Destroy()
		end
		if originalInstance then
			originalInstance.Name = string.gsub(originalInstance.Name, makeIgnoreSuffixPattern(executionId), "")
		end
	end

	return {
		runner = runner,
		shim = shim,
		module = module,
		originalInstance = originalInstance,
		resultsEvent = resultsEvent,
		incomingEvent = incomingEvent,
		outgoingEvent = outgoingEvent,
		cleanup = cleanup,
	}
end

return {
	resolveInstancePath = resolveInstancePath,
	createExecutionContext = createExecutionContext,
	makeIgnoreSuffix = makeIgnoreSuffix,
	makeIgnoreSuffixPattern = makeIgnoreSuffixPattern,
}
