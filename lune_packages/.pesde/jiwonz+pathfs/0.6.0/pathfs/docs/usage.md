# Basic Usage
```lua
local pathfs = require("../lune_packages/pathfs")
local fs = pathfs.fs -- compat with lune's fs lib (@lune/fs)

fs.writeFile("something.json", "{ \"message\": \"Hello, world!\" }")

-- Using Path
local Path = pathfs.Path
local path = Path.from("something.json")

print(fs.readFile(path))

-- Some useful utilities
pathfs.script()
pathfs.normalize("./dirty/./path")
pathfs.absolute("relative/file/path")
pathfs.withoutCurDir("./to/remove/curdir/the/dot")
pathfs.diff("target", "base")
pathfs.findFile("path/to/file")
pathfs.findDir("path/to/dir")
pathfs.watchFile("path/to/file", function()
	print("changed")
end)
pathfs.watchDirectories({ "dir1", "dir2" }, function()
	print("changed")
end)
pathfs.writeFileAll("a/b/c/d/lol", "hi")
```

## More Examples
More example codes can be found in [examples folder in the repo](https://github.com/jiwonz/lune-pathfs/tree/main/examples)
