local leaf = require(game.ReplicatedStorage.leaf)
local mid = require(game.ReplicatedStorage.mid)
local deep = require(game.ReplicatedStorage.deep)

leaf.value = "mutated"
mid.value = "mutated"
deep.value = "mutated"
deep.child.value = "mutated"
