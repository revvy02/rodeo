local dirsSys = require("./sys").linux
local types = require("./types")
local env = require("@lune/process").env

local function andThen<A, T>(a: A, fn: (A) -> T, orElse: (() -> T)?): T?
	if a then
		return fn(a)
	elseif orElse then
		return orElse()
	else
		return
	end
end

local function homeDir()
	return dirsSys.homeDir()
end

local function cacheDir()
	return andThen(env.XDG_CACHE_HOME, dirsSys.isAbsolutePath, function()
		local home = homeDir()
		return if home then home:join(".cache") else nil
	end)
end
local function configDir()
	return andThen(env.XDG_CONFIG_HOME, dirsSys.isAbsolutePath, function()
		local home = homeDir()
		return if home then home:join(".config") else nil
	end)
end
local function configLocalDir()
	return configDir()
end
local function dataDir()
	return andThen(env.XDG_DATA_HOME, dirsSys.isAbsolutePath, function()
		local home = homeDir()
		return if home then home:join(".local/share") else nil
	end)
end
local function dataLocalDir()
	return dataDir()
end
local function preferenceDir()
	return configDir()
end
local function runtimeDir()
	return andThen(env.XDG_RUNTIME_DIR, dirsSys.isAbsolutePath)
end
local function stateDir()
	return andThen(env.XDG_STATE_HOME, dirsSys.isAbsolutePath, function()
		local home = homeDir()
		return if home then home:join(".local/state") else nil
	end)
end
local function executableDir()
	return andThen(env.XDG_BIN_HOME, dirsSys.isAbsolutePath, function()
		local home = homeDir()
		return if home then home:join(".local/bin") else nil
	end)
end

local function audioDir()
	return dirsSys.userDir("MUSIC")
end
local function desktopDir()
	return dirsSys.userDir("DESKTOP")
end
local function documentDir()
	return dirsSys.userDir("DOCUMENTS")
end
local function downloadDir()
	return dirsSys.userDir("DOWNLOAD")
end
local function fontDir()
	local data = dataDir()
	return if data then data:join("fonts") else nil
end
local function pictureDir()
	return dirsSys.userDir("PICTURES")
end
local function publicDir()
	return dirsSys.userDir("PUBLICSHARE")
end
local function templateDir()
	return dirsSys.userDir("TEMPLATES")
end
local function videoDir()
	return dirsSys.userDir("VIDEOS")
end

local lin: types.Sys = {
	homeDir = homeDir,
	cacheDir = cacheDir,
	configDir = configDir,
	configLocalDir = configLocalDir,
	dataDir = dataDir,
	dataLocalDir = dataLocalDir,
	preferenceDir = preferenceDir,
	runtimeDir = runtimeDir,
	stateDir = stateDir,
	executableDir = executableDir,
	audioDir = audioDir,
	desktopDir = desktopDir,
	documentDir = documentDir,
	downloadDir = downloadDir,
	fontDir = fontDir,
	pictureDir = pictureDir,
	publicDir = publicDir,
	templateDir = templateDir,
	videoDir = videoDir,
}

return lin
