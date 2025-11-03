local dirsSys = require("./sys").windows
local types = require("./types")

local function homeDir()
	return dirsSys.knownFolderProfile()
end

local function cacheDir()
	return dataLocalDir()
end
local function configDir()
	return dirsSys.knownFolderRoamingAppData()
end
local function configLocalDir()
	return dirsSys.knownFolderLocalAppData()
end
local function dataDir()
	return dirsSys.knownFolderRoamingAppData()
end
function dataLocalDir()
	return dirsSys.knownFolderLocalAppData()
end
local function executableDir()
	return nil
end
local function preferenceDir()
	return dirsSys.knownFolderLocalAppData()
end
local function runtimeDir()
	return nil
end
local function stateDir()
	return nil
end

local function audioDir()
	return dirsSys.knownFolderMusic()
end
local function desktopDir()
	return dirsSys.knownFolderDesktop()
end
local function documentDir()
	return dirsSys.knownFolderDocuments()
end
local function downloadDir()
	return dirsSys.knownFolderDownloads()
end
local function fontDir()
	return nil
end
local function pictureDir()
	return dirsSys.knownFolderPictures()
end
local function publicDir()
	return dirsSys.knownFolderPublic()
end
local function templateDir()
	return dirsSys.knownFolderTemplates()
end
local function videoDir()
	return dirsSys.knownFolderVideos()
end

local win: types.Sys = {
	homeDir = homeDir,
	cacheDir = cacheDir,
	configDir = configDir,
	configLocalDir = configLocalDir,
	dataDir = dataDir,
	dataLocalDir = dataLocalDir,
	executableDir = executableDir,
	preferenceDir = preferenceDir,
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

return win
