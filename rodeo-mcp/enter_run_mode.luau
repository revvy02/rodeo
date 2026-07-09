--[[
    @rodeo run --mode edit --context plugin

    Enter run mode from the edit VM.
    Creates a server VM but no client VM.

    @rodeo annotations
    { "destructiveHint": true, "idempotentHint": false }
]]

task.spawn(game:GetService("StudioTestService").ExecuteRunModeAsync, game:GetService("StudioTestService"), true)
return nil
