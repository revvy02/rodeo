local Component = require("./Component")
local Components = require("./Components")
local Prefix = require("./Prefix")

type Component = Component.Component
type Components = Components.Components
type Prefix = Prefix.Prefix

export type Ancestors = {
    -- Iterator
    next: (self: Ancestors) -> Path?,
    collect: (self: Ancestors) -> { Path },
}

export type AsPath = string | Path | Components

export type Path = {
    toString: (self: Path) -> string,

    toPathBuf: (self: Path) -> Path,
    isAbsolute: (self: Path) -> boolean,
    isRelative: (self: Path) -> boolean,
    hasRoot: (self: Path) -> boolean,
    parent: (self: Path) -> Path?,
    ancestors: (self: Path) -> Ancestors,
    fileName: (self: Path) -> string?,
    stripPrefix: (self: Path, base: AsPath) -> Path?,
    startsWith: (self: Path, base: AsPath) -> boolean,
    endsWith: (self: Path, child: AsPath) -> boolean,

    fileStem: (self: Path) -> string?,
    filePrefix: (self: Path) -> string?,
    extension: (self: Path) -> string?,
    join: (self: Path, path: AsPath) -> Path,

    withFileName: (self: Path, fileName: string) -> Path,
    withExtension: (self: Path, extension: string) -> Path,
    components: (self: Path) -> Components,

    equal: (self: Path, other: Path) -> boolean,

    -- PathBuf
    push: (self: Path, path: AsPath) -> (),
    pop: (self: Path) -> boolean,
    setFileName: (self: Path, fileName: string) -> (),
    setExtension: (self: Path, extension: string) -> boolean,
    clear: (self: Path) -> (),
}

return nil
