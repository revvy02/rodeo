local process = require("@lune/process")
local targetOS = process.os
local types = require("./types")
local pathfs = require("../lune_packages/pathfs")
local gt = require("../luau_packages/greentea")

local sys: types.Sys? = if targetOS == "windows"
	then require("./win")
	elseif targetOS == "macos" then require("./mac")
	elseif targetOS == "linux" then require("./lin")
	else nil

if not sys then
	error(`Running on an unsupported OS!: {targetOS}`)
end

local dirs = {}

--[=[
	Returns the path to the user's home directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                | Example        |
	| ------- | -------------------- | -------------- |
	| Linux   | `$HOME`              | /home/alice    |
	| macOS   | `$HOME`              | /Users/Alice   |
	| Windows | `{FOLDERID_Profile}` | C:\Users\Alice |

	### Linux and macOS:

	- Use `$HOME` if it is set and not empty.
	- If `$HOME` is not set or empty, then the function `getpwuid_r` is used to determine
	the home directory of the current user.
	- If `getpwuid_r` lacks an entry for the current user id or the home directory field is empty,
	then the function returns `None`.

	### Windows:

	This function retrieves the user profile folder using `SHGetKnownFolderPath`.

	All the examples on this page mentioning `$HOME` use this behavior.
]=]
function dirs.homeDir(): pathfs.Path?
	return sys.homeDir()
end

--[=[
	Returns the path to the user's cache directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                               | Example                      |
	| ------- | ----------------------------------- | ---------------------------- |
	| Linux   | `$XDG_CACHE_HOME` or `$HOME`/.cache | /home/alice/.cache           |
	| macOS   | `$HOME`/Library/Caches              | /Users/Alice/Library/Caches  |
	| Windows | `{FOLDERID_LocalAppData}`           | C:\Users\Alice\AppData\Local |
]=]
function dirs.cacheDir(): pathfs.Path?
	return sys.cacheDir()
end

--[=[
	Returns the path to the user's config directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                                 | Example                                  |
	| ------- | ------------------------------------- | ---------------------------------------- |
	| Linux   | `$XDG_CONFIG_HOME` or `$HOME`/.config | /home/alice/.config                      |
	| macOS   | `$HOME`/Library/Application Support   | /Users/Alice/Library/Application Support |
	| Windows | `{FOLDERID_RoamingAppData}`           | C:\Users\Alice\AppData\Roaming           |
]=]
function dirs.configDir(): pathfs.Path?
	return sys.configDir()
end

--[=[
	Returns the path to the user's local config directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                                 | Example                                  |
	| ------- | ------------------------------------- | ---------------------------------------- |
	| Linux   | `$XDG_CONFIG_HOME` or `$HOME`/.config | /home/alice/.config                      |
	| macOS   | `$HOME`/Library/Application Support   | /Users/Alice/Library/Application Support |
	| Windows | `{FOLDERID_LocalAppData}`             | C:\Users\Alice\AppData\Local             |
]=]
function dirs.configLocalDir(): pathfs.Path?
	return sys.configLocalDir()
end

--[=[
	Returns the path to the user's data directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                                    | Example                                  |
	| ------- | ---------------------------------------- | ---------------------------------------- |
	| Linux   | `$XDG_DATA_HOME` or `$HOME`/.local/share | /home/alice/.local/share                 |
	| macOS   | `$HOME`/Library/Application Support      | /Users/Alice/Library/Application Support |
	| Windows | `{FOLDERID_RoamingAppData}`              | C:\Users\Alice\AppData\Roaming           |
]=]
function dirs.dataDir(): pathfs.Path?
	return sys.dataDir()
end

--[=[
	Returns the path to the user's local data directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                                    | Example                                  |
	| ------- | ---------------------------------------- | ---------------------------------------- |
	| Linux   | `$XDG_DATA_HOME` or `$HOME`/.local/share | /home/alice/.local/share                 |
	| macOS   | `$HOME`/Library/Application Support      | /Users/Alice/Library/Application Support |
	| Windows | `{FOLDERID_LocalAppData}`                | C:\Users\Alice\AppData\Local             |
]=]
function dirs.dataLocalDir(): pathfs.Path?
	return sys.dataLocalDir()
end

--[=[
	Returns the path to the user's executable directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                                                            | Example                |
	| ------- | ---------------------------------------------------------------- | ---------------------- |
	| Linux   | `$XDG_BIN_HOME` or `$XDG_DATA_HOME`/../bin or `$HOME`/.local/bin | /home/alice/.local/bin |
	| macOS   | –                                                                | –                      |
	| Windows | –                                                                | –                      |
]=]
function dirs.executableDir(): pathfs.Path?
	return sys.executableDir()
