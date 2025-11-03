local net = require("@lune/net")
local serde = require("@lune/serde")

local Result = require("../lune_packages/result")
local Option = require("../lune_packages/option")
type Result<T, E> = Result.Result<T, E>
type Option<T> = Option.Option<T>

local copy = require("./utils/copy")

local Github = {}
export type Github = typeof(setmetatable(Github :: GithubFields, { __index = Github }))
type GithubFields = {
	req: net.FetchParams,
	retries: number,
}

export type Config = {
	authToken: Option<string>,
	retries: Option<number>,
}
export type GithubOperation =
	"FetchReleases"
	| "GetMetadata"
	| "GetActionArtifacts"
	| { type: "Custom", payload: net.FetchParams }

export type GithubRelease = {
	tag_name: string,
	created_at: string,
	published_at: string,
	prerelease: boolean,
	draft: boolean,
	assets: {
		{
			name: string,
			browser_download_url: string,
			size: number,
			content_type: string,
		}
	},
}
export type GithubReleases = { GithubRelease }

local API_BASE_URL = "https://api.github.com"
local DEFAULT_MAX_RETRIES = 5
local DEFAULT_CONFIG: Config = {
	authToken = Option.None :: Option<string>,
	retries = Option.Some(DEFAULT_MAX_RETRIES) :: Option<number>,
}

function Github.new(repo: string, config: Option<Config>)
	local configOrDefault = config:unwrapOr(DEFAULT_CONFIG)
	return setmetatable(
		{
			req = {
				url = API_BASE_URL .. "/repos/" .. repo,
				headers = {
					["Authorization"] = configOrDefault.authToken:mapOr("", function(token)
						return `Bearer {token}`
					end),
				} :: net.HttpHeaderMap,
			} :: net.FetchParams,
			config = config,
			retries = configOrDefault.retries:unwrapOr(DEFAULT_MAX_RETRIES),
		} :: GithubFields,
		{
			__index = Github,
		}
	)
end

function Github.queueTransactions(self: Github, operations: { GithubOperation }): { Result<unknown, string> }
	local queue: { (retries: number) -> Result<unknown, string> } = table.create(#operations)

	for _, operation: GithubOperation in operations do
		local req: net.FetchParams = copy(self.req)

		if operation == "FetchReleases" then
			req.url ..= "/releases"
			req.method = "GET"
		end

		if typeof(operation) == "table" and operation.type == "Custom" then
			req = operation.payload
		end

		--  TODO: Other methods

		table.insert(queue, function(retries: number)
			local lastCode: number
			for _ = 1, retries do
				local resp = net.request(req)
				lastCode = resp.statusCode

				if not resp.ok then
					continue
				end

				return Result.Ok(serde.decode("json", resp.body))
			end

			return Result.Err(`Github::RespErr(statusCode={lastCode})`)
		end)
	end

	local results = {}
	for _, req in queue do
		local ok, respRes: Result<unknown, string> = pcall(req, self.retries)
		table.insert(results, if ok then respRes else Result.Err("Github::IoError"))
	end

	return results
end

return Github
