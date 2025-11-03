return {
	generators = {
		rojo = {
			sourcemap = require("@self/generators/rojo/sourcemap"),
			syncConfig = require("@self/generators/rojo/sync_config"),
		},

		argon = {
			sourcemap = require("@self/generators/argon/sourcemap"),
			syncConfig = require("@self/generators/argon/sync_config"),
		},
	},
}
