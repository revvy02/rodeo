-- Public fs API — requires rodeo to be initialized via rodeo.init()
local rodeo = require("./")
return (rodeo :: any).fs :: rodeo.Fs
