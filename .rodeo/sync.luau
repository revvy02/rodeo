--[[
    potential rojo improvements (look into argon as precedent)
    - fix the WorldPivotData problem
    - figure out how to allow syncback for duplicate files 
        (possibly have a manifest file for mapping file names to instance names)
    - fix touch interest deletion/creation (possibly generalize this for similar instance types)

    - add collapsing/expanding rbxms

    - handle edge cases with referential props when expanding/collapsing via the manifest file,
        - where u try to collapse a nested file with referential props to something outside of that subtree,
        - need to maintain this and similar cases via the manifest file

    - this can all be exposed via rodeo api
]]

local rbx = require("@rodeo/rbx")

-- loads asset path in as instance
local instance = rbx.import("path/to/asset")

-- exports instance to path in fs
rbx.export(instance, "path/to/asset.rbxm")

-- should work identical to rojo syncback but live instead of from the file
rbx.syncback("path/to/default.project.json")

-- starts syncing project json path to game
-- do we want two way sync?
rbx.sync("path/to/default.project.json", {
	twoWay = true,
})

-- expands rbxm/rbxmx into files
rbx.expand("path/to/asset.rbxm")

-- collapses files back into rbxm
rbx.collapse("path/to/asset")
