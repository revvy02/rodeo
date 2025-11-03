local pathfs = require("../lune_packages/pathfs")

export type Sys = {
	homeDir: () -> pathfs.Path?,
	cacheDir: () -> pathfs.Path?,
	configDir: () -> pathfs.Path?,
	configLocalDir: () -> pathfs.Path?,
	dataDir: () -> pathfs.Path?,
	dataLocalDir: () -> pathfs.Path?,
	executableDir: () -> pathfs.Path?,
	preferenceDir: () -> pathfs.Path?,
	runtimeDir: () -> pathfs.Path?,
	stateDir: () -> pathfs.Path?,
	audioDir: () -> pathfs.Path?,
	desktopDir: () -> pathfs.Path?,
	documentDir: () -> pathfs.Path?,
	downloadDir: () -> pathfs.Path?,
	fontDir: () -> pathfs.Path?,
	pictureDir: () -> pathfs.Path?,
	publicDir: () -> pathfs.Path?,
	templateDir: () -> pathfs.Path?,
	videoDir: () -> pathfs.Path?,
}

return nil
