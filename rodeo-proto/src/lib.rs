include!(concat!(env!("OUT_DIR"), "/_connectrpc.rs"));

/// Max connectrpc envelope size on every Rust↔Rust hop: the master's server
/// limits plus the backend's and run client's receive limits. All three sites
/// must agree or the smallest silently becomes the real cap. 16 MiB aligns
/// with the plugin WS hop's frame limit (connectrpc's 4 MiB default was the
/// cliff behind issue #7's export/import failures). This is headroom, not
/// license: senders still chunk large payloads (see stream.luau's
/// WRITE_CHUNK/READ_CHUNK) — a single envelope must never grow with user
/// data, because *any* fixed cap loses to an unbounded model file.
pub const MAX_RPC_MESSAGE_SIZE: usize = 16 * 1024 * 1024;

/// Chunk size for scripts split across ScriptChunk messages. Sized for the
/// worst hop: the backend→plugin WS forward JSON-escapes the source (~2x
/// worst case), so 8,000,000 * 2 = 16,000,000 stays under the 16MiB
/// (16,777,216) frame limit with ~777KB headroom — the same math as
/// stream.luau's WRITE_CHUNK. The Rust↔Rust envelopes clear trivially.
pub const SCRIPT_CHUNK_SIZE: usize = 8_000_000;

/// Sanity ceiling on a submitted script bundle. Chunking removes the
/// transport cliff, so this exists only to catch accidents (a bundle that
/// swallowed a build directory), not as a real limit — Studio still has to
/// compile whatever this admits.
pub const MAX_SCRIPT_SIZE: usize = 256 * 1024 * 1024;

pub use rodeo::*;
pub mod runtime_types {
    pub use crate::rodeo::runtime::*;
}
