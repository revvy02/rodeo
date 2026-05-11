/// Default port for `rodeo serve` master (the long-running process; the
/// installed plugin auto-connects here).
///
/// `rodeo serve` also spawns a studio backend at `SERVE_PORT + 1` (44873)
/// for plugin WebSocket connections, so the range 44872–44879 is reserved
/// for serve and its sub-backends. `ONCE_PORT` lives past that.
pub const SERVE_PORT: u16 = 44872;

/// Default port for the auto-spawned serve used by `rodeo run --place`
/// when no manually-running serve is detected. Must sit far enough above
/// `SERVE_PORT` that its own studio backend
/// (`ONCE_PORT + 1` = 44881) doesn't collide with a running serve's
/// studio backend (`SERVE_PORT + 1` = 44873). Both ports stable so plugin
/// configs can hard-code them.
pub const ONCE_PORT: u16 = 44880;



