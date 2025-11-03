local rojoSyncConfig = require("../rojo/sync_config")

export type TreeProperties = rojoSyncConfig.TreeProperties
export type TreeBase = rojoSyncConfig.TreeBase
export type TreeNormal = rojoSyncConfig.TreeNormal
export type TreeService = rojoSyncConfig.TreeService
export type DataModelTree = rojoSyncConfig.DataModelTree
export type Tree = rojoSyncConfig.Tree
export type SyncConfig = rojoSyncConfig.SyncConfig

_G.interactive = false

--- Generates an Argon sync configuration file (`default.project.json`) from a list of
--- input files to be included.

--- ## Errors
--- * The current process lacks permissions to a file
--- * Any I/O error occurs
return function(
	packageDirectory: string?,
	files: { string },
	options: {
		writeToFile: boolean?,
		force: boolean?,
	}
): (boolean, string?)
	-- Purely alias to the Rojo sync config generator, since Argon uses the same
	-- config format
	return rojoSyncConfig(packageDirectory, files, options)
end
