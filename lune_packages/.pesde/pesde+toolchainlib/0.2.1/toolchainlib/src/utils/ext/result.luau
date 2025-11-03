--> Non-exhaustive set of extensions for the `Result<T, E>` type

local Option = require("../../../lune_packages/option")
local Result = require("../../../lune_packages/result")

local ResultExt = {}

function ResultExt.ok<T, E>(self: Result.Result<T, E>): Option.Option<T>
	return self:mapOr(Option.None, function(val: T)
		return Option.Some(val)
	end) :: Option.Option<T>
end

return ResultExt
