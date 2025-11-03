--> Non-exhaustive set of extensions for the `Option<T>` type

local Option = require("../../../lune_packages/option")
local Result = require("../../../lune_packages/result")

local OptionExt = {}

function OptionExt.okOr<T, E>(self: Option.Option<T>, err: E): Result.Result<T, E>
	return self:mapOrElse(function()
		return Result.Err(err)
	end, function(val)
		return Result.Ok(val)
	end) :: Result.Result<T, E>
end

return OptionExt
