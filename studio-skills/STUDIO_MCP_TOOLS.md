# Roblox Studio MCP — Tool Reference

Generated from the StudioMCP proxy's `tools-cache.json` — the live tool set the connected
Studio advertised (cached 2026-06-18). This is what `mcp__Roblox_Studio__*` exposes.

**25 tools** forwarded from Studio (below). Plus two **proxy-level** tools the
`StudioMCP` binary provides itself for multi-Studio selection (not in the cache):
- `list_roblox_studios` — list connected Studio instances `{name, id, active}`. No params.
- `set_active_studio` — pick which Studio receives subsequent calls (by `studio_id`).

---

## `character_navigation`

Navigate the character to the given position, or instance.

| param | type | req | description |
|---|---|---|---|
| `datamodel_type` | string | ✔ | The target datamodel to operate on, the tool can only be performed in those datamodel types. call get_studio_state to get current available datamodel types. if the target datamodel is not available in current mode, consider using start_stop_play to switch to the desired mode and then use the tools. This is a required argument. |
| `instance_path` | string |  | The instance path that the character should be moved to. for example: "game.Workspace.Part","game.Workspace.Model". The path should start with game, LocalPlayer, or Workspace. |
| `speed_multiplier` | number |  | speed multiplier, default is 1.0, 0.5 is half speed, 2.0 is double speed. minimum is 0.1, maximum is 10.0. |
| `x` | number |  | The x coordinate to move the character to. Required if instance_path is not provided. |
| `y` | number |  | The y coordinate to move the character to. Required if instance_path is not provided. |
| `z` | number |  | The z coordinate to move the character to. Required if instance_path is not provided. |

## `execute_luau`  _(destructive, open-world)_

Executes Luau code in Roblox Studio. Returns the result of the executed code or an error message if the code fails to execute.

| param | type | req | description |
|---|---|---|---|
| `code` | string | ✔ | The Luau code to execute. |
| `datamodel_type` | string | ✔ | The target datamodel to operate on, the tool can only be performed in those datamodel types. call get_studio_state to get current available datamodel types. if the target datamodel is not available in current mode, consider using start_stop_play to switch to the desired mode and then use the tools. This is a required argument. |

## `generate_material`

Returns the BaseMaterial and Name of the generated MaterialVariant. To use, these must both be set to the Material and MaterialVariant properties of BaseParts, respectively.

| param | type | req | description |
|---|---|---|---|
| `baseMaterial` | string | ✔ |  |
| `materialDescription` | string | ✔ |  |
| `materialId` | string | ✔ |  |
| `materialPattern` | string | ✔ |  |

## `generate_mesh`

Generates a textured mesh from a prompt using AI.

| param | type | req | description |
|---|---|---|---|
| `maxTriangles` | number |  | The maximum number of triangles for the generated mesh. If provided, this must be between 12 and 20000 (inclusive). |
| `partNames` | string |  | List of part names defining the schema for the generated mesh. Accepts a comma-separated string (e.g. 'body, left wheel, right wheel') or a JSON array of strings. When provided, a SchemaDefinition is used instead of the default PredefinedSchema. |
| `size` | object |  | The generation's bounding box size. The generation will try to fit within this volume. Try to approximate a good size based on textPrompt. |
| `textPrompt` | string | ✔ | The text prompt describing the mesh to generate. |

## `generate_procedural_model`

Creates 3D objects built from primitive parts (blocks, spheres, cylinders, wedges) as a ProceduralModel with configurable attributes.
Use this tool when the user wants to:
- Create or build a 3D object, model, character, creature, vehicle, building, scenery, or any physical thing in the workspace
- Generate something from a reference image
- Create an object with tunable parameters (e.g. "add attributes to control head size, arm length, color")
- Build anything described as "procedural", "parametric", "configurable", or "with attributes"

The output is a ProceduralModel: a scripted model whose appearance is controlled by user-editable attributes (like size, color, proportions). The user can tweak these attributes after generation without regenerating.

The tool automatically inserts the generated model into the workspace. You do not need to run any code afterward.

