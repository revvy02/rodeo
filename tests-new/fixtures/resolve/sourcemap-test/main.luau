local helper = require("./helper")
local ok, mylib = pcall(require, "./packages/mylib")
local tag = if ok then mylib.tag else "skipped"
return "sm:" .. tag .. ":" .. helper.value
