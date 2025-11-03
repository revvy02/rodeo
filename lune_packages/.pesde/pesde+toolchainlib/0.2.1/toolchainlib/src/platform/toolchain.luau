local Option = require("../../lune_packages/option")
type Option<T> = Option.Option<T>

local TOOLCHAINS: { Toolchain } = { "msvc", "gnu", "musl" }
export type Toolchain = "msvc" | "gnu" | "musl"

return {
	detect = function(str: string): Option<Toolchain>
		for _, toolchain: Toolchain in TOOLCHAINS do
			if string.find(str, toolchain) then
				return Option.Some(toolchain :: Toolchain)
			end
		end

		return Option.None :: Option<Toolchain>
	end,
}
