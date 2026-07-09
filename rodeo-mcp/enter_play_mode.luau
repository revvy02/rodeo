--[[
    @rodeo run --mode edit --context plugin

    Enter play test mode from the edit VM.
    Waits for server and client VMs to connect.

    @rodeo annotations
    { "destructiveHint": true, "idempotentHint": false }
]]

task.spawn(game:GetService("StudioTestService").ExecutePlayModeAsync, game:GetService("StudioTestService"), true)
return nil
