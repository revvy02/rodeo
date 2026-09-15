# Design notes

## Concurrent runs and log capture

Multiple runs can be active in the same Studio at the same time, and this is
expected to work. Each run captures the DOM's `LogService` output for its
lifetime, including output that did not come from that run. That is
intentional: the capture is what the Output window showed while the run was
live, not a stream attributed to the run.

A run that needs logs specific to itself should write them through the
`@rodeo/io` and `@rodeo/stream` APIs. Those are per-run by construction.

## Parallel serves

Several serves, of the same or different rodeo builds, can run on one machine
at once. The port is the separation convention: every command resolves it as
`--port`, then `RODEO_PORT`, then 44872, so a project pins its port next to its
rodeo version. Each studio backend installs its own plugin file, named by
build and port, and owns that file's lifetime.

Studios a serve launched belong to that serve only. Studios opened by hand
belong to nobody and connect to every running serve. `rodeo state` is per
serve: its own Studios plus the hand-opened ones.

Studio watches the one shared plugins folder, so a serve installing or removing
its own plugin file there can make another serve's already-open Studio re-scan
and briefly reload its plugin, dropping and re-dialing that plugin's socket
within about a second. A persistent Studio recovers on its own; the only thing
this disturbs is a one-shot run in flight at the exact moment another serve
starts or stops. This is transient and self-healing, unlike the permanent
corruption a single shared plugin file caused (issue #12).
