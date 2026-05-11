-- Public io API — requires rodeo to be initialized via rodeo.init()
local rodeo = require("./")
return (rodeo :: any).io :: rodeo.Io
