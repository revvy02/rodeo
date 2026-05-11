--[[
    How this works:

    Plugins will spawn for every VM
    We use studio MCP to execute luau to fire bindables + remotes to disperse the studio ID
]]

--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Static (never change for this VM's lifetime)
local isServer = RunService:IsServer()
local isClient = RunService:IsClient()

-- RODEO_UNIFIER: cross-VM identity exchange
local RODEO_UNIFIER: Folder
local RODEO_UNIFIER_REMOTE: RemoteEvent
local RODEO_UNIFIER_BINDABLE: BindableEvent
local RODEO_UNIFIER_MODULE: ModuleScript

if isServer then
	RODEO_UNIFIER = ReplicatedStorage:FindFirstChild("RODEO_UNIFIER") :: Folder
	if not RODEO_UNIFIER then
		RODEO_UNIFIER = Instance.new("Folder")
		RODEO_UNIFIER.Name = "RODEO_UNIFIER"
		RODEO_UNIFIER.Parent = ReplicatedStorage
	end

	RODEO_UNIFIER_REMOTE = RODEO_UNIFIER:FindFirstChild("RemoteEvent") :: RemoteEvent
	if not RODEO_UNIFIER_REMOTE then
		RODEO_UNIFIER_REMOTE = Instance.new("RemoteEvent")
		RODEO_UNIFIER_REMOTE.Name = "RemoteEvent"
		RODEO_UNIFIER_REMOTE.Parent = RODEO_UNIFIER
	end

	RODEO_UNIFIER_BINDABLE = RODEO_UNIFIER:FindFirstChild("BindableEvent") :: BindableEvent
	if not RODEO_UNIFIER_BINDABLE then
		RODEO_UNIFIER_BINDABLE = Instance.new("BindableEvent")
		RODEO_UNIFIER_BINDABLE.Name = "BindableEvent"
		RODEO_UNIFIER_BINDABLE.Parent = RODEO_UNIFIER
	end

	RODEO_UNIFIER_MODULE = RODEO_UNIFIER:FindFirstChild("ModuleScript") :: ModuleScript
	if not RODEO_UNIFIER_MODULE then
		RODEO_UNIFIER_MODULE = Instance.new("ModuleScript")
		RODEO_UNIFIER_MODULE.Source = "return game:GetService('HttpService'):GenerateGUID(false)"
		RODEO_UNIFIER_MODULE.Name = "ModuleScript"
		RODEO_UNIFIER_MODULE.Parent = RODEO_UNIFIER
	end
elseif isClient then
	RODEO_UNIFIER = ReplicatedStorage:WaitForChild("RODEO_UNIFIER") :: Folder
	RODEO_UNIFIER_REMOTE = RODEO_UNIFIER:WaitForChild("RemoteEvent") :: RemoteEvent
	RODEO_UNIFIER_BINDABLE = RODEO_UNIFIER:WaitForChild("BindableEvent") :: BindableEvent
	RODEO_UNIFIER_MODULE = RODEO_UNIFIER:WaitForChild("ModuleScript") :: ModuleScript
end

local vmId = require(RODEO_UNIFIER_MODULE)

-- Inputs: mutable values updated by events. The Heartbeat reads these to compute state.
-- `*mcpStudioId*` values are StudioMCP's own ids (propagated via the RODEO_UNIFIER
-- event channels by rodeo-cli's reconciliation loop). They are NOT the canonical
-- master-assigned studio_id — that's tracked server-side.
local inputs = {
	-- From BindableEvent (MCP → edit/server VM)
	bindableMcpStudioId = nil :: string?,
	-- From RemoteEvent (cross-VM)
	serverVmId = nil :: string?,
	serverMcpStudioId = nil :: string?,
	clientVmIds = {} :: { [string]: Player },
	clientMcpStudioIds = {} :: { [string]: Player },
	-- Players
	players = {} :: { [Player]: boolean },
}

-- Current state (replaced immutably on change)
local currentState: State? = nil

export type State = {
	vmId: string,
	-- StudioMCP's assigned id for this Studio (set via reconciliation).
	-- Distinct from the master-assigned canonical studio_id, which is tracked
	-- server-side and not known to the plugin.
	mcpStudioId: string?,

	isServer: boolean,
	isClient: boolean,
	isRunning: boolean,
	isEdit: boolean,

	mode: "edit" | "run" | "test" | "play",
	dom: "edit" | "server" | "client",

	gameName: string,
	placeId: number,
	gameId: number,

	clientInfo: {
		name: string,
		userId: number,
	}?,

	clientVmIds: { [string]: {
		name: string,
		userId: number,
	} }?,
}

-- Compute a fresh state from current inputs + RunService
local function computeState(): State
	local isRunning = RunService:IsRunning()
	local isEdit = RunService:IsEdit()
	local isRunMode = RunService:IsRunMode()

	local clientMcpStudioId = if isClient then inputs.bindableMcpStudioId else next(inputs.clientMcpStudioIds)
	local serverMcpStudioId = inputs.serverMcpStudioId or clientMcpStudioId or inputs.bindableMcpStudioId

	-- Defaults to "play" when MCP studio IDs haven't been resolved via reconciliation.
	-- StudioMCP currently can't execute Luau in StartServer/StartClient windows,
	-- so play mode processes never get MCP studio IDs — defaulting to "play" is correct.
	-- For single-process test mode, MCP reconciliation sets matching MCP IDs
	-- and mode corrects from "play" to "test". When StudioMCP adds support for
	-- play DataModels, reconciliation will set different IDs and mode resolves
	-- to "play" through the explicit check instead of the default.
	local mode: "edit" | "run" | "test" | "play" = if isEdit
		then "edit"
		elseif isRunMode then "run"
		elseif serverMcpStudioId and clientMcpStudioId and serverMcpStudioId == clientMcpStudioId then "test"
		else "play"

	local clientVmIds = nil
	if isServer then
		local ids = {}
		for id, player in inputs.clientVmIds do
			ids[id] = {
				name = player.Name,
				userId = player.UserId,
			}
		end
		clientVmIds = ids
	end

	local dom: "edit" | "server" | "client" = if isClient and isServer
		then "edit"
		elseif isServer then "server"
		else "client"

	return {
		vmId = vmId,
		mcpStudioId = if isClient then clientMcpStudioId else serverMcpStudioId,

		isServer = isServer,
		isClient = isClient,
		isRunning = isRunning,
		isEdit = isEdit,

		mode = mode,
		dom = dom,

		gameName = game.Name,
		placeId = game.PlaceId,
		gameId = game.GameId,

		clientInfo = if isClient and Players.LocalPlayer
			then {
				name = Players.LocalPlayer.Name,
				userId = Players.LocalPlayer.UserId,
			}
			else nil,

		clientVmIds = clientVmIds,
	}
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, (b :: any)[k]) then
			return false
		end
	end
	for k in b do
		if (a :: any)[k] == nil then
			return false
		end
	end
	return true
