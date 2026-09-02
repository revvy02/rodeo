---
name: unit-test-testservice
description: Write, run, and debug Luau unit tests for ModuleScripts in Roblox Studio. Use this skill only when the user asks to add unit tests, improve test coverage, run tests, or debug failing tests.
---

# Unit Test

## TOOLS:
- {ToolNames.FileSearch}: Find scripts by name
- {ToolNames.GrepSearch}: Search script content for keywords
- {ToolNames.ReadFile}: Read script contents
- {ToolNames.ExecuteLuau}: Run Luau code to query game state (RETURN values, do not print)
- {ToolNames.InspectInstance}: Get detailed properties/attributes of an instance
- {ToolNames.GameTree}: Browse the game hierarchy
- {ToolNames.MultiEdit}: Edit scripts
- {ToolNames.GetConsoleOutput}: Get the console output, usually used to check the results of the unit test.


## WRITE UNIT TESTS:
- Unit Tests should be under `game.TestService` directly, named like `<ScriptName>_Test`, the <ScriptName> is the name of the script being tested, classname is Script instead of ModuleScript.
- For each Unit Test, it should have a comment in front of each case, describing what does this unit test do.
- Always check whether an instance already exists before adding new instances, including Folder or Scripts, do not create duplicate names under the same parent.
- Only unit test ModuleScripts. LocalScripts and ServerScripts are not unit testable, put common logic in ModuleScripts whenever possible.
- To run unit tests, call the {ToolNames.StartStopPlay} to start the game, then call the {ToolNames.ExecuteLuau} tool with `datamodel_type="Server"`, code=
```
local TestService = game:GetService("TestService")
TestService.Timeout = 30 -- seconds
TestService:RunAsync()
```


## WORKFLOW:
- Analyze the unit test instructions and have a rough plan for the unit test.
- Check unit test coverage for the related scripts by reading out the test code and the code under test.
- If the module script does not have enough unit test coverage, write the unit test code for the related scripts, follow the WRITE UNIT TESTS guidelines.
- Call {ToolNames.StartStopPlay} to start the game, then call the {ToolNames.ExecuteLuau} to start the test.
- If a unit test fails, stop play and fix the code, then run the unit test again.
- If you cannot fix the unit test after multiple attempts, summary of what you did, and state what you could not finish.
