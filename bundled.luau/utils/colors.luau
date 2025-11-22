type StyLer__DARKLUA_TYPE_a = typeof(setmetatable({} :: {
    open: string,
    close: string,
}, {} :: {
    __call: (self: StyLer__DARKLUA_TYPE_a, str: string) -> (string),
    __concat: (self: StyLer__DARKLUA_TYPE_a, other: { 
        open: string, 
        close: string 
    }) -> (StyLer__DARKLUA_TYPE_a),
}))

type CreateStyler__DARKLUA_TYPE_b = (open: string, close: string) -> ()

type Chalk__DARKLUA_TYPE_c = typeof(setmetatable({} :: {
    level: number,
    reset: StyLer__DARKLUA_TYPE_a,
    bold: StyLer__DARKLUA_TYPE_a,
    dim: StyLer__DARKLUA_TYPE_a,
    italic: StyLer__DARKLUA_TYPE_a,
    underline: StyLer__DARKLUA_TYPE_a,
    overline: StyLer__DARKLUA_TYPE_a,
    inverse: StyLer__DARKLUA_TYPE_a,
    hidden: StyLer__DARKLUA_TYPE_a,
    strikethrough: StyLer__DARKLUA_TYPE_a,
    black: StyLer__DARKLUA_TYPE_a,
    red: StyLer__DARKLUA_TYPE_a,
    green: StyLer__DARKLUA_TYPE_a,
    yellow: StyLer__DARKLUA_TYPE_a,
    blue: StyLer__DARKLUA_TYPE_a,
    magenta: StyLer__DARKLUA_TYPE_a,
    cyan: StyLer__DARKLUA_TYPE_a,
    white: StyLer__DARKLUA_TYPE_a,
    blackBright: StyLer__DARKLUA_TYPE_a,
    gray: StyLer__DARKLUA_TYPE_a,
    grey: StyLer__DARKLUA_TYPE_a,
    redBright: StyLer__DARKLUA_TYPE_a,
    greenBright: StyLer__DARKLUA_TYPE_a,
    yellowBright: StyLer__DARKLUA_TYPE_a,
    blueBright: StyLer__DARKLUA_TYPE_a,
    magentaBright: StyLer__DARKLUA_TYPE_a,
    cyanBright: StyLer__DARKLUA_TYPE_a,
    whiteBright: StyLer__DARKLUA_TYPE_a,
    bgBlack: StyLer__DARKLUA_TYPE_a,
    bgRed: StyLer__DARKLUA_TYPE_a,
    bgGreen: StyLer__DARKLUA_TYPE_a,
    bgYellow: StyLer__DARKLUA_TYPE_a,
    bgBlue: StyLer__DARKLUA_TYPE_a,
    bgMagenta: StyLer__DARKLUA_TYPE_a,
    bgCyan: StyLer__DARKLUA_TYPE_a,
    bgWhite: StyLer__DARKLUA_TYPE_a,
    bgBlackBright: StyLer__DARKLUA_TYPE_a,
    bgGray: StyLer__DARKLUA_TYPE_a,
    bgGrey: StyLer__DARKLUA_TYPE_a,
    bgRedBright: StyLer__DARKLUA_TYPE_a,
    bgGreenBright: StyLer__DARKLUA_TYPE_a,
    bgYellowBright: StyLer__DARKLUA_TYPE_a,
    bgBlueBright: StyLer__DARKLUA_TYPE_a,
    bgMagentaBright: StyLer__DARKLUA_TYPE_a,
    bgCyanBright: StyLer__DARKLUA_TYPE_a,
    bgWhiteBright: StyLer__DARKLUA_TYPE_a,

    rgb: (red: number, green: number, blue: number) -> StyLer__DARKLUA_TYPE_a,
    bgRgb: (red: number, green: number, blue: number) -> StyLer__DARKLUA_TYPE_a,

    hex: (hex: string) -> StyLer__DARKLUA_TYPE_a,
    bgHex: (hex: string) -> StyLer__DARKLUA_TYPE_a,

    ansi: (ansi: number) -> StyLer__DARKLUA_TYPE_a,
    bgAnsi: (ansi: number) -> StyLer__DARKLUA_TYPE_a,
    ansi256: (ansi: number) -> StyLer__DARKLUA_TYPE_a,
    bgAnsi256: (ansi: number) -> StyLer__DARKLUA_TYPE_a,
}, {} :: {
    __call: (_: any, str: string) -> (string),
}))

