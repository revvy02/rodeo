//! Run routing: mode / dom-kind / run-context resolution.
//!
//! A run is routed by three orthogonal, individually-optional fields
//! (`RouteSpec`): the studio `mode` to converge to, the `dom_kind` (which
//! DataModel the run lands on — the communication boundary: same-DOM contexts
//! share instances, cross-DOM needs remotes), and the `context` (the *identity
//! level* the code runs at, each an independent Luau VM on the DOM — cf.
//! Roblox's `Script.RunContext` Server/Client/Plugin, plus `elevated` for the
//! command bar; NOT a script class).
//! `resolve()` applies the defaults table and validates the combination; the
//! master calls it at submit time, the CLI/MCP call it early for fast errors.

use anyhow::{bail, Result};

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RunContext {
    Plugin,
    Server,
    Client,
    Elevated,
}

impl RunContext {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Plugin => "plugin",
            Self::Server => "server",
            Self::Client => "client",
            Self::Elevated => "elevated",
        }
    }

    pub fn parse(s: &str) -> Result<Self> {
        match s {
            "plugin" => Ok(Self::Plugin),
            "server" => Ok(Self::Server),
            "client" => Ok(Self::Client),
            "elevated" => Ok(Self::Elevated),
            _ => bail!("unknown context '{s}' — expected plugin, server, client, or elevated"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StudioMode {
    Edit,
    Run,
    Test,
    Play,
}

impl StudioMode {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Edit => "edit",
            Self::Run => "run",
            Self::Test => "test",
            Self::Play => "play",
        }
    }

    pub fn parse(s: &str) -> Result<Self> {
        match s {
            "edit" => Ok(Self::Edit),
            "run" => Ok(Self::Run),
            "test" => Ok(Self::Test),
            "play" => Ok(Self::Play),
            _ => bail!("unknown mode '{s}' — expected edit, run, test, or play"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DomKind {
    Edit,
    Server,
    Client,
}

impl DomKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Edit => "edit",
            Self::Server => "server",
            Self::Client => "client",
        }
    }

    /// Parse a user-supplied dom kind. `edit` is accepted: the edit DataModel
    /// exists in every studio mode (it's the source the run/test/play DOMs are
    /// cloned from), so it's addressable as a kind in any mode.
    pub fn parse(s: &str) -> Result<Self> {
        match s {
            "edit" => Ok(Self::Edit),
            "server" => Ok(Self::Server),
            "client" => Ok(Self::Client),
            _ => bail!("unknown dom '{s}' — expected edit, server, or client"),
        }
    }
}

/// What the caller actually specified — every field optional. Defaults and
/// validity live in [`RouteSpec::resolve`], so all frontends (CLI, MCP,
/// client libraries via the wire) share one semantics.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct RouteSpec {
    pub mode: Option<StudioMode>,
    pub dom_kind: Option<DomKind>,
    pub context: Option<RunContext>,
}

/// A fully-resolved, validated route.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Resolved {
    pub mode: StudioMode,
    pub dom_kind: DomKind,
    pub context: RunContext,
}

impl RouteSpec {
    /// Build from wire-level strings (empty/absent → None). Unknown words error.
    pub fn from_strings(
        mode: Option<&str>,
        dom_kind: Option<&str>,
        context: Option<&str>,
    ) -> Result<Self> {
        fn some(s: Option<&str>) -> Option<&str> {
            s.filter(|v| !v.is_empty())
        }
        Ok(Self {
            mode: some(mode).map(StudioMode::parse).transpose()?,
            dom_kind: some(dom_kind).map(DomKind::parse).transpose()?,
            context: some(context).map(RunContext::parse).transpose()?,
        })
    }

    pub fn is_empty(&self) -> bool {
        self.mode.is_none()
            && self.dom_kind.is_none()
            && self.context.is_none()
    }

