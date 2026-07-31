# lute adapter conformance tests

Unlike `../lune/` (verbatim upstream tests), these are **rodeo-authored**:
lute's own runtime tests depend on `@std/test`, a framework from lute's
separate std distribution that isn't part of the `submodules/lute` checkout —
so there is nothing self-contained to vendor yet. These scripts are written
against the API contracts in `submodules/lute/definitions/*.luau` (pinned at
`1219ec5`) and assert the behaviors those definitions document.

Each script is a plain Luau file run through `rodeo run` by
`tests-new/adapters/lute.test.ts`; an error fails the run and the suite.

If lute's std distribution gets vendored later, upstream tests can replace
these — same rule as the lune suite: upstream files stay verbatim, and
anything that can't pass gets a manifest entry, not an edit.
