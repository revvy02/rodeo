--[[
    @rodeo run --mode test --context server

    Exit play/run test mode.

    @rodeo annotations
    { "destructiveHint": true, "idempotentHint": true }
]]

game:GetService("StudioTestService"):EndTest("end_test")
return nil
