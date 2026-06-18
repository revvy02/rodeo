---
name: open-cloud-usage
description: IMPORTANT: Before assuming ANY Roblox resource (developer products, badges, game passes, data stores, etc.) cannot be created or managed programmatically, call this skill. Studio can create and manage many of these via the Open Cloud API. Attempt use of those APIs before suggesting the user do it manually in the Creator Dashboard. Retrieves guidance on how to use Roblox Open Cloud APIs from within Studio, including authentication, available endpoints, and troubleshooting. No API key or external credentials are needed. Studio provides credentials automatically via HttpService:RequestAccessTokenScopesAsync(scopes). Full authentication instructions are in the skill result. An index of all available Open Cloud functionality can be found by using the http_get tool with https://create.roblox.com/docs/cloud/llms.txt. Call this skill before any Open Cloud request for the full authentication guide and to discover available endpoints.
---

## Execution in this repo (rodeo / Studio MCP)

Open Cloud calls run as a Luau script **inside Studio**: `rodeo run --target edit:plugin` (or MCP `execute_luau`) executing `HttpService:RequestAccessTokenScopesAsync(scopes)` for the Bearer token, then `HttpService:RequestAsync` to the endpoint. No external API key — Studio mints the token. Read `create.roblox.com/docs/cloud/llms.txt` and the per-API docs first via `http_get` (MCP `mcp__Roblox_Studio__http_get`) or `WebFetch`. Scope grants are governed by the Studio MCP / Assistant **MCP Scope Permissions** dialog; the denied-scope / 401 / 403 cases below still apply.

> **Verified caveat (external execution):** the token step needs a **published** place (`RequestAccessTokenScopesAsync` returns `No access token provider is available` when `game.GameId == 0`) *and* an access-token provider that appears to be supplied by the in-Studio Assistant's MCP integration — **not** plain `execute_luau` / rodeo. Expect the token step to fail when driven externally; the `http_get` doc-reading half works regardless.

# Open Cloud Usage

> **Reconcile with the caveat above.** This section is Roblox's, written for the in-Studio
> Assistant — for which `RequestAccessTokenScopesAsync` "just works." Driven externally (rodeo /
> MCP `execute_luau`), the token step **fails**: plugin identity lacks the `LocalUser` capability,
> and even at elevated there's *no access-token provider* (it's supplied by the Assistant's MCP
> integration). So the auth flow below is reference-only externally — the `http_get` doc lookups
> work, but minting a token needs the in-Studio Assistant.

Access Open Cloud by executing a Luau script making a request to the relevant Open Cloud endpoints with HttpService.

The Authorization header should be set to the result of calling `game:GetService("HttpService"):RequestAccessTokenScopesAsync(<requiredScopes>)`, where scopes is an array of the OAuth2 scopes needed for the request (e.g., `{"universe:read"}`). The returned token already has the `Bearer ` prefix so no additional prefix is necessary.

Current supported scopes are:
  - developer-product:read
  - developer-product:write
  - game-pass:read
  - game-pass:write
  - universe:read

Available Open Cloud APIs are described here: https://create.roblox.com/docs/cloud/llms.txt

Use the `http_get` tool to fetch this URL and read the API listing. Any URLs referenced within the llms.txt response should also be fetched via `http_get` to get the detailed API documentation needed for your request.

## Error Handling

- `Scope '<scope>' has been denied`
  → The scope needs to be enabled in the Assistant Plugin's MCP Scope Permissions dialog. Ask the user to enable it and retry after they confirm it's enabled.
- HTTP 403
  → The required scope needs to be enabled in the Assistant Plugin's MCP Scope Permissions dialog. Ask the user to enable it and retry after they confirm it's enabled.
- HTTP 401
  → The token is invalid or expired. Re-call `RequestAccessTokenScopesAsync` to get a fresh token and retry the request.
