return {
	-- Suffix used to rename modules during uncacheable require traversal
	IGNORE_SUFFIX = ".rodeo.ignore.",

	-- Rodeo version, injected at build time by darklua (inject_global_value).
	VERSION = RODEO_VERSION,

	-- Default connection settings. The static plugin auto-connects to the
	-- studio backend's WebSocket on this port (= rodeo-cli's SERVE_PORT + 1;
	-- keep in sync with rodeo-cli/src/util/config.rs::SERVE_PORT). A rodeo
	-- launch overrides the port via the `rodeoPort` workspace attribute (set
	-- by the RunScript bootstrap) and supplies its session via `rodeoSession`.
	DEFAULT_HOST = "localhost",
	DEFAULT_PORT = 44873,
	DEFAULT_AUTO_CONNECT = true,
	VERBOSE = false,

	-- Bit positions for context bitset
	-- Order: Server, Client, Running, Edit, Studio
	CONTEXT_BITS = {
		isServer = 0,
		isClient = 1,
		isRunning = 2,
		isEdit = 3,
		isStudio = 4,
	},

	-- UI Colors for arcade design - Rodeo red theme
	COLORS = {
		-- Backgrounds - dark with subtle red tint
		background = Color3.fromRGB(8, 6, 5),
		backgroundLight = Color3.fromRGB(20, 10, 12),

		-- Text - red/pink tones
		text = Color3.fromRGB(255, 150, 160),
		textDim = Color3.fromRGB(180, 100, 110),

		-- Accents - vibrant crimson (logo red)
		accent = Color3.fromRGB(255, 70, 80),
		accentHover = Color3.fromRGB(255, 100, 110),

		-- Status colors - green for connected, red for disconnected, yellow for executing
		success = Color3.fromRGB(140, 220, 100),
		error = Color3.fromRGB(220, 80, 90),
		executing = Color3.fromRGB(255, 200, 50),

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
