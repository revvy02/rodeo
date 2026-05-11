-- @lune/serde shim — maps to HttpService JSON encode/decode
local HttpService = game:GetService("HttpService")

return {
	encode = function(format: string, value: any): string
		if format == "json" then
			return HttpService:JSONEncode(value)
		end
		error("serde shim only supports json format, got: " .. format)
	end,
	decode = function(format: string, data: string): any
		if format == "json" then
			return HttpService:JSONDecode(data)
		end
		error("serde shim only supports json format, got: " .. format)
	end,
}
