-- Shared utilities for rodeo plugins

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
			moduleScript.Source = script
			moduleScript.Parent = originalInstance.Parent
		else
			if originalInstance then
				warn(`[rodeo] Instance at {instancePath} is not a ModuleScript, using temp module`)
			else
				warn(`[rodeo] Instance not found: {instancePath}, using temp module`)
			end
			moduleScript = Instance.new("ModuleScript")
			moduleScript.Source = script
		end
	else
		moduleScript = Instance.new("ModuleScript")
		moduleScript.Source = script
	end

	return moduleScript
end

return {
	resolveInstancePath = resolveInstancePath,
	createModuleScript = createModuleScript,
}
