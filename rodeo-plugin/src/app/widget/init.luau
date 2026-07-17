local React = require("@pkg/react")

local AppContext = require(script.Parent.context.AppContext)
local Checkbox = require(script.Checkbox)
local Container = require(script.Container)
local Label = require(script.Label)
local RodeoLabel = require(script.RodeoLabel)
local Row = require(script.Row)
local StatusIndicator = require(script.StatusIndicator)
local constants = require(script.Parent.Parent.library.constants)

local AppProvider = AppContext.AppProvider
local useAppContext = AppContext.useAppContext

local COLORS = constants.COLORS

local e = React.createElement

export type Props = {
	plugin: Plugin,
	initialSettings: {
		port: number,
	},
}

-- Color for process state
local PROCESS_STATE_COLORS = {
	running = COLORS.executing,
	done = COLORS.success,
	error = COLORS.error,
	killed = COLORS.textDim,
}

-- Inner component that can use context
local function AppContent()
	local context = useAppContext()

	-- Build process list entries
	local processChildren = {}
	local processOrder = 0
	for eid, proc in pairs(context.activeProcesses) do
		processOrder += 1
		local stateColor = PROCESS_STATE_COLORS[proc.state] or COLORS.textDim
		local stateHex = stateColor:ToHex()
		processChildren[eid] = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = `{eid}  {proc.name}  <font color="#{stateHex}">{proc.state}</font>`,
			TextTruncate = Enum.TextTruncate.AtEnd,
			RichText = true,
			TextColor3 = COLORS.text,
			TextSize = 14,
			Font = Enum.Font.Arcade,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = processOrder,
		})
	end
	local hasProcesses = processOrder > 0

	return e(Container, {}, {
		-- Status indicator (always shown)
		Status = e(StatusIndicator),

		-- Process list (only when there are active processes)
		Processes = hasProcesses and e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Children = e(React.Fragment, nil, processChildren),
		}) or nil,

		-- Verbose toggle (the only remaining control; connection is automatic)
		VerboseRow = e(Row, {
			height = 30,
			layoutOrder = 5,
		}, {
			Label = e(Label, {
				text = "> Verbose",
				textColor = COLORS.accent,
			}),
			Checkbox = e(Checkbox, {
				checked = context.settings.verbose,
				strokeColor = COLORS.stroke,
				onToggle = function()
					context.setVerbose(not context.settings.verbose)
				end,
			}),
		}),

		-- Rodeo label (always shown)
		RodeoLabel = e(RodeoLabel),

		-- Version label (always shown, bottom-right)
		Version = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = `v{constants.VERSION}`,
			TextColor3 = COLORS.textDim,
			TextSize = 14,
			Font = Enum.Font.Arcade,
			TextXAlignment = Enum.TextXAlignment.Right,
			LayoutOrder = 99,
		}),
	})
end

local function App(props: Props)
	return e("Frame", {
		BackgroundColor3 = COLORS.background,
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, {
		Content = e(AppProvider, {
			plugin = props.plugin,
			initialSettings = props.initialSettings,
		}, e(AppContent)),
	})
end

return App
