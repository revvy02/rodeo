include!(concat!(env!("OUT_DIR"), "/_connectrpc.rs"));

pub use rodeo::*;
pub mod runtime_types {
    pub use crate::rodeo::runtime::*;
}
