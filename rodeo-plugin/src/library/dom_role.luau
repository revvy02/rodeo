--!strict
-- Which part this DOM's plugin plays in the RODEO_UNIFIER exchange, derived
-- from RunService's flags. Pure: no Roblox globals, so it runs under lune
-- (tests-new/plugin/dom_role.spec.luau) as well as in Studio.

export type Flags = {
	isEdit: boolean,
	isServer: boolean,
	isClient: boolean,
}

export type DomKind = "edit" | "server" | "client"

export type Role = {
	-- Creates ReplicatedStorage.RODEO_UNIFIER when missing.
	hosts: boolean,
	-- Owns the server side of the unifier's RemoteEvent (collects play-client
	-- dom ids). Only a real play server: the edit DOM has no play peers, and
	-- in a Team Create session OnServerEvent throws there ("can only be used
	-- on the server") because the edit DataModel is a network client.
	serves: boolean,
	-- Waits for a host's unifier to replicate in and registers itself over
	-- the RemoteEvent as a play client.
	joins: boolean,
	domKind: DomKind,
}

-- The DOM that is authoritative for its own DataModel hosts; only a client
-- of a real play server joins. Network role alone can't tell these apart:
-- a plain edit DataModel reports server+client, but in a Team Create session
-- the edit DataModel is a network client of Roblox's Team Create server —
-- IsServer() false, IsClient() true — and that server runs nobody's plugins,
-- so nothing else would ever create the unifier (issue #18). IsEdit() is true
-- for the edit DOM either way, so it decides first.
local function derive(flags: Flags): Role
	local hosts = flags.isEdit or flags.isServer
	local serves = flags.isServer and not flags.isEdit
	local joins = flags.isClient and not hosts
	local domKind: DomKind = if flags.isEdit
		then "edit"
		elseif flags.isServer then "server"
		else "client"
	return {
		hosts = hosts,
		serves = serves,
		joins = joins,
		domKind = domKind,
	}
end

return {
	derive = derive,
}
