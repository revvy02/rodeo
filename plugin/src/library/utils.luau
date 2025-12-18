-- Shared utilities for rodeo plugins

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

local function createModuleScript(script: string, instancePath: string?): (ModuleScript, () -> ())
	local moduleScript: ModuleScript
	local cleanup = function() end

	if instancePath then
		local originalInstance = resolveInstancePath(instancePath)
		if originalInstance and originalInstance:IsA("ModuleScript") then
			moduleScript = originalInstance:Clone()
			-- moduleScript.Source = script
			-- Rename original so clone takes precedence
			originalInstance.Name = originalInstance.Name .. ".rodeo.ignore"
			moduleScript.Parent = originalInstance.Parent

			cleanup = function()
				moduleScript:Destroy()
				originalInstance.Name = string.gsub(originalInstance.Name, "%.rodeo%.ignore$", "")
			end
		else
			if originalInstance then
				warn(`[rodeo] Instance at {instancePath} is not a ModuleScript, using temp module`)
			else
				warn(`[rodeo] Instance not found: {instancePath}, using temp module`)
			end
			moduleScript = Instance.new("ModuleScript")
			moduleScript.Source = script
			moduleScript.Parent = game:GetService("ReplicatedStorage")
			cleanup = function()
				moduleScript:Destroy()
			end
		end
	else
		moduleScript = Instance.new("ModuleScript")
		moduleScript.Source = script
		moduleScript.Parent = game:GetService("ReplicatedStorage")
		cleanup = function()
			moduleScript:Destroy()
		end
	end

	return moduleScript, cleanup
end

return {
	resolveInstancePath = resolveInstancePath,
	createModuleScript = createModuleScript,
}
