-- Embedded plugin utilities
-- Handles writing embedded plugin binaries to Studio plugin directory
-- with runtime flag patching for serve vs once mode

local fs = require("@lune/fs")

type PluginConfig = {
	DEBUG: boolean,
	SETTINGS_PANEL_ENABLED: boolean,
	SETTINGS: {
		port: number,
		autoConnect: boolean,
	},
}

-- Patch configuration flags in the plugin rbxmx binary
-- The flags.luau file contains placeholder values that we replace via string substitution
local function patchFlags(binaryData: string, config: PluginConfig): string
	local patched = binaryData

	-- Patch DEBUG flag
	patched = string.gsub(patched, "DEBUG = false", `DEBUG = {tostring(config.DEBUG)}`)

	-- Patch SETTINGS_PANEL_ENABLED flag
	patched = string.gsub(patched, "SETTINGS_PANEL_ENABLED = true", `SETTINGS_PANEL_ENABLED = {tostring(config.SETTINGS_PANEL_ENABLED)}`)

	-- Patch SETTINGS.port
	patched = string.gsub(patched, "port = 44872", `port = {config.SETTINGS.port}`)

	-- Patch SETTINGS.autoConnect
	patched = string.gsub(patched, "autoConnect = false", `autoConnect = {tostring(config.SETTINGS.autoConnect)}`)

	return patched
end

local function writeEmbeddedPlugin(binaryData: string, targetPath: string)
	-- Ensure parent directory exists
	local parentDir = targetPath:match("(.+)/[^/]+$")
	if parentDir and not fs.isDir(parentDir) then
		fs.writeDir(parentDir)
	end

	-- Write the plugin file directly (raw binary string)
	fs.writeFile(targetPath, binaryData)
end

local function writeOncePlugin(targetPath: string, port: number?)
	local patched = patchFlags(_G.RODEO_PLUGIN, {
		DEBUG = false,
		SETTINGS_PANEL_ENABLED = false,
		SETTINGS = {
			port = port or 44873,
			autoConnect = true,
		},
	})
	writeEmbeddedPlugin(patched, targetPath)
end

local function writeServePlugin(targetPath: string, port: number?)
	local patched = patchFlags(_G.RODEO_PLUGIN, {
		DEBUG = false,
		SETTINGS_PANEL_ENABLED = true,
		SETTINGS = {
			port = port or 44872,
			autoConnect = false,
		},
	})
	writeEmbeddedPlugin(patched, targetPath)
end

return {
	writeOncePlugin = writeOncePlugin,
	writeServePlugin = writeServePlugin,
}
