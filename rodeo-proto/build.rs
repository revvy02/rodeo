fn main() {
    connectrpc_build::Config::new()
        .files(&["proto/rodeo.proto", "proto/runtime.proto"])
        .includes(&["proto/"])
        .include_file("_connectrpc.rs")
        .compile()
        .expect("failed to compile connectrpc definitions");
}
