-- rodeo-client-lune — Luau port of rodeo-client-ts.
-- Entry point: `rodeo.connect({ port = ... })`.

local client = require("@self/client")
local run = require("@self/run")
local studio = require("@self/studio")
local dom = require("@self/dom")

export type RodeoClient = client.RodeoClient
export type ConnectOpts = client.ConnectOpts
export type BackendInfo = client.BackendInfo
export type ProcessInfo = client.ProcessInfo

export type Dom = dom.Dom
export type DomSnapshot = dom.DomSnapshot

export type StudioBackend = studio.StudioBackend
export type Studio = studio.Studio
export type OpenOpts = studio.OpenOpts
export type OpenPlaceOpts = studio.OpenPlaceOpts
export type OpenFileOpts = studio.OpenFileOpts
export type SaveResult = studio.SaveResult
export type MultiplayerTestServer = studio.MultiplayerTestServer
export type MultiplayerTestClient = studio.MultiplayerTestClient

export type RunCodeOpts = run.RunCodeOpts
export type RunResult = run.RunResult
export type LogFilter = run.LogFilter

return {
	connect = client.connect,
}
