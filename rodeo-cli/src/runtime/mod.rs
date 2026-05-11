//! Runtime module — the fs/stream/process RPC dispatch lives in the
//! `rodeo-client` crate now (same code is used client-side by `runCode` and
//! server-side for in-process script execution). `mcp` stays here because it
//! depends on `rbx-control`'s StudioMCP client, which is server-only.

pub mod mcp;

pub use rodeo_client::runtime::{
    dispatch_client, RpcState,
};
#[allow(unused_imports)]
pub use rodeo_client::runtime::fs;
#[allow(unused_imports)]
pub use rodeo_client::runtime::process;
#[allow(unused_imports)]
pub use rodeo_client::runtime::stream;
