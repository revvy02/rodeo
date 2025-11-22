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
}