type StyLer__DARKLUA_TYPE_d = StyLer__DARKLUA_TYPE_a
type Chalk__DARKLUA_TYPE_e = Chalk__DARKLUA_TYPE_c
type StyLer__DARKLUA_TYPE_f  = StyLer__DARKLUA_TYPE_d
type Chalk__DARKLUA_TYPE_g  = Chalk__DARKLUA_TYPE_e local __DARKLUA_BUNDLE_MODULES={cache={}::any}do do local function __modImpl()--!nocheck
-- ROBLOX NOTE: inline stringReplaceAll to keep ChalkLua as one file

local function stringReplaceAll(string_, substring, replacer)
	local index = string.find(string_, substring, 1, true)
	if index == nil then
		return string_
	end
	local substringLength = #substring
	local endIndex = 1
	local returnValue = ""
	repeat
		returnValue ..= string.sub(string_, endIndex, index - 1) .. substring .. replacer
		endIndex = index + substringLength
		index = string.find(string_, substring, endIndex, true)
	until not (index ~= nil)
	returnValue ..= string.sub(string_, endIndex)
	return returnValue
end

-- ROBLOX NOTE: inline stringEncaseCRLFWithFirstIndex to keep ChalkLua as one file
local function stringEncaseCRLFWithFirstIndex(string_, prefix, postfix, index)
	local endIndex = 1
	local returnValue = ""
	repeat
		local gotCR = string.sub(string_, index - 1, index - 1) == "\r"
		returnValue ..= string.sub(string_, endIndex, if gotCR then index - 2 else index - 1) .. prefix .. (if gotCR
			then "\r\n"
			else "\n") .. postfix
		endIndex = index + 1
		index = string.find(string_, "\n", endIndex)
	until not (index ~= nil)
	returnValue ..= string.sub(string_, endIndex)
	return returnValue
end

local ansiStyles = {
	modifier = {
		reset = { 0, 0 },
		bold = { 1, 22 },
		dim = { 2, 22 },
		italic = { 3, 23 },
		underline = { 4, 24 },
		overline = { 53, 55 },
		inverse = { 7, 27 },
		hidden = { 8, 28 },
		strikethrough = { 9, 29 },
	},

	color = {
		black = { 30, 39 },
		red = { 31, 39 },
		green = { 32, 39 },
		yellow = { 33, 39 },
		blue = { 34, 39 },
		magenta = { 35, 39 },
		cyan = { 36, 39 },
		white = { 37, 39 },

		-- bright color
		blackBright = { 90, 39 },
		gray = { 90, 39 },
		grey = { 90, 39 },
		redBright = { 91, 39 },
		greenBright = { 92, 39 },
		yellowBright = { 93, 39 },
		blueBright = { 94, 39 },
		magentaBright = { 95, 39 },
		cyanBright = { 96, 39 },
		whiteBright = { 97, 39 },
	},

	bgColor = {
		bgBlack = { 40, 49 },
		bgRed = { 41, 49 },
		bgGreen = { 42, 49 },
		bgYellow = { 43, 49 },
		bgBlue = { 44, 49 },
		bgMagenta = { 45, 49 },
		bgCyan = { 46, 49 },
		bgWhite = { 47, 49 },

		-- bright color
		bgBlackBright = { 100, 49 },
		bgGray = { 100, 49 },
		bgGrey = { 100, 49 },
		bgRedBright = { 101, 49 },
		bgGreenBright = { 102, 49 },
		bgYellowBright = { 103, 49 },
		bgBlueBright = { 104, 49 },
		bgMagentaBright = { 105, 49 },
		bgCyanBright = { 106, 49 },
		bgWhiteBright = { 107, 49 },
	},
}

