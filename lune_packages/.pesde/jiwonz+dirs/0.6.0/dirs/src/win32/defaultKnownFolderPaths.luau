local KNOWNFOLDERID = require("./KNOWNFOLDERID")

local defaultKnownFolderPaths = {} :: { [string]: { string } | string }

-- if default path is table, you should check their element paths all
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_Desktop] = "%USERPROFILE%\\Desktop"
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_Documents] = "%USERPROFILE%\\Documents"
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_Downloads] = "%USERPROFILE%\\Downloads"
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_LocalAppData] = { "%LOCALAPPDATA%", "%USERPROFILE%\\AppData\\Local" }
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_Music] = "%USERPROFILE%\\Music"
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_Pictures] = "%USERPROFILE%\\Pictures"
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_Profile] = { "%USERPROFILE%", "%SystemDrive%\\Users\\%USERNAME%" }
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_Public] = { "%PUBLIC%", "%SystemDrive%\\Users\\Public" }
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_RoamingAppData] = { "%APPDATA%", "%USERPROFILE%\\AppData\\Roaming" }
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_Templates] = "%APPDATA%\\Microsoft\\Windows\\Templates"
defaultKnownFolderPaths[KNOWNFOLDERID.FOLDERID_Videos] = "%USERPROFILE%\\Videos"

return defaultKnownFolderPaths
