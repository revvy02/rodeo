fn main() {
    // Pre-tokio dispatch for the embedded launch-control helper. Invoked as
    // `rodeo __launch-control ...`, we hand off directly without initializing
    // tokio, clap, tracing, or anything else. Synchronous helper (setsid →
    // pty → drain → exit); the rest of `main` would just add startup overhead.
    if std::env::args().nth(1).as_deref() == Some("__launch-control") {
        launch_control::run_main_with_args(std::env::args().skip(2));
    }

    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("failed to build tokio runtime");
    rt.block_on(rodeo::run());
}
