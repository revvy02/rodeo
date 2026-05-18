-- Generate per-module markdown pages for the Luau surfaces, via lute's
-- built-in `lute doc`. Run from the repo root:
--   lute run docs/docgen.luau
--
-- Output lands at docs/src/content/docs/{api,runtime}/<...>.md, mirroring
-- the source-tree layout: subdirectories in the source become subdirectories
-- here, so Starlight's `autogenerate` produces nested sidebar entries
-- (same shape as lute's own docs).

local fs = require("@std/fs")
local process = require("@std/process")

-- Each entry: source dir (relative to repo root), destination dir, and
-- lute's auto-generated package name (used to find the output subdir).
local SECTIONS = {
	{
		src = "rodeo-client-lune/src",
		dest = "docs/src/content/docs/api",
		luePkg = "rodeo-client-lune",
	},
	{
		src = "rodeo-pkg/rodeo/src",
		dest = "docs/src/content/docs/runtime",
		luePkg = "rodeo",
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
local function injectFrontmatter(content: string, moduleName: string): string
	local without_h1 = (string.gsub(content, "^# [^\n]+\n+", ""))
	return string.format("---\ntitle: %s\n---\n\n", moduleName) .. without_h1
end

-- Recursively copy lute's output tree into the Starlight content tree,
-- transforming each .md file along the way (frontmatter + strip warning).
local function copyTree(srcDir: string, dstDir: string)
	sh({ "mkdir", "-p", dstDir })
	for _, entry in fs.listDirectory(srcDir) do
		local from = srcDir .. "/" .. entry.name
		local to = dstDir .. "/" .. entry.name
		if entry.type == "dir" then
			-- Skip directories whose names start with `_` (e.g. `_internal/`).
			-- Convention: anything underscore-prefixed is implementation detail.
			if string.sub(entry.name, 1, 1) == "_" then
				print(`  skipping {entry.name}/ (underscore-prefixed = internal)`)
				continue
			end
			-- Recurse — preserves subdir structure so sidebar autogenerate
			-- produces nested groups (e.g. api/util/{base64,uuid}.md).
			copyTree(from, to)
		elseif entry.name == "index.md" then
			-- lute emits a directory-summary index.md per dir. We don't
			-- want it — sidebar autogenerate handles nesting on its own.
			print(`  skipping index.md (lute directory summary)`)
		else
			local moduleName = (string.gsub(entry.name, "%.md$", ""))
			local content = fs.readFileToString(from)
			content = stripWarningCallout(content)
			content = injectFrontmatter(content, moduleName)
			fs.writeStringToFile(to, content)
			print(`  generated {to}`)
		end
	end
end

sh({ "rm", "-rf", TMP })
sh({ "mkdir", "-p", TMP })

for _, section in SECTIONS do
	sh({ "mkdir", "-p", section.dest })
	-- Fresh lute doc output for this section.
	local sectionTmp = TMP .. "/" .. section.luePkg
	sh({ "rm", "-rf", sectionTmp })
	sh({ "lute", "doc", "--output", sectionTmp, section.src })

	-- Wipe stale generated pages in DEST entirely (no index.md to preserve
	-- now that the narrative landings are gone — sidebar autogenerate is the
	-- single source for the section structure).
	sh({ "rm", "-rf", section.dest })

	local genDir = sectionTmp .. "/reference/" .. section.luePkg
	assert(fs.exists(genDir), `lute doc output not found at {genDir}`)

	copyTree(genDir, section.dest)
end

print("Docgen complete.")
