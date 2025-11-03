-- Terminal color constants using ANSI escape codes

local COLORS = {
	Print = "",
	Info = "\27[36m", -- Cyan
	Warning = "\27[33m", -- Yellow
	Error = "\27[31m", -- Red
	Reset = "\27[0m",
}

return COLORS
