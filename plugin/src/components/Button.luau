local React = require(script.Parent.Parent.Parent.packages.react)
local useAppContext = require(script.Parent.Parent.context.AppContext).useAppContext

local e = React.createElement

export type Props = {}

local function Button()
	local context = useAppContext()
	local isHovering, setIsHovering = React.useState(false)

	local isConnected = context.connectionStatus.connected

	local function handleClick()
		if isConnected then
			context.handleDisconnect()
		else
			context.handleConnect()
		end
	end

	local function handleMouseEnter()
		setIsHovering(true)
	end

	local function handleMouseLeave()
		setIsHovering(false)
	end

	local baseColor = if isConnected then context.COLORS.buttonDisconnect else context.COLORS.buttonConnect
	local backgroundColor = if isHovering then context.COLORS.buttonHover else context.COLORS.buttonBackground

	return e("TextButton", {
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(120, 50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Text = "",
		[React.Event.Activated] = handleClick,
		[React.Event.MouseEnter] = handleMouseEnter,
		[React.Event.MouseLeave] = handleMouseLeave,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		Stroke = e("UIStroke", {
			Color = baseColor,
			Thickness = 1.5,
			Transparency = 0,
		}),
		Label = e("TextLabel", {
			Text = if isConnected then "DISCONNECT" else "CONNECT",
			TextColor3 = baseColor,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.Arcade,
			TextSize = 16,
			TextScaled = true,
		}, {
			TextSizeConstraint = e("UITextSizeConstraint", {
				MaxTextSize = 16,
				MinTextSize = 10,
			}),
			Gradient = e("UIGradient", {
				Color = if isConnected
					then ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 60, 65)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 40, 45)),
					})
					else ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 110)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 70)),
					}),
				Rotation = 90,
			}),
		}),
	})
end

return Button
