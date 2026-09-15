/// Default port for the `rodeo` master (the long-running process).
///
/// Every command that talks to a master resolves its port the same way:
/// `--port`, then the `RODEO_PORT` environment variable (a project pins it in
/// `.mise.toml` or `.env`, next to its rodeo version), then this constant. A
/// serve is a master on that port plus a studio backend on port + 1 for
/// plugin WebSocket connections. `rodeo run` reuses a healthy serve on the
/// resolved port and starts one only when none is running, so projects that
/// resolve to the same port share a serve, and projects on different ports
/// run independently — including different rodeo builds side by side.
pub const SERVE_PORT: u16 = 44872;



