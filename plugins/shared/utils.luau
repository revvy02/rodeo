-- Shared utilities for rir3 plugins

local function resolveInstancePath(path: string): Instance?
	local fn = loadstring("return " .. path)
	if not fn then
		return nil
	end

	local success, result = pcall(fn)
	if success and typeof(result) == "Instance" then
		return result
	end
	return nil
end

local function createModuleScript(script: string, instancePath: string?): ModuleScript
	local moduleScript: ModuleScript

	if instancePath then
		local originalInstance = resolveInstancePath(instancePath)
		if originalInstance and originalInstance:IsA("ModuleScript") then
			moduleScript = originalInstance:Clone()
			moduleScript.Source = "return function() " .. script .. "\nend"
			moduleScript.Parent = originalInstance.Parent
		else
			if originalInstance then
				warn(`[rir3] Instance at {instancePath} is not a ModuleScript, using temp module`)
			else
				warn(`[rir3] Instance not found: {instancePath}, using temp module`)
			end
			moduleScript = Instance.new("ModuleScript")
			moduleScript.Source = "return function() " .. script .. "\nend"
		end
	else
		moduleScript = Instance.new("ModuleScript")
		moduleScript.Source = "return function() " .. script .. "\nend"
	end

	return moduleScript
end

local function executeModule(moduleScript: ModuleScript): (boolean, any)
	local success, result = xpcall(function()
		local fn = require(moduleScript)
		return fn()
	end, debug.traceback)
	moduleScript:Destroy()

	if not success then
		local event = Instance.new("BindableEvent")
		event.Event:Connect(function()
			error(result, 0)
		end)
		event:Fire()
		return false, nil
	end

	return true, result
end

return {
	resolveInstancePath = resolveInstancePath,
	createModuleScript = createModuleScript,
	executeModule = executeModule,
}