| param | type | req | description |
|---|---|---|---|
| `attachedImageUri` | string |  | The image URI (IMAGEID_<id>) from the user's attached image. Always pass this when the user provides a reference image. |
| `partNames` | string |  | List of part names that define the structure of the generated model. Accepts a comma-separated string (e.g. 'body, left wheel, right wheel, door') or a JSON array of strings. When provided, the model will be built around these named parts. |
| `prompt` | string | ✔ | A text description of what to create and what attributes to expose. Pass the user's own words. If they mention specific configurable properties (e.g. "head size", "arm length", "wheel count"), include those in the prompt so the generated model exposes them as editable attributes. If an image is attached and the user gave no text description, pass an empty string. Do NOT describe or interpret the attached image — only pass the user's own words. |

## `get_console_output`  _(read-only)_

Get the console output from the Studio output log.

_No parameters._

## `get_studio_state`  _(read-only)_

Get the state of the studio, including current play state and available datamodel types. If the studio state is not expected, please call start_stop_play tool to start or stop the play.

_No parameters._

## `http_get`  _(read-only, open-world)_

Fetches the content of a URL via HTTP GET request. Returns the response body as text.

Optionally searches the fetched content for a keyword (query parameter). When a query is provided:
- Returns only the matching sections with surrounding context lines, saving context window space.
- Returns a short "no match" message if the keyword isn't found.
- Use context_lines to control how many lines of context around each match (default: 3).
- Use return_full: true to get the entire document when the keyword matches.

Without a query, the full response body is returned.

Only the following URL patterns are allowed:
- https://create.roblox.com/docs/reference/engine (Roblox Engine API docs — URLs must end with .md or be llms.txt)
- https://create.roblox.com/docs/cloud (Roblox Cloud API docs — URLs must end with .md or be llms.txt)
- https://create.roblox.com/docs/performance-optimization (Roblox Performance Optimization docs — URLs must end with .md or be llms.txt)
- https://github.com/Roblox/libmp (Roblox LibMP repository — URLs must end with .md or be llms.txt)

Any URL that does not match one of the above rules will be rejected.
Only GET requests are supported. The full URL must be provided.

Examples:
- http_get(url: "https://create.roblox.com/docs/reference/engine/classes/Part.md")
- http_get(url: "https://create.roblox.com/docs/reference/engine/classes/Part.md", query: "Anchored")
- http_get(url: "https://create.roblox.com/docs/reference/engine/classes/BasePart.md", query: "Position", context_lines: 10)
- http_get(url: "https://create.roblox.com/docs/reference/engine/classes/Part.md", query: "Anchored", return_full: true)

| param | type | req | description |
|---|---|---|---|
| `context_lines` | number |  | Lines of surrounding context per match. Only meaningful when query is provided. Default: 3. |
| `query` | string |  | Optional keyword to search for in the fetched content (case-insensitive literal match). When provided, only matching sections are returned. |
| `return_full` | boolean |  | If true and query matches, return the entire document instead of just matched sections. Only meaningful when query is provided. Default: false. |
| `url` | string | ✔ | The full URL to fetch. Must match one of the allowed URL patterns. |

## `insert_asset`

Inserts an asset into the game by its numeric Roblox asset ID.
Use this tool when you have a specific asset ID to insert directly, rather than searching the Creator Store.
The asset will be loaded, validated, and placed in the scene.
Always provide assetName when you know the name of the asset (e.g. from search results or user request). The inserted instance will be named using assetName — if omitted, it defaults to a generic name.
Supports models, meshes, images/decals, audio, video, animations, and packages.

| param | type | req | description |
|---|---|---|---|
| `assetId` | string | ✔ | Numeric Roblox asset ID to insert. |
| `assetName` | string |  | Name for the inserted instance in the game tree. Always provide this when you know the asset name (e.g. from search_asset results). If omitted, defaults to a generic name. |
| `assetType` | string |  | Asset type hint. If provided, skips the metadata API lookup and uses this type directly. Use when the caller already knows the asset type (e.g. from inventory search results). 'Image' and 'Decal' both insert as a Decal instance. |
| `parentPath` | string |  | DataModel path to parent the asset under (e.g. game.Workspace.Folder1). Defaults to workspace. |

