export type Roblox = {
	load: (path: string) -> { Instance },
}

local rodeo = require("./")
return (rodeo :: any).roblox :: Roblox
