local Path = require('@self/Path')
local types = require("@self/types")

export type Path = types.Path
export type AsPath = types.AsPath

return {
    Path = (Path :: any) :: {
		new: (path: string) -> types.Path,
		from: (path: types.AsPath) -> types.Path,
		is: (value: unknown) -> boolean,
	},
}