## `inspect_instance`  _(read-only)_

Inspect a specific Roblox instance to get all its properties, attributes, and children summary.
Returns detailed information about instances including all readable properties, custom attributes, 
and a comprehensive summary of immediate children and recursive child counts.
If multiple instances match the same path, all matches will be returned.
Use this tool after using GameTree to explore specific instances in detail.

SINGLE MATCH OUTPUT FORMAT:
{
  "name": "MyPart",
  "className": "Part",
  "path": "Workspace.MyPart",
  "uniqueId": "1234567890ABCDEF",
  "properties": {
    "Anchored": true,
    "CanCollide": true,
    "CFrame.Position": "0, 10, 0",
    "CFrame.Rotation": "1, 0, 0, 0, 1, 0, 0, 0, 1",
    // ... all other readable properties
  },
  "attributes": {
    "CustomTag": "PlayerSpawn",
    "SpawnDelay": 5,
    "IsActive": true
  },
  "children": {
    "immediateChildren": [
      {
        "className": "Part",
        "path": "Workspace.MyPart.ChildPart"
      },
      {
        "className": "Model",
        "path": "Workspace.MyPart.ChildModel"
      }
    ],
    "childrenCount": 2,
    "totalDescendants": 8
  }
}

CHILDREN SUMMARY FIELDS:
- immediateChildren: Array of direct children with className and path only (no name, childCount, or uniqueId)
- childrenCount: Number of direct children
- totalDescendants: Total count of all descendants (children, children's children, etc.)

uniqueId is included for the main inspected instance when available. This is a unique identifier for each instance in the DataModel.

MULTIPLE MATCHES OUTPUT FORMAT:
{
  "matches": [
    { 
      "name": "MyPart", 
      "className": "Part", 
      "path": "Workspace.MyPart",
      "uniqueId": "RBX1234567890ABCDEF",
      "properties": {...}, 
      "attributes": {...},
      "children": {...}
    },
    { 
      "name": "MyPart", 
      "className": "MeshPart", 
      "path": "Workspace.MyPart",
      "uniqueId": "RBX9876543210FEDCBA",
      "properties": {...}, 
      "attributes": {...},
      "children": {...}
    }
  ],
  "count": 2,
  "totalFound": 2,
  "note": "Multiple instances found with path 'Workspace.MyPart'. All 2 matches are included below."
}

WHEN TOO MANY MATCHES (>20):
{
  "matches": [ /* first 20 matches with full details */ ],
  "count": 20,
  "totalFound": 45,
  "note": "Multiple instances found with path 'Workspace.Part'.",
  "warning": "Found 45 total matches, but only showing first 20 due to output limits. Consider using a more specific path to narrow down results."
}

PATH SPECIFICATION:
- Use dot notation: "Workspace.Model.Part"
- Can include or omit "game." prefix
- Path must match instance hierarchy
- If multiple instances have the same name at the same level, all will be returned
- Maximum of 20 matches will be returned (with warning if more exist)

EXAMPLES:
- Inspect with children: InspectInstance(path: "Workspace.Baseplate")
- Multiple matches: InspectInstance(path: "Workspace.Part") → Returns up to 20 Parts with children summary
- Case-insensitive: InspectInstance(path: "workspace.baseplate")
- Inspect script: InspectInstance(path: "ServerScriptService.MainScript")
- Inspect GUI: InspectInstance(path: "StarterGui.ScreenGui.Frame")
- With game prefix: InspectInstance(path: "game.Workspace.Model")

CHILDREN SUMMARY USE CASES:
- Understand instance hierarchy structure
- Count total descendants for performance considerations
- See immediate children for navigation purposes
- Identify complex models with many nested children
- Plan traversal strategies for large hierarchies

| param | type | req | description |
|---|---|---|---|
| `path` | string | ✔ | Path to the instance(s) to inspect using dot notation (case-insensitive). Returns detailed properties, attributes, and children summary. If multiple instances match, up to 20 will be returned with a warning if more exist. Example: 'Workspace.Model.Part' or 'workspace.model.part' |

## `multi_edit`

Makes multiple edits to a single script in one operation. More efficient than multiple single edits.
Can also create new scripts if the path doesn't exist (will need to specify className).

Example Call (correct):
- Args: {"file_path":"ReplicatedStorage.Platformer.Constants","edits":[{"old_string":"JUMP_COOLDOWN = 0.15","new_string":"JUMP_COOLDOWN = 0.3"}]}

Path Format:
- Use dot notation like "game.ServerScriptService.MyScript"

Creating New Scripts:
- If the script doesn't exist, it will be created using the provided className
- className is required when creating new scripts
- First edit with empty old_string ("") sets the initial content
- Subsequent edits work normally on the created content

Before Using:
- Read or search file to understand existing script contents
- For new scripts, provide className and start with empty old_string to set initial content

Important Notes:
- All edits are applied in sequence, in the order provided
- Each edit operates on the result of the previous edit
- All edits must be valid for the operation to succeed - atomic operation
- Plan edits carefully to avoid conflicts between sequential operations

Critical Requirements:
- old_string must match script contents exactly (including whitespace)
- old_string and new_string must be different
- className required only when creating new scripts
- For new files: first edit can have empty old_string to set initial content

When Making Edits:
- Ensure all edits result in correct, runnable code
- Don't leave code in a broken state
- Use replace_all for renaming variables across the entire script

| param | type | req | description |
|---|---|---|---|
| `className` | string |  | The class name of the script to create (e.g., 'Script', 'LocalScript', 'ModuleScript'). Required only when creating new scripts, leave empty if script already exists. |
| `datamodel_type` | string | ✔ | The target datamodel to operate on, the tool can only be performed in those datamodel types. call get_studio_state to get current available datamodel types. if the target datamodel is not available in current mode, consider using start_stop_play to switch to the desired mode and then use the tools. This is a required argument. |
| `edits` | array<object> | ✔ | An array of edit operations. For new scripts, first edit can have empty old_string to set initial content. |
| `file_path` | string | ✔ | The dot-notation path of the script (e.g., 'game.ServerScriptService.MyScript'). Will be created if it doesn't exist. |

## `screen_capture`  _(read-only)_

Capture current edit-time screen, return the image data. If camera_position and look_at_position are provided, the camera will be temporarily set to the camera_position and look at the look_at_position.

| param | type | req | description |
|---|---|---|---|
| `camera_position` | array<number> |  | The position of the camera to capture the screen from. |
| `capture_id` | string | ✔ | Capture identifier such as 'ScreenCapture_1', 'ScreenCapture_2', etc. |
| `look_at_position` | array<number> |  | The position to look at. |

## `script_grep`  _(read-only)_

Runs a search for a string pattern over all script contents in the game. To avoid overwhelming output, the results are capped at 50 matches.

| param | type | req | description |
|---|---|---|---|
| `query` | string | ✔ | The string or Luau pattern to search for. |

## `script_read`  _(read-only)_

Reads a script from the Roblox workspace. The output will be returned with line numbers in format: LINE_NUMBER→LINE_CONTENT.
When using this tool to gather information, ensure you gather the COMPLETE context to fulfill the user's request.

Usage:
- This tool reads the entire script by default to provide complete context
- You can read multiple scripts in parallel for efficiency
- If you need to find specific symbols across multiple scripts, use the grep search tool
- Avoid re-reading the same script unless the script may have changed since the last read
- For very large scripts (thousands of lines), consider using grep_search to locate specific functions or patterns first

Path Format:
- The path needs to be a full path, with no wildcard matching
- Use dot notation like "game.ServerScriptService.MyScript"
- Script must already exist (use `file_search` or `grep_search` to find the script path first)
- Will only read existing scripts, never creates new ones

| param | type | req | description |
|---|---|---|---|
| `end_line_one_indexed_inclusive` | integer |  | The one-indexed line number to end reading at (inclusive). Required if should_read_entire_file is false. |
| `should_read_entire_file` | boolean |  | Whether to read the entire script. Defaults to true. |
| `start_line_one_indexed` | integer |  | The one-indexed line number to start reading from (inclusive). Required if should_read_entire_file is false. |
| `target_file` | string | ✔ | The dot-notation path of the script to read (e.g., 'game.ServerScriptService.MyScript') |

## `script_search`  _(read-only)_

Fast script search based on fuzzy matching against script names.
Use if you know part of the script name but don't know where it's located exactly.
Response will be capped to 10 results.
Make your query more specific if need to filter results further.
Note: Pattern matching is not supported such as asterisk (*) or question mark (?) wildcards.

| param | type | req | description |
|---|---|---|---|
| `keywords` | string | ✔ | The comma-separated keywords string to search for in the game's scripts. Each keyword is case-insensitive. |

## `search_asset`  _(read-only, open-world)_

Searches for assets across Creator Store (public marketplace) and Creator Inventory (user/group/universe).
Use this tool to find assets by keyword before inserting them with insert_asset.
Returns a list of matching assets with metadata (name, type, source, price).

Scope controls where to search:
- 'auto' (default): waterfalls through universe inventory → universe's owning group → user inventory → Creator Store. Best for general "find me an X" requests.
- 'creator_store': searches only the marketplace. Use this when the user wants marketplace assets, paid assets, or when using price/creator filters.
- 'user': searches the user's personal inventory only.
- 'group': searches the universe's owning group by default. Pass groupId or groupName to search a different group instead. If the universe has no owning group and you don't pass a groupId, the response lists the user's groups so you can retry.
- 'universe': searches the current universe's inventory only.

Targeting a specific group: when the user names a particular group ("in my group X" / "in group 12345"), set scope='group' AND pass groupId or groupName to constrain to that one group. groupId/groupName are only valid with scope='group'; combining with any other scope (including 'auto') is rejected.

Result attribution: each inventory result includes `creatorId` (string, the group or user ID that owns the asset) and `creatorName` (the group/user name when known). `creatorId` semantics depend on `source`: for source='inventory' coming from a group, it's the group ID.

Every scope='group' or scope='auto' response includes a `groups` field listing { id, name } for each of the user's groups (when the user has any). Use these to make a follow-up scope='group' + groupId call when the default (the universe's owning group, or the first relevant group) doesn't match what the user wants.

