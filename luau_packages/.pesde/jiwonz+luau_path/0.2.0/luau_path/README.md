[![checks](https://github.com/seaofvoices/luau-path/actions/workflows/test.yml/badge.svg)](https://github.com/seaofvoices/luau-path/actions/workflows/test.yml)
![version](https://img.shields.io/github/package-json/v/seaofvoices/luau-path)
[![GitHub top language](https://img.shields.io/github/languages/top/seaofvoices/luau-path)](https://github.com/luau-lang/luau)
![license](https://img.shields.io/npm/l/luau-path)
![npm](https://img.shields.io/npm/dt/luau-path)

# luau-path

A Luau library to handle file paths based on the Rust [path](https://doc.rust-lang.org/std/path/struct.Path.html) library.

The library can be configured to use unix or windows style separator using the global variable `SYS_PATH_SEPARATOR`. The global should be defined to `'/'` or `'\'`.

When the global is not defined, it will default to `'/'`. If a `LUA_ENV` global variable is set to [`lune`](https://github.com/lune-org/lune), the path separator will be inferred from lune's [process](https://lune-org.github.io/docs/api-reference/process#os) built-in library.

## Installation

Add `luau-path` in your dependencies:

```bash
yarn add luau-path
```

Or if you are using `npm`:

```bash
npm install luau-path
```

## Content

This libary exports a `Path` class and the [`AsPath` type](#aspath-type).

```lua
local PathModule = require('@pkg/luau-path')

local Path = PathModule.Path

type Path = PathModule.Path
type AsPath = PathModule.AsPath
```

Constructors:

- [Path.new](#pathnew)
- [Path.from](#pathfrom)

Static functions:

- [Path.is](#pathis)

Path methods:

- [ancestors](#ancestors)
- [clear](#clear)
- [components](#components)
- [endsWith](#endswith)
- [equal](#equal)
- [extension](#extension)
- [fileName](#filename)
- [filePrefix](#fileprefix)
- [fileStem](#filestem)
- [hasRoot](#hasroot)
- [isAbsolute](#isabsolute)
- [isRelative](#isrelative)
- [join](#join)
- [parent](#parent)
- [pop](#pop)
- [push](#push)
- [setExtension](#setextension)
- [setFileName](#setfilename)
- [startsWith](#startswith)
- [stripPrefix](#stripprefix)
- [toPathBuf](#topathbuf)
- [toString](#tostring)
- [withFileName](#withfilename)
- [withExtension](#withextension)

## AsPath Type

```lua
type AsPath = string | Path | Components
```

### Path.new

```lua
function Path.new(path: string): Path
```

Creates a new path from the given `string`.

### Path.from

```lua
function Path.from(path: AsPath): Path
```

Creates a new path from a `string `or a [`Components`](#components) iterator, or return the given Path object.

This function errors if the value does not satisfy the `AsPath` type.

### Path.is

```lua
function Path.new(value: unknown): boolean
```

Returns `true` if the given value is a Path.

### toString

```lua
function Path:toString(): string
```

Converts the path to a string representation.

### toPathBuf

```lua
function Path:toPathBuf(): Path
```

Creates a new `Path` object that is a copy of the current path.

### isAbsolute

```lua
function Path:isAbsolute(): boolean
```

Returns true if the Path is absolute, i.e., if it is independent of the current directory.

- On Unix, a path is absolute if it starts with the root, so `isAbsolute` and [`hasRoot`](#hasroot) are equivalent.
- On Windows, a path is absolute if it has a prefix and starts with the root: `c:\windows` is absolute, while `c:temp` and `\temp` are not.

### isRelative

```lua
function Path:isRelative(): boolean
```

Returns `true` if the Path is relative, i.e., not absolute.

See [isAbsolute](#isabsolute)'s documentation for more details.

Examples

```lua
assert(Path.new("foo.txt"):isRelative())
```

### hasRoot

```lua
function Path:hasRoot(): boolean
```

Returns `true` if the Path has a root.

- On Unix, a path has a root if it begins with `/`.
- On Windows, a path has a root if it:
  - has no prefix and begins with a separator, e.g., `\windows`
  - has a prefix followed by a separator, e.g., `c:\windows` but not `c:windows`
  - has any non-disk prefix, e.g., `\\server\share`

Examples

```lua
assert(Path.new("/etc/passwd"):hasRoot())
```

### parent

```lua
function Path:parent(): Path?
```

Returns the Path without its final component, if there is one.

This means it returns `""` for relative paths with one component.

Returns `nil` if the path terminates in a root or prefix, or if it’s the empty string.

### ancestors

```lua
function Path:ancestors(): Ancestors
```

Produces an iterator over Path and its ancestors.

The iterator will yield the Path that is returned if the parent method is used zero or more times. That means, the iterator will yield `self`, `self:parent()`, `self:parent():parent()` and so on. If the parent method returns `nil`, the iterator will do likewise. The iterator will always yield at least one value, namely `self`.

### fileName

```lua
function Path:fileName(): string?
```

Returns the final component of the Path, if there is one.

If the path is a normal file, this is the file name. If it’s the path of a directory, this is the directory name.

Returns `nil` if the path terminates in `..`.

### stripPrefix

```lua
function Path:stripPrefix(base: AsPath): Path?
```

Returns a path that, when joined onto base, yields self.

If base is not a prefix of self (i.e., [startsWith](#startswith) returns `false`), returns `nil`.

### startsWith

```lua
function Path:startsWith(base: AsPath): boolean
```

Determines whether `base` is a prefix of `self`.

Only considers whole path components to match.

### endsWith

```lua
function Path:endsWith(child: AsPath): boolean
```

Determines whether `child` is a suffix of `self`.

Only considers whole path components to match.

### fileStem

```lua
function Path:fileStem(): string?
```

Extracts the stem (non-extension) portion of `self:fileName()`.

The stem is:

- `nil`, if there is no file name;
- The entire file name if there is no embedded `.`;
- The entire file name if the file name begins with `.` and has no other `.`s within;
- Otherwise, the portion of the file name before the final `.`

_See Also_

This method is similar to [`filePrefix`](#fileprefix), which extracts the portion of the file name before the _first_ `.`

### filePrefix

```lua
function Path:filePrefix(): string?
```

Extracts the prefix of `self:fileName()`.

The prefix is:

- `nil`, if there is no file name;
- The entire file name if there is no embedded `.`;
- The portion of the file name before the first non-beginning `.`;
- The entire file name if the file name begins with `.` and has no other `.`s within;
- The portion of the file name before the second `.` if the file name begins with `.`

_See Also_

This method is similar to [`fileStem`](#filestem), which extracts the portion of the file name before the _last_ `.`

### extension

```lua
function Path:extension(): string?
```

Extracts the extension (without the leading dot) of `self:fileName()`, if possible.

The extension is:

- `nil`, if there is no file name;
- `nil`, if there is no embedded `.`;
- `nil`, if the file name begins with `.` and has no other `.`s within;
- Otherwise, the portion of the file name after the final `.`

### join

```lua
function Path:join(path: AsPath): Path
```

Creates a new Path with `path` adjoined to self.

If path is absolute, it replaces the current path.

See [`push`](#push) for more details on what it means to adjoin a path.

### withFileName

```lua
function Path:withFileName(fileName: string): Path
```

Creates a new Path like `self` but with the given file name.

See [`setFileName`](#setfilename) for more details.

### withExtension

```lua
function Path:withExtension(extension: string): Path
```

Creates a new Path like `self` but with the given extension.

See [`setExtension`](#setextension) for more details.

### components

```lua
function Path:components(): Components
```

Produces an iterator over the Components of the path.

When parsing the path, there is a small amount of normalization:

- Repeated separators are ignored, so a/b and a//b both have a and b as components.
- Occurrences of . are normalized away, except if they are at the beginning of the path. For example, a/./b, a/b/, a/b/. and a/b all have a and b as components, but ./a/b starts with an additional CurDir component.
- A trailing slash is normalized away, /a/b and /a/b/ are equivalent.

Note that no other normalization takes place; in particular, `a/c` and `a/b/../c` are distinct, to account for the possibility that `b` is a symbolic link (so its parent isn't `a`).

### equal

```lua
function Path:equal(other: Path): boolean
```

Returns `true` if the current path is equal to the other path.

### push

```lua
function Path:push(path: AsPath): ()
```

Extends `self` with `path`.

If `path` is absolute, it replaces the current path.

On Windows:

- if `path` has a root but no prefix (e.g., `\windows`), it replaces everything except for the prefix (if any) of self.
- if `path` has a prefix but no root, it replaces `self`.
- if `self` has a verbatim prefix (e.g. `\\?\C:\windows`) and `path` is not empty, the new path is normalized: all references to `.` and `..` are removed.

Consider using [`join`](#join) if you need a new Path instead of using this function on a cloned Path.

### pop

```lua
function Path:pop(): boolean
```

Truncates `self` to `self:parent()`.

Returns `false` and does nothing if `self:parent()` is `nil`. Otherwise, returns `true`.

### setFileName

```lua
function Path:setFileName(fileName: string): ()
```

Updates `self:fileName()` to `fileName`.

If `self:fileName()` was `nil`, this is equivalent to pushing `fileName`.

Otherwise it is equivalent to calling [`pop`](#pop) and then pushing `fileName`. The new path will be a sibling of the original path. (That is, it will have the same parent.)

### setExtension

```lua
function Path:setExtension(extension: string): boolean
```

Updates `self:extension()` to `extension` or to `nil` if `extension` is empty.

Returns `false` and does nothing if `self:fileName()` is `nil`, returns `true` and updates the extension otherwise.

If `self:extension()` is `nil`, the extension is added; otherwise it is replaced.

If extension is the empty string, `self:extension()` will be None afterwards, not `""`.

**Caveats**

The new extension may contain dots and will be used in its entirety, but only the part after the final dot will be reflected in `self:extension()`.

If the file stem contains internal dots and extension is empty, part of the old file stem will be considered the new `self:extension()`.

### clear

```lua
function Path:clear(): ()
```

Clears the path, making it an empty path.

## License

This project is available under the MIT license. See [LICENSE.txt](LICENSE.txt) for details.

## Other Lua Environments Support

If you would like to use this library on a Lua environment, where it is currently incompatible, open an issue (or comment on an existing one) to request the appropriate modifications.

The library uses [darklua](https://github.com/seaofvoices/darklua) to process its code.
