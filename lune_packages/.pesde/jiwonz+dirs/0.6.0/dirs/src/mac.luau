local dirsSys = require("./sys").neitherWindowsNorUnix
local types = require("./types")
local pathfs = require("../lune_packages/pathfs")

local function homeDir()
	return dirsSys.homeDir()
end

local function appSupportDir(): pathfs.Path?
	local home = homeDir()
	return if home then home:join("Library/Application Support") else nil
end

local function cacheDir()
	local home = homeDir()
	return if home then home:join("Library/Caches") else nil
end
local function configDir()
	return appSupportDir()
end
local function configLocalDir()
	return appSupportDir()
end
local function dataDir()
	return appSupportDir()
end
local function dataLocalDir()
	return appSupportDir()
end
local function preferenceDir()
	local home = homeDir()
	return if home then home:join("Library/Preferences") else nil
end
local function executableDir()
	return nil
end
local function runtimeDir()
	return nil
end
local function stateDir()
	return nil
end

local function audioDir()
	local home = homeDir()
	return if home then home:join("Music") else nil
end
local function desktopDir()
	local home = homeDir()
	return if home then home:join("Desktop") else nil
end
local function documentDir()
	local home = homeDir()
	return if home then home:join("Documents") else nil
end
local function downloadDir()
	local home = homeDir()
	return if home then home:join("Downloads") else nil
end
local function fontDir()
	local home = homeDir()
	return if home then home:join("Library/Fonts") else nil
end
local function pictureDir()
	local home = homeDir()
	return if home then home:join("Pictures") else nil
end
local function publicDir()
	local home = homeDir()
	return if home then home:join("Public") else nil
end
local function templateDir()
	return nil
end
local function videoDir()
	local home = homeDir()
	return if home then home:join("Movies") else nil
end

local mac: types.Sys = {
	homeDir = homeDir,
	cacheDir = cacheDir,
	configDir = configDir,
	configLocalDir = configLocalDir,
	dataDir = dataDir,
	dataLocalDir = dataLocalDir,
	preferenceDir = preferenceDir,
	executableDir = executableDir,
	runtimeDir = runtimeDir,
	stateDir = stateDir,
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

return mac