Every response also includes a `context` field describing the current Studio session: { userId, universeId, isPublished, creatorType ('User'/'Group' when published), creatorId, creatorName }. Use this to ground answers about which place is being edited and to disambiguate "in my group" requests.

Cross-owner inserts caution: when an inventory result's creatorId differs from context.creatorId (the place's owner), inserting it brings another owner's asset into this place. The user may have access to view the asset but might not intend or have the authority to share it across owners. Before calling insert_asset on a cross-owner result, name the source (the asset's creatorName) and the destination (context.creatorName or universe), and ask the user for explicit consent.

When to use price filters: If the user asks for paid/premium assets or specifies a price range, set scope='creator_store' and use priceFilter, minPriceCents, and/or maxPriceCents. These filters only apply to Creator Store searches.
When to use asset type: If the user asks for a specific asset type (audio, decals, meshes, packages, etc.), set assetType to filter results. The inventory API requires exactly one assetType per call and defaults to 'Model' when omitted, so cross-type discovery requires explicit assetType=Image / Audio / etc. Packages are stored as Models with a Package subtype — set assetType='Package' to find them (do not search for the word "package" as a query).
Inventory results (source='inventory') are always insertable. Creator Store results may occasionally be restricted — if insert fails, try the next result.
Each result includes a thumbnailUrl (Roblox Thumbnails API). Fetch it to get JSON with data[0].imageUrl pointing to a CDN image of the asset — useful for visually comparing assets before inserting.

