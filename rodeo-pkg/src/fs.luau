-- Filesystem operations available inside Studio scripts.
-- Bundled require: `local fs = require("@rodeo/fs")`.

local singleton = require("./_internal/singleton")
local shared = require("./_internal/types")

export type Fs = {
	open: (path: string, mode: string?) -> shared.StreamHandle,
	remove: (path: string) -> (),
	stat: (path: string) -> shared.FileMetadata,
	type: (path: string) -> string,
	mkdir: (path: string) -> (),
	exists: (path: string) -> boolean,
	copy: (src: string, dest: string) -> (),
	listdir: (path: string) -> { shared.DirectoryEntry },
	rmdir: (path: string) -> (),
}

return (singleton :: any).fs :: Fs
