# lune adapter conformance tests

Verbatim copies of [lune](https://github.com/lune-org/lune)'s complete test
suite — all twelve std-lib modules — executed through `rodeo run` so the
`@lune` adapters are held to lune's ground truth instead of what the shims
were written to remember.

Only five modules have adapters today (`fs`, `process`, `serde`, `stdio`,
`task`); the other seven (`datetime`, `globals`, `luau`, `net`, `regex`,
`require`, `roblox`) are vendored anyway as the aspirational roadmap — their
tests fail wholesale until an adapter exists, and the harness manifest
records them as out-of-scope rather than letting them noise up the run.

- Source: `lune-org/lune` `tests/`, pinned at the commit the
  `submodules/lune` checkout points to (copied at `7f1849c`).
- License: MPL-2.0 (see `LICENSE.txt`, copied from the lune repository).
- Update flow: pull `submodules/lune`, re-copy the five directories
  verbatim, re-run the harness, reconcile the manifest.

Files are intentionally unmodified — a test that can't pass under rodeo is
recorded in the harness manifest (`gap` with a reason, or `out-of-scope`),
never edited to pass.