local ansi16 = "%c[%dm"
local ansi256 = "%c[%d;5;%dm"
local ESC = 27
local ANSI_SET_FOREGROUND = 38
local ANSI_SET_BACKGROUND = 48

local styles = {}

for groupName, group in pairs(ansiStyles) do
	for styleName, style in pairs(group) do
		styles[styleName] = {
			open = string.format(ansi16, ESC, style[1]),
			close = string.format(ansi16, ESC, style[2]),
		}
	end
end

local createStyler
local applyStyle

local function compositeStyler(style, otherStyle)
	return createStyler(style.open .. otherStyle.open, otherStyle.close .. style.close)
end

local Chalk = { level = 2 }
if _G.LUA_ENV == "roblox" then
	-- Ansi colors are not supported in Roblox, so set level to 0.
	Chalk.level = 0
end

setmetatable(Chalk, {
	__call = function(_, str)
		if str == nil or type(str) == "string" and #str == 0 then
			return ""
		end
		return tostring(str)
	end,
})

function createStyler(open, close)
	local styler = {
		open = open,
		close = close,
	}

	setmetatable(styler, {
		__call = function(self, str)
			return applyStyle(self, str)
		end,
		__concat = function(self, other)
			return compositeStyler(self, other)
		end,
	})

	return styler
end

function applyStyle(self, str)
	if str == nil or type(str) == "string" and #str == 0 then
		return ""
	end
	if Chalk.level == 0 then
		return tostring(str)
	end

	local styler = self

	local openAll, closeAll = styler.open, styler.close
	if string.match(str, "\u{001B}") then
		-- ROBLOX deviation START: no parent styles support yet
		-- Replace any instances already present with a re-opening code
		-- otherwise only the part of the string until said closing code
		-- will be colored, and the rest will simply be 'plain'.
		str = stringReplaceAll(str, styler.close, styler.open)
		-- ROBLOX deviation END
	end

	-- We can move both next actions out of loop, because remaining actions in loop won't have
	-- any/visible effect on parts we add here. Close the styling before a linebreak and reopen
	-- after next line to fix a bleed issue on macOS: https://github.com/chalk/chalk/pull/92
	local lfIndex = string.find(str, "\n")
	if lfIndex ~= nil then
		str = stringEncaseCRLFWithFirstIndex(str, closeAll, openAll, lfIndex)
	end

	return self.open .. tostring(str) .. self.close
end

local function noStyle()
	return createStyler("", "")
end

local close = string.format(ansi16, ESC, 39)
local bgClose = string.format(ansi16, ESC, 49)
local reset = string.format(ansi16, ESC, 0)

for styleName, style in pairs(styles) do
	Chalk[styleName] = createStyler(style.open, style.close)
end

Chalk["reset"] = createStyler(reset, reset)

local function rgbToAnsi256(red, green, blue)
	if red == green and green == blue then
		if red < 8 then
			return 16
		end
		if red > 248 then
			return 231
		end

		return math.round((((red - 8) / 247) * 24) + 232)
	end

	local ansi = 16
		+ (36 * math.round(red / 255 * 5))
		+ (6 * math.round(green / 255 * 5))
		+ math.round(blue / 255 * 5)
	return ansi
end

Chalk["rgb"] = function(red, green, blue)
	if
		type(red) ~= "number"
		or type(green) ~= "number"
		or type(blue) ~= "number"
		or red > 255
		or red < 0
		or green > 255
		or green < 0
		or blue > 255
		or blue < 0
	then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_FOREGROUND, rgbToAnsi256(red, green, blue))
	return createStyler(open, close)
