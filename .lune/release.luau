-- Stage the version sources together before building/committing/tagging a release.
-- Usage: lune run release 1.5.0-rc.8
-- The plugin/build ID derives from Cargo.toml; Cargo.lock regenerates on build,
-- and the Lune package version derives from the release tag in CI.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local version = assert(process.args[1], "usage: lune run release <semver>")
assert(version:match("^%d+%.%d+%.%d+$") or version:match("^%d+%.%d+%.%d+%-[%w%.%-]+$"), "invalid release version")
local manifestPath, skillPath = "rodeo-cli/Cargo.toml", ".claude/skills/rodeo/SKILL.md"
local manifest, skill = fs.readFile(manifestPath), fs.readFile(skillPath)
local previous = serde.decode("toml", manifest).package.version
local count
manifest, count = manifest:gsub('(\nversion = ")[^"\n]+(")', function(a, b)
	return a .. version .. b
end, 1)
assert(count == 1, "missing CLI version")
local frontmatter, body = skill:match("^(%-%-%-\n.-\n%-%-%-\n)(.*)$")
assert(frontmatter, "missing skill frontmatter")
frontmatter, count = frontmatter:gsub("(\n  version:%s*)[^%s]+", function(a)
	return a .. version
end)
assert(count == 1, "missing or duplicated skill version stamp")
body, count = body:gsub("(This skill describes rodeo %*%*)[^*]+(%*%*)", function(a, b)
	return a .. version .. b
end)
assert(count == 1, "missing or duplicated skill body version")
-- Validate every replacement before writing either source.
fs.writeFile(manifestPath, manifest)
fs.writeFile(skillPath, frontmatter .. body)
print(`Staged rodeo {previous} -> {version}. Run lune run build, then commit and tag v{version}.`)
