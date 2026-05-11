-- ANSI log capture: connects to LogService, writes colored output to streams
-- Returns a factory: (LogService, fs, stream, io, logFilter, outputFile) -> logConnection, outputFileStreamHandle?

return function(LogService, fs, stream, io, logFilter, outputFile)
	local ANSI = {
		[Enum.MessageType.MessageOutput] = "",
		[Enum.MessageType.MessageInfo] = "\27[36m",
		[Enum.MessageType.MessageWarning] = "\27[1m\27[38;2;255;140;0m",
		[Enum.MessageType.MessageError] = "\27[1m\27[38;2;200;0;0m",
	}
	local RESET = "\27[0m"

	local LOG_FILTER = {
		[Enum.MessageType.MessageOutput] = logFilter.enableOutput ~= false,
		[Enum.MessageType.MessageInfo] = logFilter.enableInfo ~= false,
		[Enum.MessageType.MessageWarning] = logFilter.enableWarn ~= false,
		[Enum.MessageType.MessageError] = logFilter.enableError ~= false,
	}

	-- Output file stream (via rodeo fs/stream APIs)
	local outputFileHandle = if outputFile ~= "" then fs.open(outputFile, "w") else nil

	local logConnection = LogService.MessageOut:Connect(function(body, messageType)
		if not LOG_FILTER[messageType] then
			return
		end
		local color = ANSI[messageType] or ""
		stream.write(io.stdout, if color ~= "" then color .. body .. RESET .. "\n" else body .. "\n")
		if outputFileHandle then
			stream.write(outputFileHandle, body .. "\n")
		end
	end)

	return logConnection, outputFileHandle
end
