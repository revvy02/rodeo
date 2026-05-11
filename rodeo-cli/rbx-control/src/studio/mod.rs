//! Roblox Studio-specific control mechanics.
//!
//! Modules here automate or communicate with Roblox Studio specifically:
//! Studio process launch, multi-process multiplayer-test mode, log tailing,
//! and the StudioMCP JSON-RPC client. Cross-cutting modules (fflags, paths,
//! place, profile_scanner) live at the crate root since they apply to both
//! Studio and Player.

pub mod launch;
pub mod layout;
pub mod log_scanner;
pub mod mcp_client;
pub mod multiplayer_test;