end

Chalk["bgRgb"] = function(red, green, blue)
	if
		type(red) ~= "number"
		or type(green) ~= "number"
		or type(blue) ~= "number"
		or red > 255
		or red < 0
		or green > 255
		or green < 0
		or blue > 255
		or blue < 0
	then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_BACKGROUND, rgbToAnsi256(red, green, blue))
	return createStyler(open, bgClose)
end

local function hexToRgb(hex)
	local red = tonumber(string.sub(hex, 2, 3), 16)
	local blue = tonumber(string.sub(hex, 4, 5), 16)
	local green = tonumber(string.sub(hex, 6, 7), 16)

	return rgbToAnsi256(red, blue, green)
end

Chalk["hex"] = function(hex)
	if type(hex) ~= "string" or string.find(hex, "#%X") ~= nil or #hex ~= 7 then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_FOREGROUND, hexToRgb(hex))
	return createStyler(open, close)
end

Chalk["bgHex"] = function(hex)
	if type(hex) ~= "string" or string.find(hex, "#%X") ~= nil or #hex ~= 7 then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_BACKGROUND, hexToRgb(hex))
	return createStyler(open, bgClose)
end

Chalk["ansi"] = function(ansi)
	if type(ansi) ~= "number" or ansi < 30 or (ansi > 37 and ansi < 90) or ansi > 97 then
		return noStyle()
	end
	local open = string.format(ansi16, ESC, ansi)
	return createStyler(open, close)
end

Chalk["bgAnsi"] = function(ansi)
	if type(ansi) ~= "number" or ansi < 40 or (ansi > 47 and ansi < 100) or ansi > 107 then
		return noStyle()
	end
	local open = string.format(ansi16, ESC, ansi)
	return createStyler(open, bgClose)
end

Chalk["ansi256"] = function(ansi)
	if type(ansi) ~= "number" or ansi < 0 or ansi > 255 then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_FOREGROUND, ansi)
	return createStyler(open, close)
end

Chalk["bgAnsi256"] = function(ansi)
	if type(ansi) ~= "number" or ansi < 0 or ansi > 255 then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_BACKGROUND, ansi)
	return createStyler(open, bgClose)
end

return Chalk
end function __DARKLUA_BUNDLE_MODULES.a():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a=v end return v.c end end do local function __modImpl()











































































return {}end function __DARKLUA_BUNDLE_MODULES.b():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.b if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.b=v end return v.c end end do local function __modImpl()
local chalk = __DARKLUA_BUNDLE_MODULES.a()
local type = __DARKLUA_BUNDLE_MODULES.b()


return chalk :: Chalk__DARKLUA_TYPE_c end function __DARKLUA_BUNDLE_MODULES.c():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.c if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.c=v end return v.c end end do local function __modImpl()
local module = __DARKLUA_BUNDLE_MODULES.c()


return module end function __DARKLUA_BUNDLE_MODULES.d():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.d if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.d=v end return v.c end end end-- Centralized color definitions for consistent styling across the codebase

local chalk = __DARKLUA_BUNDLE_MODULES.d()

-- Define custom colors using RGB for better saturation/control
local ERROR_RED = chalk.rgb(200, 0, 0) -- Deep saturated red
local WARNING_ORANGE = chalk.rgb(255, 140, 0) -- Orange color for warnings

-- Export color functions with appropriate modifiers
local colors = {
	error = (chalk.bold .. ERROR_RED),
	warning = (chalk.bold .. WARNING_ORANGE),
	info = chalk.cyan,
	success = chalk.green,
	grey = chalk.grey,
	cyan = chalk.cyan,
}

-- Output level color mapping for execution results
colors.levelColors = {
	Print = function(s)
		return s
	end,
	Info = colors.info,
	Warning = colors.warning,
	Error = colors.error,
}

return colors