| param | type | req | description |
|---|---|---|---|
| `assetType` | string |  | Filter by asset type. Use 'Image' for user-uploaded images (most decals/textures uploaded today are stored as Image, not Decal). Use 'Package' when the user asks about packages — packages are Models with a Package subtype, so a keyword search for 'package' won't find them. |
| `audioMaxDuration` | number |  | Maximum audio duration in seconds (only when assetType='Audio'). |
| `audioMinDuration` | number |  | Minimum audio duration in seconds (only when assetType='Audio'). |
| `excludeSources` | array<string> |  | With scope='auto': skip these sources from the waterfall. |
| `facets` | array<string> |  | Additional keywords to refine the search (Creator Store only, ignored for inventory scopes). Facets narrow results by related concepts — e.g. for a 'lion' search: 'mane', 'safari', 'realistic', 'animated'. Available facets depend on the query. |
| `groupId` | string |  | Numeric group ID to constrain group inventory searches to a single group. Only valid with scope='group'. Mutually exclusive with groupName. |
| `groupName` | string |  | Group name to constrain group inventory searches to a single group. Matched case-insensitively against the user's groups. Only valid with scope='group'. If the name doesn't match any of the user's groups, the response includes a `groups` field listing valid options. Mutually exclusive with groupId. |
| `includeSources` | array<string> |  | With scope='auto': only search these sources (e.g. ['user', 'creator_store']). |
| `maxPriceCents` | number |  | Maximum price in cents. Requires scope='creator_store'. Use with minPriceCents for a price range. |
| `maxResults` | number |  | Number of results to return (1-20, default 5). |
| `minPriceCents` | number |  | Minimum price in cents. Requires scope='creator_store'. Use with maxPriceCents for a price range (e.g. minPriceCents=100, maxPriceCents=5000). |
| `priceFilter` | string |  | Price filter. Requires scope='creator_store'. 'free' returns only free assets, 'paid' returns only paid assets, 'all' (default) returns both. |
| `query` | string |  | Search term. Can be empty when filtering by assetType alone (e.g. to list all packages). Supports multi-term search with '+' (e.g. 'red+car') and exact phrase with quotes (e.g. '"red+car"'). |
| `scope` | string |  | Where to search. 'auto' (default) waterfalls through all available sources. Use explicit scope to target a single source. |
| `tags` | array<string> |  | Tags to filter by (Creator Store only, ignored for inventory scopes). Tags are category labels like 'Vehicle', 'Airplane', 'Fantasy'. |
| `verifiedCreatorsOnly` | boolean |  | Only return results from verified creators (Creator Store only). |

