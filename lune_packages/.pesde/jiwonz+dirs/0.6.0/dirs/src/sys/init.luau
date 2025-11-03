local process = require("@lune/process")
local env = process.env
local targetOS = process.os
local pathfs = require("../lune_packages/pathfs")
local fs = pathfs.fs

local sys = {}

local function homeDir(): pathfs.Path?
	local home = process.env.HOME
	if home then
		return pathfs.Path.from(home)
	end
	return
end

local function isAbsolutePath(pathStr: string): pathfs.Path?
	local path = pathfs.Path.from(pathStr)
	if path:isAbsolute() then
		return path
	else
		return
	end
end

if targetOS == "linux" then
	local dirsSys = {
		homeDir = homeDir,
		isAbsolutePath = isAbsolutePath,
	}
	local xdgUserDirs = require("@self/xdgUserDirs")

	local function userDirFile(home: pathfs.Path): pathfs.Path
		return (isAbsolutePath(env.XDG_CONFIG_HOME) or home:join(".config")):join("user-dirs.dirs")
	end

	local function userDir(userDirName: string): pathfs.Path?
		local home = homeDir()
		if home then
			return xdgUserDirs.single(home, userDirFile(home), userDirName)[userDirName]
		else
			return
		end
	end

	local function userDirs(homeDirPath: pathfs.Path): { [string]: pathfs.Path }
		return xdgUserDirs.all(homeDirPath, userDirFile(homeDirPath))
	end

	dirsSys.userDir = userDir
	dirsSys.userDirs = userDirs
	sys.linux = dirsSys
end

if targetOS ~= "windows" and targetOS ~= "linux" then
	local dirsSys = {
		homeDir = homeDir,
		isAbsolutePath = isAbsolutePath,
	}
	sys.neitherWindowsNorUnix = dirsSys
end

if targetOS == "windows" then
	local dirsSys = {
		homeDir = homeDir,
		isAbsolutePath = isAbsolutePath,
	}
	local KNOWNFOLDERID = require("./win32/KNOWNFOLDERID")
	local defaultKnownFolderPaths = require("./win32/defaultKnownFolderPaths")
	local parsePath = require("./win32/parsePath")

	--[=[
		Due to lack of lune-ffi built-in library, there's no way to call SHGetKnownFolderPath. so we're going to dlopen via powershell temporary.

		Tries with default path if powershell fails.
	]=]
	local function knownFolder(guid: string): pathfs.Path?
		local success, value = pcall(function()
			local script = `$GetSignature = @'\
[DllImport("shell32.dll", CharSet = CharSet.Unicode)]public extern static int SHGetKnownFolderPath(\
ref Guid folderId,\
uint flags,\
IntPtr token,\
out IntPtr pszProfilePath);\
'@\
$GetType = Add-Type -MemberDefinition $GetSignature -Name 'GetKnownFolders' -Namespace 'SHGetKnownFolderPath' -Using "System.Text" -PassThru -ErrorAction SilentlyContinue\
$ptr = [intptr]::Zero\
[void]$GetType::SHGetKnownFolderPath([Ref]"{guid}", 0, 0, [ref]$ptr)\
[System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)\
[System.Runtime.InteropServices.Marshal]::FreeCoTaskMem($ptr)`
			local result = process.exec("powershell", { "-Command", script })
			if result.ok then
				return result.stdout:split("\r\n")[1]
			else
				error("Powershell command was not successful")
			end
		end)
		if success then
			return pathfs.Path.from(value)
		else
			local defaultPath = defaultKnownFolderPaths[guid]
			if type(defaultPath) == "string" then
				local parsed = parsePath(defaultPath)
				if parsed and fs.isFile(parsed) then
					return parsed
				end
			elseif type(defaultPath) == "table" then
				for _, v in defaultPath do
					local parsed = parsePath(v)
					if parsed and fs.isFile(parsed) then
						return parsed
					end
				end
			end
		end
		return
	end

	local function knownFolderProfile(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_Profile)
	end

	local function knownFolderRoamingAppData(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_RoamingAppData)
	end

	local function knownFolderLocalAppData(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_LocalAppData)
	end

	local function knownFolderMusic(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_Music)
	end

	local function knownFolderDesktop(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_Desktop)
	end

	local function knownFolderDocuments(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_Documents)
	end

	local function knownFolderDownloads(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_Downloads)
	end

	local function knownFolderPictures(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_Pictures)
	end

	local function knownFolderPublic(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_Public)
	end

	local function knownFolderTemplates(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_Templates)
	end

	local function knownFolderVideos(): pathfs.Path?
		return knownFolder(KNOWNFOLDERID.FOLDERID_Videos)
	end

	dirsSys.knownFolder = knownFolder
	dirsSys.knownFolderProfile = knownFolderProfile
	dirsSys.knownFolderRoamingAppData = knownFolderRoamingAppData
	dirsSys.knownFolderLocalAppData = knownFolderLocalAppData
	dirsSys.knownFolderMusic = knownFolderMusic
	dirsSys.knownFolderDesktop = knownFolderDesktop
	dirsSys.knownFolderDocuments = knownFolderDocuments
	dirsSys.knownFolderDownloads = knownFolderDownloads
	dirsSys.knownFolderPictures = knownFolderPictures
	dirsSys.knownFolderPublic = knownFolderPublic
	dirsSys.knownFolderTemplates = knownFolderTemplates
	dirsSys.knownFolderVideos = knownFolderVideos
	sys.windows = dirsSys
end

return sys
