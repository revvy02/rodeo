-- Generate per-module markdown pages for the Luau API surface, via lute's
-- built-in `lute doc`. Run from the repo root:
--   lute run docs/docgen.luau
--
-- Output lands at docs/src/content/docs/api/<module>.md. Hand-written
-- narrative at docs/src/content/docs/api/index.md is not touched.

local fs = require("@std/fs")
local process = require("@std/process")

local SRC = "rodeo-client-lune/src"
local DEST = "docs/src/content/docs/api"
local TMP = ".rodeo/.temp/luedoc"

local function sh(args: { string })
	local r = process.run(args)
	assert(r.ok, `{args[1]} failed (exit {r.exitcode}): {r.stderr}`)
end

-- Strip lute's stock ":::warning ... :::" callout — the repo's README and
-- Status section already cover stability; surfacing it on every page is noise.
local function stripWarningCallout(content: string): string
	local pattern = ":::warning\n.-:::\n*"
	return (string.gsub(content, pattern, ""))
end

-- Starlight requires `title` frontmatter. lute doc emits `# <module>` as the
-- first line — promote that to frontmatter and drop the H1 so Starlight
-- renders the page title from the front-matter slot only.
local function injectFrontmatter(content: string, moduleName: string): string
	local without_h1 = (string.gsub(content, "^# [^\n]+\n+", ""))
	return string.format(
		"---\ntitle: %s\n---\n\n> _This page is auto-generated from `rodeo-client-lune/src/%s.luau`._\n\n",
		moduleName, moduleName
	) .. without_h1
end

-- Fresh lute doc output → temp dir → flatten into DEST.
sh({ "rm", "-rf", TMP })
sh({ "mkdir", "-p", TMP, DEST })

-- Wipe stale generated pages in DEST (keep index.md = hand-written narrative).
sh({ "find", DEST, "-mindepth", "1", "-not", "-name", "index.md", "-delete" })
sh({ "lute", "doc", "--output", TMP, SRC })

local genDir = TMP .. "/reference/rodeo-client-lune"
assert(fs.exists(genDir), `lute doc output not found at {genDir}`)

for _, entry in fs.listDirectory(genDir) do
	if entry.type == "dir" then
		print(`skipping {entry.name}/`)
		continue
	end
	-- index.md from lute is a directory-summary autogen; we keep our hand-written one.
	if entry.name == "index.md" then
		print(`skipping {entry.name} (hand-written narrative preserved)`)
		continue
	end
	local src = genDir .. "/" .. entry.name
	local dst = DEST .. "/" .. entry.name
	local moduleName = (string.gsub(entry.name, "%.md$", ""))
	local content = fs.readFileToString(src)
	content = stripWarningCallout(content)
	content = injectFrontmatter(content, moduleName)
	fs.writeStringToFile(dst, content)
	print(`generated {dst}`)
end

print("Luau API docgen complete.")
