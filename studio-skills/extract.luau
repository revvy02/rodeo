--!strict
-- Extracts the Roblox Studio Assistant's built-in skills out of the shipped
-- Assistant plugin (Assistant.rbxm) into raw/ as a tree of plain .md files.
-- raw/ is the pristine reference; curated skills are hand-edited copies (see README).
--
-- The skills are stored as StringValues under
--   Assistant/Packages/_Index/AssistantSkills/AssistantSkills/<skill>/...
-- with this shape per skill:
--   SKILL            main skill doc (frontmatter + body)
--   SKILL-combined   convenience: SKILL + every command/spec concatenated
--   QuerySpecs/API_spec   reference data shapes (optional)
--   commands/<name>  sub-skill command docs (optional)
--
-- Usage (run from this directory):
--   lune run extract.luau                 -- autodetect Studio, write ./raw
--   lune run extract.luau <rbxm> <outdir>
--
-- No network, no Studio running required: reads the local install's bytes.
-- Re-run after a Studio update to refresh the reference, then diff against your
-- curated copies in .claude/skills/ and merge changes by hand.

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")

local CANDIDATES = {
	"/Applications/RobloxStudio.app/Contents/Resources/BuiltInStandalonePlugins/Packed/Assistant.rbxm",
	"/Applications/RobloxStudio.app/Contents/Resources/BuiltInStandalonePlugins/Optimized_Embedded_Signature/Assistant.rbxm",
}

local rbxmPath = process.args[1]
if not rbxmPath then
	for _, c in CANDIDATES do
		if fs.isFile(c) then
			rbxmPath = c
			break
		end
	end
end
assert(rbxmPath, "Assistant.rbxm not found in default locations; pass its path as arg 1")

local outDir = process.args[2] or "raw"

print("reading  " .. rbxmPath)
local model = roblox.deserializeModel(fs.readFile(rbxmPath))

-- Locate the inner registry folder: a Folder named "AssistantSkills" that
-- directly contains the known "rbx-debug" skill folder.
local registry: any = nil
local function findRegistry(inst: any)
	for _, c in inst:GetChildren() do
		if c.Name == "AssistantSkills" and c:FindFirstChild("rbx-debug") then
			registry = c
		end
		findRegistry(c)
	end
end
for _, root in model do
	findRegistry(root)
end
assert(registry, "AssistantSkills registry not found inside the rbxm")

if fs.isDir(outDir) then
	fs.removeDir(outDir)
end
fs.writeDir(outDir)

local fileCount = 0
local skillCount = 0
local function dump(inst: any, dir: string)
	for _, c in inst:GetChildren() do
		if c.ClassName == "Folder" then
			local sub = dir .. "/" .. c.Name
			fs.writeDir(sub)
			dump(c, sub)
		elseif c.ClassName == "StringValue" then
			fs.writeFile(dir .. "/" .. c.Name .. ".md", c.Value)
			fileCount += 1
			print(string.format("  %-58s %7d chars", dir .. "/" .. c.Name .. ".md", #c.Value))
		end
	end
end

for _, skillFolder in registry:GetChildren() do
	if skillFolder.ClassName == "Folder" then
		skillCount += 1
	end
end
dump(registry, outDir)

print(string.format("\nextracted %d skills (%d files) -> %s/", skillCount, fileCount, outDir))
