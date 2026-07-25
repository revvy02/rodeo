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

pub use rodeo::*;
pub mod runtime_types {
    pub use crate::rodeo::runtime::*;
}