## `search_game_tree`  _(read-only)_

Explore the Roblox game hierarchy tree with flat JSON output.
Returns an array of JSON objects representing instances in the Data Model, showing names, paths, and relationships.
Use optional filters to narrow down results by path, instance type, or keywords.
For detailed inspection of a specific instance's properties and attributes, use the Inspect Instance tool.

OUTPUT FORMAT:
Array of objects with:
{
  "name": "InstanceName",
  "className": "Part", 
  "fullPath": "Workspace.Folder.InstanceName",
  "parentName": "Folder",
  "childSummary": "5 children (3 Part, 2 Script)",  // Present if depth limit reached and children exist
  "unexploredChildCount": 5  // Present if depth limit reached with matching children
}

DEPTH LIMITING:
- Default max_depth: 3 levels from start point (absolute traversal depth)
- Absolute max: 10 levels
- max_depth limits how deep into the hierarchy we traverse, regardless of filters
- Beyond max_depth, children are summarized with counts by class type
- Nodes at depth limit show: "unexploredChildCount" and "childSummary"

EXAMPLES:
- Full tree (3 levels): GameTree()
- Workspace only: GameTree(path: "Workspace")
- ServerScriptService: GameTree(path: "ServerScriptService")
- All base scripts: GameTree(instance_type: "BaseScript")
- All parts: GameTree(instance_type: "Part")
- By keywords: GameTree(keywords: "player, character")
- Deep exploration: GameTree(max_depth: 6)
- Specific path: GameTree(path: "Workspace.Models")
- Combined filters: GameTree(path: "Workspace", instance_type: "Part", keywords: "red")
- Increase output: GameTree(head_limit: 1000, max_depth: 5)

