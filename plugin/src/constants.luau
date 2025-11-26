-- Shared constants for rodeo plugins

return {
	SERVE_PORT = 44872,
	ONCE_PORT = 44873,

	-- Bit positions for run context bitset
	CONTEXT_BITS = {
		isStudio = 0,
		isServer = 1,
		isClient = 2,
		isEdit = 3,
		isRunning = 4,
	},

	-- UI Colors for arcade design - Rodeo red theme
	COLORS = {
		-- Backgrounds - dark with subtle red tint
		background = Color3.fromRGB(12, 5, 6),
		backgroundLight = Color3.fromRGB(20, 10, 12),

		-- Text - red/pink tones
		text = Color3.fromRGB(255, 150, 160),
		textDim = Color3.fromRGB(180, 100, 110),

		-- Accents - vibrant crimson (logo red)
		accent = Color3.fromRGB(255, 70, 80),
		accentHover = Color3.fromRGB(255, 100, 110),

		-- Status colors - green for connection status, red for disconnected
		success = Color3.fromRGB(140, 220, 100),
		error = Color3.fromRGB(220, 80, 90),

		-- Button colors - bright crimson for connect, vibrant red-orange for disconnect
		buttonConnect = Color3.fromRGB(255, 70, 80),
		buttonDisconnect = Color3.fromRGB(255, 90, 70),

		-- Component-specific
		buttonBackground = Color3.fromRGB(35, 20, 22),
		buttonHover = Color3.fromRGB(45, 28, 30),
		border = Color3.fromRGB(120, 60, 65),
		inputBackground = Color3.fromRGB(20, 12, 14),
		stroke = Color3.fromRGB(200, 90, 100),
	},
}