end

local function stateChanged(a: State?, b: State): boolean
	if a == nil then
		return true
	end
	return not deepEqual(a, b)
end

-- Listeners
local stateListeners: { [number]: () -> () } = {}
local nextListenerId = 1

local function listen(fn: () -> ()): () -> ()
	local id = nextListenerId
	stateListeners[id] = fn
	nextListenerId += 1
	return function()
		stateListeners[id] = nil
	end
end

local function notifyListeners()
	for _, fn in stateListeners do
		fn()
	end
end

-- Heartbeat: compute fresh state, diff, swap + notify
RunService.Heartbeat:Connect(function()
	local newState = computeState()
	if stateChanged(currentState, newState) then
		currentState = newState
		notifyListeners()
	end
end)

-- Event handlers: just update inputs, Heartbeat picks them up

if isServer then
	RODEO_UNIFIER_REMOTE.OnServerEvent:Connect(function(player, action, id)
		if action == "register_client_vm_id" then
			inputs.clientVmIds[id] = player
		elseif action == "studio_id_from_client" then
			-- "id" is the client's mcp_studio_id (from reconciliation)
			inputs.clientMcpStudioIds[id] = player
		end
	end)

	local function playerAdded(player: Player)
		inputs.players[player] = true
		RODEO_UNIFIER_REMOTE:FireClient(player, "register_server_vm_id", vmId)
	end

	for _, player in Players:GetPlayers() do
		playerAdded(player)
	end
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(function(player)
		inputs.players[player] = nil
	end)
end

if isClient then
	RODEO_UNIFIER_REMOTE.OnClientEvent:Connect(function(action, id)
		if action == "register_server_vm_id" then
			inputs.serverVmId = id
		elseif action == "studio_id_from_server" then
			-- "id" is the server's mcp_studio_id (from reconciliation)
			inputs.serverMcpStudioId = id
		end
	end)
	RODEO_UNIFIER_REMOTE:FireServer("register_client_vm_id", vmId)
end

RODEO_UNIFIER_BINDABLE.Event:Connect(function(id)
	-- "id" is this VM's mcp_studio_id (from reconciliation's unify_code)
	inputs.bindableMcpStudioId = id
end)

return {
	vmId = vmId,
	listen = listen,
	getState = function(): State?
		return currentState
	end,
}