| param | type | req | description |
|---|---|---|---|
| `head_limit` | number |  | Maximum number of results to return. Default: 200. Prevents overwhelming output for large trees. |
| `instance_type` | string |  | Filter by ClassName using IsA() check. Examples: 'BasePart', 'BaseScript', 'GuiObject', 'Model', 'Folder'. Case sensitive. |
| `keywords` | string |  | Filter by instance name keywords (case-insensitive). Separate multiple keywords with commas or spaces. Instance name must contain at least one keyword. Examples: 'player', 'red, blue', 'button door' |
| `max_depth` | number |  | Maximum absolute depth to traverse from start point. Default: 3, Absolute max: 10. Limits how deep we explore in the hierarchy regardless of filters. Beyond this depth, children are summarized instead of expanded. |
| `path` | string |  | Start exploration from this path. Examples: 'Workspace', 'ServerScriptService', 'Workspace.Models'. Path is case-sensitive. |

## `skill`  _(read-only)_

Retrieve detailed knowledge, best practices, or reference material for a specific skill.
Skills provide domain-specific expertise that helps you produce better, more accurate results.

<available_skills>
  <skill>
    <name>rbx-debug</name>
    <description>Programmatically add breakpoints and inspect thread information to debug Roblox Studio games via MCP, plugins, or command scripts. Use as a more robust tool to investigate scripting bugs or verify script behavior beyond static analysis.</description>
  </skill>
  <skill>
    <name>rbx-device-simulator-lua</name>
    <description>Control the Studio Device Simulator to test UI across device form factors. Use when switching devices, testing orientations, running multi-device comparisons, or verifying UI layout via MCP tools (execute_luau + screen_capture).</description>
  </skill>
  <skill>
    <name>rbx-docs-search</name>
    <description>Look up Roblox Engine API documentation using the http_get tool. Use when you need accurate, up-to-date details about classes, datatypes, enums, globals, or libraries.</description>
  </skill>
  <skill>
    <name>rbx-scene-analysis</name>
    <description>Analyze and optimize Roblox scenes using SceneAnalysisService — rendering, memory, instance composition, unparented instances, and animation/audio assets. Use when investigating performance, memory, or leaks in a place.</description>
  </skill>
</available_skills>

When to use skills:
1. When the task involves a domain covered by an available skill
2. When you need best practices or conventions before writing or reviewing code
3. When you are unsure about the correct patterns or APIs for a specific area

Important:
1. Invoke the skill BEFORE writing code or taking action, not after
2. Follow the returned guidance closely in your response
3. Do not mention a skill without actually invoking it first

| param | type | req | description |
|---|---|---|---|
| `skill_name` | string | ✔ | The name of the skill to retrieve. Options: rbx-debug, rbx-device-simulator-lua, rbx-docs-search, rbx-scene-analysis |

## `start_stop_play`

Start play the game or stop the play.

| param | type | req | description |
|---|---|---|---|
| `is_start` | boolean | ✔ | true to start the game, false to stop the game and return to edit mode. |

## `store_image`

Load an image from a local file path and return an IMAGEID_<id> URI that can be passed to other tools (e.g. as attachedImageUri for generate_procedural_model).
Use this tool when you need to convert a local image file into an image URI that other tools accept.
Supported formats: png, jpg, jpeg. Max file size: 5MB.

| param | type | req | description |
|---|---|---|---|
| `filePath` | string | ✔ | Absolute path to a local image file (png, jpg, or jpeg). |

## `subagent`

Launch a specialized subagent to handle complex, multi-step tasks autonomously.
Subagents are independent AI assistants with restricted tool access and specialized instructions.

<available_subagents>
  <subagent>
    <name>explore</name>
    <description>Fast agent specialized for exploring codebases and searching for information. Use this when you need to:
- Find files by patterns (e.g., "scripts with 'player' in the name")
- Search code for keywords or patterns (e.g., "how are touch events handled?")
- Answer questions about the codebase structure
- Query the current game state via Luau execution
- Understand existing game architecture before making changes
- Gather context from multiple files before deciding on an approach</description>
  </subagent>
  <subagent>
    <name>playtest</name>
    <description>Agent specialized for playtesting Roblox experiences. Use this when you need to:
