//! Control plane for Roblox processes.
//!
//! Reusable, consumer-agnostic infrastructure for automating Roblox Studio
//! and Roblox Player. Modules split along process type:
//!
//! - [`studio`] — Studio-specific mechanics (launch-slot daemon, log
//!   scanner, StudioMCP JSON-RPC client).
//! - [`player`] — Roblox Player launch and process handle.
//! - [`fflags`], [`paths`], [`place`], [`profile_scanner`] — cross-cutting
//!   infrastructure shared by Studio and Player consumers.
//!
//! Nothing here depends on or names any particular consumer — callers
//! compose these pieces into their own orchestration.

pub mod fflags;
pub mod paths;
pub mod place;
pub mod player;
pub mod profile_scanner;
pub mod studio;
