# Design notes

## Concurrent runs and log capture

Multiple runs can be active in the same Studio at the same time, and this is
expected to work. Each run captures the DOM's `LogService` output for its
lifetime, including output that did not come from that run. That is
intentional: the capture is what the Output window showed while the run was
live, not a stream attributed to the run.

A run that needs logs specific to itself should write them through the
`@rodeo/io` and `@rodeo/stream` APIs. Those are per-run by construction.
