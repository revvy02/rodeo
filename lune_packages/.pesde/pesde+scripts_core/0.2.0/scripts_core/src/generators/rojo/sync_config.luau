local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

export type TreeProperties = {
	Name: never?,
	Parent: never?,
}

export type TreeBase = {
	["$className"]: string?,
	["$ignoreUnknownInstances"]: boolean?,
	["$path"]: string | { optional: string }?,
	["$properties"]: TreeProperties?,
}

export type TreeNormal = TreeBase & {
	[string]: TreeNormal,
} & ({ ["$className"]: string } | {
	["$path"]: string | { optional: string },
})

export type TreeService = TreeBase & {
	[string]: TreeNormal,
}

export type DataModelTree = TreeBase & {
	StarterPlayer: (TreeBase & {
		StarterPlayerScripts: TreeService?,
		StarterCharacterScripts: TreeService?,
		[string]: TreeNormal,
	})?,
	[string]: TreeService,
}

export type Tree =
	(DataModelTree & {
		["$className"]: "DataModel",
	})
	| TreeNormal

export type SyncConfig = {
	name: string,
	servePort: number?,
	servePlaceIds: { number }?,
	placeId: number?,
	gameId: number?,
	serveAddress: string?,
	globIgnorePaths: { string }?,
	tree: Tree,
}

local PLATFORM_SEP = if process.os == "windows" then "\\" else "/"
_G.interactive = false

--- Generates a Rojo sync configuration file (`default.project.json`) from a list of
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
	packageDirectory = packageDirectory or process.cwd
	local syncConfigPath =
		`{packageDirectory}{PLATFORM_SEP}default.project.json`
	if fs.isFile(syncConfigPath) and not options.force then
		return true, nil
	end

	local syncConfigTree = {} :: Tree

	for _, file in files do
		-- Remove the `.lua` or `.luau` file extension from the file name
		local name = string.gsub(file, ".luau?$", "")

		if name == "init" then
			syncConfigTree["$path"] = name
			continue
		end

		syncConfigTree[name] = {
			["$path"] = file,
		}
	end

	-- If there isn't a top level path, we mark the entire thing as a Folder
	if not syncConfigTree["$path"] then
		syncConfigTree["$className"] = "Folder"
	end

	-- If the config tree does not include pesde's downloaded roblox dependencies
	-- directory, we add it as an optional one for the future, once dependencies
	-- are installed
	if not syncConfigTree["roblox_packages"] then
		syncConfigTree["roblox_packages"] = {
			["$path"] = {
				optional = "roblox_packages",
			},
		}
	end

	-- If the config tree does not include pesde's downloaded roblox server dependencies
	-- directory, we add it as an optional one for the future, once server dependencies
	-- are installed
	if not syncConfigTree["roblox_server_packages"] then
		syncConfigTree["roblox_server_packages"] = {
			["$path"] = {
				optional = "roblox_server_packages",
			},
		}
	end

	-- Finally, we serialize the config to a JSON string and optionally write it
	-- to the sync config path
	local serializedConfig = serde.encode("json", {
		name = string.match(packageDirectory :: string, "[^\\/]+$"),
		tree = syncConfigTree,
	}, true)
	if options.writeToFile then
		fs.writeFile(syncConfigPath, serializedConfig)
	end

	return true, serializedConfig
end
