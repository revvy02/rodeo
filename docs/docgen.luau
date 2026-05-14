-- Generate per-module markdown pages for the Luau surfaces, via lute's
-- built-in `lute doc`. Run from the repo root:
--   lute run docs/docgen.luau
--
-- Output lands at docs/src/content/docs/{api,runtime}/<module>.md.
-- Hand-written index.md per section is preserved (we keep the narrative).

local fs = require("@std/fs")
local process = require("@std/process")

-- Each entry: source dir (relative to repo root), destination dir,
-- lute's auto-generated package name (used to find the output subdir).
local SECTIONS = {
	{
		src = "rodeo-client-lune/src",
		dest = "docs/src/content/docs/api",
		luePkg = "rodeo-client-lune",
		sourceLabel = "rodeo-client-lune/src",
	},
	{
		src = "rodeo-pkg/src",
		dest = "docs/src/content/docs/runtime",
		luePkg = "rodeo-pkg",
		sourceLabel = "rodeo-pkg/src",
	},
}

local TMP = ".rodeo/.temp/luedoc"

local function sh(args: { string })
	local r = process.run(args)
	assert(r.ok, `{args[1]} failed (exit {r.exitcode}): {r.stderr}`)
end

-- Strip lute's stock ":::warning ... :::" callout — the README's Status
-- section already covers stability; surfacing it on every page is noise.
local function stripWarningCallout(content: string): string
	local pattern = ":::warning\n.-:::\n*"
	return (string.gsub(content, pattern, ""))
end

-- Starlight requires `title` frontmatter. lute doc emits `# <module>` as the
-- first line — promote that to frontmatter and drop the H1 so Starlight
-- renders the page title from the front-matter slot only.
local function injectFrontmatter(content: string, moduleName: string, sourcePath: string): string
	local without_h1 = (string.gsub(content, "^# [^\n]+\n+", ""))
	return string.format(
		"---\ntitle: %s\n---\n\n> _This page is auto-generated from `%s`._\n\n",
		moduleName, sourcePath
	) .. without_h1
end

sh({ "rm", "-rf", TMP })
sh({ "mkdir", "-p", TMP })

for _, section in SECTIONS do
	sh({ "mkdir", "-p", section.dest })
	-- Fresh lute doc output for this section.
	local sectionTmp = TMP .. "/" .. section.luePkg
	sh({ "rm", "-rf", sectionTmp })
	sh({ "lute", "doc", "--output", sectionTmp, section.src })

	-- Wipe stale generated pages in DEST (keep index.md = hand-written narrative).
	sh({ "find", section.dest, "-mindepth", "1", "-not", "-name", "index.md", "-delete" })

	local genDir = sectionTmp .. "/reference/" .. section.luePkg
	assert(fs.exists(genDir), `lute doc output not found at {genDir}`)

	for _, entry in fs.listDirectory(genDir) do
		if entry.type == "dir" then
			-- Skip subdirs — utility / _internal / examples / etc.
			print(`  skipping {entry.name}/`)
			continue
		end
		-- index.md from lute is a directory-summary autogen; we keep ours.
		if entry.name == "index.md" then
			print(`  skipping {entry.name} (hand-written narrative preserved)`)
			continue
		end
		local src = genDir .. "/" .. entry.name
		local dst = section.dest .. "/" .. entry.name
		local moduleName = (string.gsub(entry.name, "%.md$", ""))
		local content = fs.readFileToString(src)
		content = stripWarningCallout(content)
		content = injectFrontmatter(content, moduleName, section.sourceLabel .. "/" .. moduleName .. ".luau")
		fs.writeStringToFile(dst, content)
		print(`  generated {dst}`)
	end
end

print("Docgen complete.")
