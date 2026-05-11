--[[
    @rodeo run --target edit:plugin

    Enter play test mode from the edit VM.
    Waits for server and client VMs to connect.
]]

task.spawn(game:GetService("StudioTestService").ExecutePlayModeAsync, game:GetService("StudioTestService"), true)
return nil
