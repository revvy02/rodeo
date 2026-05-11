--[[
    @rodeo run --target test:server

    Exit play/run test mode.
]]

game:GetService("StudioTestService"):EndTest("end_test")
return nil