end

--[=[
	Returns the path to the user's preference directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                                 | Example                          |
	| ------- | ------------------------------------- | -------------------------------- |
	| Linux   | `$XDG_CONFIG_HOME` or `$HOME`/.config | /home/alice/.config              |
	| macOS   | `$HOME`/Library/Preferences           | /Users/Alice/Library/Preferences |
	| Windows | `{FOLDERID_RoamingAppData}`           | C:\Users\Alice\AppData\Roaming   |
]=]
function dirs.preferenceDir(): pathfs.Path?
	return sys.preferenceDir()
end

--[=[
	Returns the path to the user's runtime directory.

	The runtime directory contains transient, non-essential data (like sockets or named pipes) that
	is expected to be cleared when the user's session ends.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value              | Example         |
	| ------- | ------------------ | --------------- |
	| Linux   | `$XDG_RUNTIME_DIR` | /run/user/1001/ |
	| macOS   | –                  | –               |
	| Windows | –                  | –               |
]=]
function dirs.runtimeDir(): pathfs.Path?
	return sys.runtimeDir()
end

--[=[
	Returns the path to the user's state directory.

	The state directory contains data that should be retained between sessions (unlike the runtime
	directory), but may not be important/portable enough to be synchronized across machines (unlike
	the config/preferences/data directories).

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                                     | Example                  |
	| ------- | ----------------------------------------- | ------------------------ |
	| Linux   | `$XDG_STATE_HOME` or `$HOME`/.local/state | /home/alice/.local/state |
	| macOS   | –                                         | –                        |
	| Windows | –                                         | –                        |
]=]
function dirs.stateDir(): pathfs.Path?
	return sys.stateDir()
end

--[=[
	Returns the path to the user's audio directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value              | Example              |
	| ------- | ------------------ | -------------------- |
	| Linux   | `XDG_MUSIC_DIR`    | /home/alice/Music    |
	| macOS   | `$HOME`/Music      | /Users/Alice/Music   |
	| Windows | `{FOLDERID_Music}` | C:\Users\Alice\Music |
]=]
function dirs.audioDir(): pathfs.Path?
	return sys.audioDir()
end

--[=[
	Returns the path to the user's desktop directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                | Example                |
	| ------- | -------------------- | ---------------------- |
	| Linux   | `XDG_DESKTOP_DIR`    | /home/alice/Desktop    |
	| macOS   | `$HOME`/Desktop      | /Users/Alice/Desktop   |
	| Windows | `{FOLDERID_Desktop}` | C:\Users\Alice\Desktop |
]=]
function dirs.desktopDir(): pathfs.Path?
	return sys.desktopDir()
end

--[=[
	Returns the path to the user's document directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                  | Example                  |
	| ------- | ---------------------- | ------------------------ |
	| Linux   | `XDG_DOCUMENTS_DIR`    | /home/alice/Documents    |
	| macOS   | `$HOME`/Documents      | /Users/Alice/Documents   |
	| Windows | `{FOLDERID_Documents}` | C:\Users\Alice\Documents |
]=]
function dirs.documentDir(): pathfs.Path?
	return sys.documentDir()
end

--[=[
	Returns the path to the user's download directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                  | Example                  |
	| ------- | ---------------------- | ------------------------ |
	| Linux   | `XDG_DOWNLOAD_DIR`     | /home/alice/Downloads    |
	| macOS   | `$HOME`/Downloads      | /Users/Alice/Downloads   |
	| Windows | `{FOLDERID_Downloads}` | C:\Users\Alice\Downloads |
]=]
function dirs.downloadDir(): pathfs.Path?
	return sys.downloadDir()
end

--[=[
	Returns the path to the user's font directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                                                | Example                        |
	| ------- | ---------------------------------------------------- | ------------------------------ |
	| Linux   | `$XDG_DATA_HOME`/fonts or `$HOME`/.local/share/fonts | /home/alice/.local/share/fonts |
	| macOS   | `$HOME/Library/Fonts`                                | /Users/Alice/Library/Fonts     |
	| Windows | –                                                    | –                              |
]=]
function dirs.fontDir(): pathfs.Path?
	return sys.fontDir()
end

