--!strict

local terminal = {}

export type TableConfig = {
	justify_left: { number }?,
	justify_right: { number }?,
	justify_center: { number }?,
	margin_left: { number }?,
	margin_right: { number }?,
}

export type FormatTree = {
	text: string,
	children: { FormatTree }?,
}

---------------------------------------------------------------------
-- ANSI STYLE (colors, bold, underline)
---------------------------------------------------------------------

local ANSI = {
	RESET = "\27[0m",
	BOLD = "\27[1m",
	UNDERLINE = "\27[4m",
	WHITE = "\27[37m",
	GREEN = "\27[32m",
	RED = "\27[31m",
	YELLOW = "\27[33m",
	BLUE = "\27[34m",
	MAGENTA = "\27[35m",
	CYAN = "\27[36m",
	GRAY = "\27[90m",
	ORANGE = "\27[38;5;208m",
}

local function make_style(code: string)
	return function(s: string)
		return code .. s .. ANSI.RESET
	end
end

terminal.style = {
	white_underline = function(s: string)
		return ANSI.BOLD .. ANSI.UNDERLINE .. s .. ANSI.RESET
	end,
	white = make_style(ANSI.WHITE),
	green = make_style(ANSI.GREEN),
	red = make_style(ANSI.RED),
	yellow = make_style(ANSI.YELLOW),
	blue = make_style(ANSI.BLUE),
	magenta = make_style(ANSI.MAGENTA),
	cyan = make_style(ANSI.CYAN),
	gray = make_style(ANSI.GRAY),
	orange = make_style(ANSI.ORANGE),
	-- Composable bold
	bold = function(s: string)
		return ANSI.BOLD .. s .. ANSI.RESET
	end,
	white_bold = function(s: string)
		return ANSI.BOLD .. ANSI.WHITE .. s .. ANSI.RESET
	end,
}

---------------------------------------------------------------------
-- ANSI detection (ROBUST)
---------------------------------------------------------------------

local ANSI_PATTERN = "\27%[[0-9;?]*[A-Za-z]"

---------------------------------------------------------------------
-- UTF-8 iteration
---------------------------------------------------------------------

local function utf8_iter(str: string): () -> string?
	local i = 1
	local n = #str
	return function()
		if i > n then
			return nil
		end
		local c = str:byte(i)
		local len
		if c < 0x80 then
			len = 1
		elseif c < 0xE0 then
			len = 2
		elseif c < 0xF0 then
			len = 3
		else
			len = 4
		end
		local bytes = str:sub(i, i + len - 1)
		i += len
		return bytes
	end
end

---------------------------------------------------------------------
-- UTF-8 → Codepoint
---------------------------------------------------------------------