    /// Apply the defaults table, then validate the combination.
    ///
    /// `mode` is the sole driver of studio transitions and is NEVER inferred
    /// from `context`/`dom_kind` — it defaults to `edit` when omitted. So a
    /// server/client run must pass `--mode` explicitly (e.g. `--mode run
    /// --context server`); `--context server` alone resolves to `(edit,
    /// server)` and fails validation rather than silently transitioning the
    /// studio. This keeps the mutating action (mode change) explicit and the
    /// outcome independent of the studio's current state.
    ///
    /// Defaults:
    /// - `mode` omitted: `edit`.
    /// - `dom_kind` omitted: from `context` (server→server, client→client);
    ///   for plugin/elevated (or none) by mode: edit→edit, run/test/play→server.
    /// - `context` omitted: the native context of the resolved dom kind
    ///   (edit→plugin, server→server, client→client).
    pub fn resolve(&self) -> Result<Resolved> {
        use DomKind as K;
        use RunContext as C;
        use StudioMode as M;

        let mode = self.mode.unwrap_or(M::Edit);

        let dom_kind = self.dom_kind.unwrap_or(match self.context {
            Some(C::Server) => K::Server,
            Some(C::Client) => K::Client,
            // plugin / elevated / unspecified: the mode's primary DOM
            _ => match mode {
                M::Edit => K::Edit,
                M::Run | M::Test | M::Play => K::Server,
            },
        });

        let context = self.context.unwrap_or(match dom_kind {
            K::Edit => C::Plugin,
            K::Server => C::Server,
            K::Client => C::Client,
        });

        // Validity: which DOMs exist in each mode. The edit DataModel is present
        // in every mode (the run/test/play DOMs are clones of it), so `edit` is
        // always addressable — including to run in the edit DOM while a test or
        // play session is live in the sibling DOMs.
        match (mode, dom_kind) {
            (M::Edit, K::Edit) => {}
            (M::Edit, k) => bail!(
                "a {} DOM needs --mode run/test/play — mode defaults to edit, which has only an edit DOM",
                k.as_str()
            ),
            (M::Run, K::Edit | K::Server) => {}
            (M::Run, K::Client) => bail!("mode run has no client DOM (edit + server only)"),
            (M::Test, _) => {}
            (M::Play, _) => {}
        }

        let ok_context = match dom_kind {
            K::Edit => matches!(context, C::Plugin | C::Elevated),
            K::Server => matches!(context, C::Server | C::Plugin | C::Elevated),
            K::Client => matches!(context, C::Client | C::Plugin | C::Elevated),
        };
        if !ok_context {
            bail!(
                "context {} cannot run on the {} DOM",
                context.as_str(),
                dom_kind.as_str()
            );
        }

        Ok(Resolved {
            mode,
            dom_kind,
            context,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use DomKind as K;
    use RunContext as C;
    use StudioMode as M;

    fn spec(
        mode: Option<M>,
        dom_kind: Option<K>,
        context: Option<C>,
    ) -> RouteSpec {
        RouteSpec { mode, dom_kind, context }
    }

    #[test]
    fn defaults_table() {
        // (input spec, expected resolved (mode, dom_kind, context))
        let cases: &[(RouteSpec, (M, K, C))] = &[
            // bare run = edit plugin
            (spec(None, None, None), (M::Edit, K::Edit, C::Plugin)),
            // mode is never inferred from context: without --mode, mode is edit,
            // so only edit-hosted contexts (plugin/elevated) resolve here.
            // (server/client without --mode are invalid — see invalid_combos.)
            (spec(None, None, Some(C::Elevated)), (M::Edit, K::Edit, C::Elevated)),
            (spec(None, None, Some(C::Plugin)), (M::Edit, K::Edit, C::Plugin)),
            (spec(None, Some(K::Edit), None), (M::Edit, K::Edit, C::Plugin)),
            // edit DOM addressable while a session runs (edit exists in every mode)
            (spec(Some(M::Run), Some(K::Edit), None), (M::Run, K::Edit, C::Plugin)),
            (spec(Some(M::Test), Some(K::Edit), None), (M::Test, K::Edit, C::Plugin)),
            (spec(Some(M::Play), Some(K::Edit), None), (M::Play, K::Edit, C::Plugin)),
            (spec(Some(M::Test), Some(K::Edit), Some(C::Elevated)), (M::Test, K::Edit, C::Elevated)),
            // mode alone → primary DOM + native context
            (spec(Some(M::Run), None, None), (M::Run, K::Server, C::Server)),
            (spec(Some(M::Test), None, None), (M::Test, K::Server, C::Server)),
            (spec(Some(M::Play), None, None), (M::Play, K::Server, C::Server)),
            (spec(Some(M::Edit), None, None), (M::Edit, K::Edit, C::Plugin)),
            // the old three-segment targets
            (spec(Some(M::Run), None, Some(C::Plugin)), (M::Run, K::Server, C::Plugin)),
            (spec(Some(M::Test), Some(K::Client), Some(C::Plugin)), (M::Test, K::Client, C::Plugin)),
            (spec(Some(M::Test), None, Some(C::Elevated)), (M::Test, K::Server, C::Elevated)),
            (spec(Some(M::Test), Some(K::Client), Some(C::Elevated)), (M::Test, K::Client, C::Elevated)),
            // mode + context implying dom kind
            (spec(Some(M::Test), None, Some(C::Client)), (M::Test, K::Client, C::Client)),
            (spec(Some(M::Play), None, Some(C::Client)), (M::Play, K::Client, C::Client)),
            (spec(Some(M::Play), Some(K::Client), Some(C::Client)), (M::Play, K::Client, C::Client)),
        ];
        for (input, (mode, dom_kind, context)) in cases {
            let r = input.resolve().unwrap_or_else(|e| panic!("{input:?}: {e}"));
            assert_eq!((r.mode, r.dom_kind, r.context), (*mode, *dom_kind, *context), "{input:?}");
        }
    }

    #[test]
    fn invalid_combos() {
        let cases: &[RouteSpec] = &[
            // edit mode has no server/client DOM
            spec(Some(M::Edit), Some(K::Server), None),
            spec(Some(M::Edit), Some(K::Client), None),
            spec(Some(M::Edit), None, Some(C::Client)),
            spec(Some(M::Edit), None, Some(C::Server)),
            // no --mode → mode defaults to edit, so a server/client context or
            // dom kind is invalid (must pass --mode run/test/play explicitly)
            spec(None, None, Some(C::Server)),
            spec(None, None, Some(C::Client)),
            spec(None, Some(K::Server), None),
            spec(None, Some(K::Client), None),
            // run mode has no client DOM
            spec(Some(M::Run), Some(K::Client), None),
            spec(Some(M::Run), None, Some(C::Client)),
            // context/dom-kind mismatches
            spec(None, Some(K::Server), Some(C::Client)),
            spec(None, Some(K::Client), Some(C::Server)),
            // edit DOM hosts only plugin/elevated — not server/client contexts
            spec(Some(M::Test), Some(K::Edit), Some(C::Server)),
            spec(Some(M::Test), Some(K::Edit), Some(C::Client)),
        ];
        for input in cases {
            assert!(input.resolve().is_err(), "{input:?} should be invalid");
        }
    }

    #[test]
    fn from_strings_roundtrip() {
        let s = RouteSpec::from_strings(Some("play"), Some("client"), Some("plugin")).unwrap();
        assert_eq!(
            s,
            spec(Some(M::Play), Some(K::Client), Some(C::Plugin))
        );
        // empty strings are None
        assert!(RouteSpec::from_strings(Some(""), None, Some("")).unwrap().is_empty());
        // edit is now an accepted dom kind
        assert_eq!(
            RouteSpec::from_strings(None, Some("edit"), None).unwrap(),
            spec(None, Some(K::Edit), None)
        );
        // unknown words error
        assert!(RouteSpec::from_strings(Some("editt"), None, None).is_err());
        assert!(RouteSpec::from_strings(None, Some("edom"), None).is_err());
        assert!(RouteSpec::from_strings(None, None, Some("identity")).is_err());
    }
}