--[=[
	Returns the path to the user's picture directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                 | Example                 |
	| ------- | --------------------- | ----------------------- |
	| Linux   | `XDG_PICTURES_DIR`    | /home/alice/Pictures    |
	| macOS   | `$HOME`/Pictures      | /Users/Alice/Pictures   |
	| Windows | `{FOLDERID_Pictures}` | C:\Users\Alice\Pictures |
]=]
function dirs.pictureDir(): pathfs.Path?
	return sys.pictureDir()
end

--[=[
	Returns the path to the user's public directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                 | Example             |
	| ------- | --------------------- | ------------------- |
	| Linux   | `XDG_PUBLICSHARE_DIR` | /home/alice/Public  |
	| macOS   | `$HOME`/Public        | /Users/Alice/Public |
	| Windows | `{FOLDERID_Public}`   | C:\Users\Public     |
]=]
function dirs.publicDir(): pathfs.Path?
	return sys.publicDir()
end

--[=[
	Returns the path to the user's template directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value                  | Example                                                    |
	| ------- | ---------------------- | ---------------------------------------------------------- |
	| Linux   | `XDG_TEMPLATES_DIR`    | /home/alice/Templates                                      |
	| macOS   | –                      | –                                                          |
	| Windows | `{FOLDERID_Templates}` | C:\Users\Alice\AppData\Roaming\Microsoft\Windows\Templates |
]=]
function dirs.templateDir(): pathfs.Path?
	return sys.templateDir()
end

--[=[
	Returns the path to the user's video directory.

	The returned value depends on the operating system and is either a `Path`, containing a value from the following table, or a `nil`.

	|Platform | Value               | Example               |
	| ------- | ------------------- | --------------------- |
	| Linux   | `XDG_VIDEOS_DIR`    | /home/alice/Videos    |
	| macOS   | `$HOME`/Movies      | /Users/Alice/Movies   |
	| Windows | `{FOLDERID_Videos}` | C:\Users\Alice\Videos |
]=]
function dirs.videoDir(): pathfs.Path?
	return sys.videoDir()
end

local tempDir = require("./utils/tempDir")

--[=[
	Returns the path to the user's temp directory.
]=]
function dirs.tempDir()
	return pathfs.Path.from(tempDir())
end

local createTemp = require("./utils/createTemp")
local optionalStringType = gt.build(gt.opt(gt.string()))
local optionalNumberType = gt.build(gt.opt(gt.number()))
local optionalAsPathType = gt.build(gt.opt(gt.custom(function(value)
	return pcall(pathfs.Path.from, value)
end, "AsPath") :: pathfs.AsPath))

--[=[
	Creates a temporary directory.

	- `base` (optional): The base directory in which to create the temporary directory. If `nil`, the system's temporary directory is used.
	- `prefix` (optional): The prefix of the temporary directory name. If `nil`, the default prefix is `.tmp`.
	- `suffix` (optional): The suffix of the temporary directory name. If `nil`, the default suffix is an empty string.
	- `randomLength` (optional): The length of the random part of the temporary directory name. If `nil`, the default length is 6.

	Returns a `Path` object representing the temporary directory.
]=]
function dirs.createTempDir(
	base: typeof(optionalAsPathType:type()),
	prefix: typeof(optionalStringType:type()),
	suffix: typeof(optionalStringType:type()),
	randomLength: typeof(optionalNumberType:type())
): pathfs.DirectoryPath
	assert(optionalAsPathType(base))
	assert(optionalStringType(prefix))
	assert(optionalStringType(suffix))
	assert(optionalNumberType(randomLength))

	return pathfs.DirectoryPath.fromExisting(createTemp(true, base, prefix, suffix, randomLength))
end

--[=[
	Creates a temporary file.

	- `base` (optional): The base directory in which to create the temporary file. If `nil`, the system's temporary directory is used.
	- `prefix` (optional): The prefix of the temporary file name. If `nil`, the default prefix is `.tmp`.
	- `suffix` (optional): The suffix of the temporary file name. If `nil`, the default suffix is an empty string.
	- `randomLength` (optional): The length of the random part of the temporary file name. If `nil`, the default length is 6.

	Returns a `Path` object representing the temporary file.
]=]
function dirs.createTempFile(
	base: typeof(optionalAsPathType:type()),
	prefix: typeof(optionalStringType:type()),
	suffix: typeof(optionalStringType:type()),
	randomLength: typeof(optionalNumberType:type())
): pathfs.FilePath
	assert(optionalAsPathType(base))
	assert(optionalStringType(prefix))
	assert(optionalStringType(suffix))
	assert(optionalNumberType(randomLength))

	return pathfs.FilePath.fromExisting(createTemp(false, base, prefix, suffix, randomLength))
end

return dirs
