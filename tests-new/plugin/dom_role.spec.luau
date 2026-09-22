--!strict
-- Unit spec for rodeo-plugin/src/library/dom_role.luau, run under lune by
-- tests-new/plugin/domRole.test.ts. Each case is the RunService flag triple a
-- real DOM reports; the expected role is the one that keeps every DOM of a
-- Studio announcing itself.
local dom_role = require("../../rodeo-plugin/src/library/dom_role")

type Case = {
	name: string,
	flags: dom_role.Flags,
	expect: dom_role.Role,
}

local cases: { Case } = {
	{
		-- Plain edit DataModel: standalone, reports both network roles.
		name = "edit DOM (plain place)",
		flags = { isEdit = true, isServer = true, isClient = true },
		expect = { hosts = true, serves = false, joins = false, domKind = "edit" },
	},
	{
		-- Team Create edit DataModel: a network client of Roblox's Team Create
		-- server, which runs no plugins. Nothing else will ever create the
		-- unifier, so the edit DOM must still host (issue #18). It must not
		-- serve: OnServerEvent throws in a network-client DataModel.
		name = "edit DOM (Team Create place)",
		flags = { isEdit = true, isServer = false, isClient = true },
		expect = { hosts = true, serves = false, joins = false, domKind = "edit" },
	},
	{
		-- Play server: solo (in-process) or a multiplayer-test server process.
		name = "play server DOM",
		flags = { isEdit = false, isServer = true, isClient = false },
		expect = { hosts = true, serves = true, joins = false, domKind = "server" },
	},
	{
		-- Play client: solo or a multiplayer-test client process.
		name = "play client DOM",
		flags = { isEdit = false, isServer = false, isClient = true },
		expect = { hosts = false, serves = false, joins = true, domKind = "client" },
	},
}

local failures = 0
for _, case in cases do
	local got = dom_role.derive(case.flags)
	for _, key in { "hosts", "serves", "joins", "domKind" } do
		local want = (case.expect :: any)[key]
		local have = (got :: any)[key]
		if want ~= have then
			failures += 1
			print(`FAIL {case.name}: {key} = {tostring(have)}, want {tostring(want)}`)
		end
	end
end

if failures > 0 then
	error(`{failures} assertion(s) failed`)
end
print(`ok: {#cases} cases`)
