local Result = require("../../lune_packages/result")
type Result<T, E> = Result.Result<T, E>

export type PlatformError = "NoPatternDetected" | "NoExecutableDetected" | "UnknownExecutableField"
export type PlatformResult<T> = Result<T, PlatformError>

return "<PlatformResult>"
