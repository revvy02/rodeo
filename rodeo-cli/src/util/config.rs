/// Default port for the `rodeo` master (the long-running process; the
/// installed plugin auto-connects to its studio backend).
///
/// A serve is a master on `SERVE_PORT` plus a studio backend at
/// `SERVE_PORT + 1` (44873) for plugin WebSocket connections. There is one
/// device-level serve: `rodeo run` reuses a serve already on this port and
/// only starts one here when none is running, so every studio shares it.
/// The port is stable so plugin configs can hard-code it.
pub const SERVE_PORT: u16 = 44872;



