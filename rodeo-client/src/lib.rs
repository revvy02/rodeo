//! Canonical rodeo client library.
//!
//! Mirrors `rodeo-client-ts` shape in Rust. Owns a connectrpc transport,
//! exposes `RodeoClient` → `StudioBackend` → `Studio` → `Vm` handles,
//! with `runCode` streaming + local RPC dispatch.

pub mod client;
pub mod studio;
pub mod vm;
pub mod run;
mod transport;
pub mod runtime;

pub use client::RodeoClient;
pub use studio::{
    MultiplayerTest, Studio, StudioBackend,
};
pub use vm::Vm;
pub use run::{RunCodeOpts, RunResult, RunStream};

pub use rodeo_proto as proto;
