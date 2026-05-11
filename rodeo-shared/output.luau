-- Done message factory for rodeo execution results.
-- Returns a typed PluginMessage (done variant) that callers forward to their
-- transport (BindableEvent → MessageHandler in the plugin).

local rodeoProto = require("./proto/rodeo")

local function createDoneMessage(executionId: string, success: boolean, err: string?)
	return rodeoProto.PluginMessage.new({
		msg = {
			type = "done",
			value = rodeoProto.ExecutionDone.new({
				executionId = executionId,
				success = success,
				error = err,
			}),
		},
	})
end

return {
	createDoneMessage = createDoneMessage,
}
