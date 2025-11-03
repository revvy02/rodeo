export type SPDXLicense =
	"MIT"
	| "Apache-2.0"
	| "BSD-2-Clause"
	| "BSD-3-Clause"
	| "GPL-2.0"
	| "GPL-3.0"
	| "LGPL-2.1"
	| "LGPL-3.0"
	| "MPL-2.0"
	| "ISC"
	| "Unlicense"
	| "WTFPL"
	| "Zlib"
	| "CC0-1.0"
	| "CC-BY-4.0"
	| "CC-BY-SA-4.0"
	| "BSL-1.0"
	| "EPL-2.0"
	| "AGPL-3.0"

export type DependencySpecifier = ((
	{ name: string, version: string, index: string? }
	| { workspace: string, version: string }
	| { repo: string, rev: string, path: string? }
) & {
	target: string?,
}) | { wally: string, version: string, index: string? }

export type PackageTarget =
	{
		environment: "luau" | "lune" | "roblox" | "roblox_server",
		lib: string,
	}
	| {
		environment: "luau" | "lune",
		bin: string,
	}

export type PesdeManifest = {
	name: string,
	version: string,
	description: string?,
	license: SPDXLicense?,
	authors: { string }?,
	repository: string?,
	private: boolean?,
	includes: { string }?,
	pesde_version: string?,
	workspace_members: { string }?,
	target: PackageTarget,
	build_files: { string }?,
	scripts: { [string]: string }?,
	indices: { [string]: string },
	wally_indices: { [string]: string }?,
	overrides: { [string]: DependencySpecifier }?,
	patches: { [string]: { [string]: string } }?,
	place: { [string]: string }?,
	dependencies: { [string]: DependencySpecifier }?,
	peer_dependencies: { [string]: DependencySpecifier }?,
	dev_dependencies: { [string]: DependencySpecifier }?,
}

return "<manifest>"