- Run playtests that involve moving through the world and interacting with objects like a human player.
- Verify observable outcomes through world state, GUI changes, and console output.
- For playtest requests, prefer using this subagent over directly orchestrating individual tools.
- The agent can use start_stop_play - no need to call start_stop_play.</description>
  </subagent>
</available_subagents>

When to use subagents:
1. When you need to explore the codebase before making decisions
2. When a task requires multiple search/read steps across many files
3. When you're uncertain about the right approach and need autonomous investigation
4. To separate concerns (e.g., explore first, then modify)

Important:
1. Subagents return a final text result summarizing their work
2. You cannot have a back-and-forth conversation with a subagent
3. Subagents cannot spawn other subagents (no nesting)
4. Choose the most specific subagent for your task

| param | type | req | description |
|---|---|---|---|
| `description` | string | ✔ | A short 3-5 word description of the task in present continuous tense (e.g., 'Exploring player spawn logic', 'Finding lighting scripts'). Used for display. |
| `subagent_type` | string | ✔ | The type of subagent to invoke. Options: explore, playtest, screen_capture |
| `task` | string | ✔ | Detailed task description and instructions for the subagent. Be specific about what you need the subagent to do and what information to return. |

## `upload_image`

Upload a batch of images from http server to Roblox Asset Server, returning imagePath to assetId map, such as {"http://localhost/image.png" : "rbxassetid://12345678", "https://www.figma.com/api/mcp/asset/6dcff81e-b394-4640-b3b1-123456789" : "rbxassetid://12345679"}.

| param | type | req | description |
|---|---|---|---|
| `imagePaths` | array<string> | ✔ | An array of image paths to be uploaded. |

## `user_keyboard_input`

Send one or more keyboard inputs to the game in order. Each step is keyDown, keyUp, keyPress (keyDown then keyUp), textInput, or wait.

| param | type | req | description |
|---|---|---|---|
| `actions` | array<object> | ✔ | Ordered list of keyboard actions to perform. |
| `datamodel_type` | string | ✔ | The target datamodel to operate on, the tool can only be performed in those datamodel types. call get_studio_state to get current available datamodel types. if the target datamodel is not available in current mode, consider using start_stop_play to switch to the desired mode and then use the tools. This is a required argument. |

## `user_mouse_input`

Send one or more mouse actions in order: moveTo, mouseButtonDown, mouseButtonUp, mouseButtonClick, scrollUp, scrollDown, or wait. For mouseButtonDown, mouseButtonUp, and mouseButtonClick, set mouse_button to "left" or "right". After the first step that sets position (x/y or instance_path), later steps may omit coordinates and reuse that position.

| param | type | req | description |
|---|---|---|---|
| `actions` | array<object> | ✔ | Ordered list of mouse actions to perform. |
| `datamodel_type` | string | ✔ | The target datamodel to operate on, the tool can only be performed in those datamodel types. call get_studio_state to get current available datamodel types. if the target datamodel is not available in current mode, consider using start_stop_play to switch to the desired mode and then use the tools. This is a required argument. |

## `wait_job_finished`  _(read-only)_

Wait for a primitive generation job to finish. Returns the final status and details when the job reaches a terminal state (Completed, Failed, or Cancelled).

DO NOT call this tool automatically after generate_procedural_model. The generate_procedural_model tool already handles generation in the background and updates the UI.

Only call this tool when:
- The user EXPLICITLY asks to wait for the generation to finish (e.g. "wait for it to complete", "let me know when it's done")
- You need to confirm the generation result before performing a follow-up action that depends on it (e.g. the user says "create a car with primitives and then change its color to red")

| param | type | req | description |
|---|---|---|---|
| `generationId` | string | ✔ | The generation ID returned by the generate_procedural_model tool. |
| `timeout` | number |  | Maximum time in seconds to wait for the job to finish. Defaults to 600 (10 minutes). |