local function utf8_codepoint(utf8char: string): number
	local b1, b2, b3, b4 = utf8char:byte(1, #utf8char)
	if not b2 then
		return b1
	end
	if not b3 then
		return (b1 % 32) * 64 + (b2 % 64)
	end
	if not b4 then
		return (b1 % 16) * 4096 + (b2 % 64) * 64 + (b3 % 64)
	end
	return (b1 % 8) * 262144 + (b2 % 64) * 4096 + (b3 % 64) * 64 + (b4 % 64)
end

---------------------------------------------------------------------
-- wcwidth (full terminal width correctness)
---------------------------------------------------------------------

local combining = {
	{ 0x0300, 0x036F },
	{ 0x1AB0, 0x1AFF },
	{ 0x1DC0, 0x1DFF },
	{ 0x20D0, 0x20FF },
	{ 0xFE20, 0xFE2F },
}

local function is_combining(cp: number): boolean
	for _, r in combining do
		if cp >= r[1] and cp <= r[2] then
			return true
		end
	end
	return false
end

local function is_wide(cp: number): boolean
	if
		(cp >= 0x1100 and cp <= 0x115F)
		or (cp >= 0x2E80 and cp <= 0xA4CF)
		or (cp >= 0xAC00 and cp <= 0xD7A3)
		or (cp >= 0xF900 and cp <= 0xFAFF)
		or (cp >= 0xFE10 and cp <= 0xFE19)
		or (cp >= 0xFE30 and cp <= 0xFE6F)
		or (cp >= 0x1F300 and cp <= 0x1FAFF)
	then
		return true
	end
	return false
end

local function wcwidth(cp: number): number
	if cp == 0 then
		return 0
	end
	if is_combining(cp) then
		return 0
	end
	if is_wide(cp) then
		return 2
	end
	return 1
end

---------------------------------------------------------------------
-- Compute visible width (ANSI-removed + UTF-8 wcwidth)
---------------------------------------------------------------------

local function visual_width(str: string): number
	-- PRE strip ANSI
	str = str:gsub(ANSI_PATTERN, "")

	local width = 0
	for ch in utf8_iter(str) do
		width += wcwidth(utf8_codepoint(ch))
	end
	return width
end

---------------------------------------------------------------------
-- Pad a string to a target display width (ANSI safe)
---------------------------------------------------------------------

local function pad_ansi(str: string, target: number, align: string)
	local vis = visual_width(str)
	local diff = target - vis
	if diff <= 0 then
		return str
	end

	if align == "right" then
		return string.rep(" ", diff) .. str
	elseif align == "center" then
		local left = math.floor(diff / 2)
		local right = diff - left
		return string.rep(" ", left) .. str .. string.rep(" ", right)
	else
		return str .. string.rep(" ", diff)
	end
end

---------------------------------------------------------------------
-- MAIN TABLE RENDERER
---------------------------------------------------------------------

function terminal.format_table(rows: { { string } }, config: TableConfig?): string
	if #rows == 0 then
		return ""
	end

	local results = terminal.format_table_batch({ rows }, config)
	return results[1]
end

---------------------------------------------------------------------
-- BATCH TABLE RENDERER (aligned across multiple tables)
---------------------------------------------------------------------

function terminal.format_table_batch(batch: { { { string } } }, config: TableConfig?): { string }
	if #batch == 0 then
		return {}
	end

	local cfg = config or {} :: TableConfig

	-- Build alignment lookup sets
	local align_left = {}
	local align_right = {}
	local align_center = {}

	if cfg.justify_left then
		for _, c in cfg.justify_left do
			align_left[c] = true
		end
	end
	if cfg.justify_right then
		for _, c in cfg.justify_right do
			align_right[c] = true
		end
	end
	if cfg.justify_center then
		for _, c in cfg.justify_center do
			align_center[c] = true
		end
	end

	-- Determine number of columns across ALL tables
	local num_cols = 0
	for _, rows in batch do
		for _, row in rows do
			if #row > num_cols then
				num_cols = #row
			end
		end
	end

	-- Column width calculation across ALL tables
	local col_widths = table.create(num_cols, 0)
	for _, rows in batch do
		for _, row in rows do
			for col_idx = 1, num_cols do
				local cell = row[col_idx] or ""
				local w = visual_width(cell)
				if w > col_widths[col_idx] then
					col_widths[col_idx] = w
				end
			end
		end
	end

	-- Render each table separately with shared column widths
	local results = {}

	for _, rows in batch do
		local out = {}

		for _, row in rows do
			local parts = table.create(num_cols)

			for col_idx = 1, num_cols do
				local cell = row[col_idx] or ""

				-- alignment
				local align = "left"
				if align_right[col_idx] then
					align = "right"
				elseif align_center[col_idx] then
					align = "center"
				elseif align_left[col_idx] then
					align = "left"
				end

				-- margins
				local ml = (cfg.margin_left and cfg.margin_left[col_idx]) or 0
				local mr = (cfg.margin_right and cfg.margin_right[col_idx]) or 0

				local with_margins = string.rep(" ", ml) .. cell .. string.rep(" ", mr)

				local padded = pad_ansi(with_margins, col_widths[col_idx] + ml + mr, align)
				parts[col_idx] = padded
			end

			table.insert(out :: any, table.concat(parts))
		end

		table.insert(results, table.concat(out, "\n"))
	end

	return results
end

---------------------------------------------------------------------
-- SCALED VALUE FORMATTER
---------------------------------------------------------------------

export type ScaleThreshold = {
	threshold: number,
	scale: number,
	prefix: string,
	color: (string) -> string,
}

function terminal.format_scaled_value(value: number, unit: string, scale_thresholds: { ScaleThreshold }, precision: number?): string
	local prec = precision or 2
	local abs_value = math.abs(value)

	for _, scale_info in scale_thresholds do
		if abs_value >= scale_info.threshold then
			local scaled_value = value / scale_info.scale
			local styled_unit = scale_info.color(scale_info.prefix .. unit)
			return string.format(`%.{prec}f %s` :: any, scaled_value, styled_unit)
		end
	end

	return string.format(`%.{prec}f %s` :: any, value, unit)
end

function terminal.format_scaled_value_plain(value: number, unit: string, scale_thresholds: { ScaleThreshold }, precision: number?): (string, string)
	local prec = precision or 2
	local abs_value = math.abs(value)

	for _, scale_info in scale_thresholds do
		if abs_value >= scale_info.threshold then
			local scaled_value = value / scale_info.scale
			return string.format(`%.{prec}f` :: any, scaled_value), scale_info.prefix .. unit
		end
	end

	return string.format(`%.{prec}f` :: any, value), unit
end

function terminal.get_scale_color(value: number, scale_thresholds: { ScaleThreshold }): (string) -> string
	local abs_value = math.abs(value)

	for _, scale_info in scale_thresholds do
		if abs_value >= scale_info.threshold then
			return scale_info.color
		end
	end

	return terminal.style.green -- default
end

---------------------------------------------------------------------
-- TREE RENDERER
---------------------------------------------------------------------

local function populate_format_tree_lines(nodes: { FormatTree }, prefix: string, lines: { string })
	for i, node in nodes do
		local is_last = i == #nodes
		local branch = is_last and "└── " or "├── "
		local continuation = is_last and "    " or "│   "

		table.insert(lines, prefix .. terminal.style.gray(branch) .. node.text)

		if node.children then
			populate_format_tree_lines(node.children, prefix .. terminal.style.gray(continuation), lines)
		end
	end
end

function terminal.format_tree(nodes: { FormatTree }): string
	local lines = {}
	populate_format_tree_lines(nodes, "", lines)
	return table.concat(lines, "\n")
end

return terminal
