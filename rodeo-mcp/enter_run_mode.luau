--[[
    @rodeo run --target edit:plugin

    Enter run mode from the edit VM.
    Creates a server VM but no client VM.
]]

task.spawn(game:GetService("StudioTestService").ExecuteRunModeAsync, game:GetService("StudioTestService"), true)
return nil
