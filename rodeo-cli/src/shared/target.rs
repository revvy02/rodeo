//! Run routing: mode / dom-kind / run-context resolution.
//!
//! A run is routed by up to four orthogonal, individually-optional fields
//! (`RouteSpec`): the studio `mode` to converge to, the `dom_kind` (which
//! DataModel role receives the script), the `context` the code executes as
//! (cf. Roblox's own `Script.RunContext` — our set is its Server/Client/Plugin
//! plus `elevated`), and the play-session `clients` size. `resolve()` applies
//! the defaults table and validates the combination; the master calls it at
//! submit time, the CLI/MCP call it early for fast errors.

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

    /// Parse a user-supplied dom kind. `edit` is intentionally not accepted:
    /// the edit DOM is addressed by `mode: edit`, never selected as a kind.
    pub fn parse(s: &str) -> Result<Self> {
        match s {
            "server" => Ok(Self::Server),
            "client" => Ok(Self::Client),
            _ => bail!("unknown dom kind '{s}' — expected server or client"),
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
    /// Play session size: ensure the session has this many clients total.
    /// Only valid when the resolved mode is `play`.
    pub clients: Option<u32>,
}

/// A fully-resolved, validated route.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Resolved {
    pub mode: StudioMode,
    pub dom_kind: DomKind,
    pub context: RunContext,
    pub clients: Option<u32>,
}

impl RouteSpec {
    /// Build from wire-level strings (empty/absent → None). Unknown words error.
    pub fn from_strings(
        mode: Option<&str>,
        dom_kind: Option<&str>,
        context: Option<&str>,
        clients: Option<u32>,
    ) -> Result<Self> {
        fn some(s: Option<&str>) -> Option<&str> {
            s.filter(|v| !v.is_empty())
        }
        Ok(Self {
            mode: some(mode).map(StudioMode::parse).transpose()?,
            dom_kind: some(dom_kind).map(DomKind::parse).transpose()?,
            context: some(context).map(RunContext::parse).transpose()?,
            clients,
        })
    }

    pub fn is_empty(&self) -> bool {
        self.mode.is_none()
            && self.dom_kind.is_none()
            && self.context.is_none()
            && self.clients.is_none()
    }

    /// Apply the defaults table, then validate the combination.
    ///
    /// Defaults:
    /// - `mode` omitted: from `dom_kind` (server→run, client→test) if given,
    ///   else from `context` (client→test, server→run, plugin/elevated→edit),
    ///   else edit.
    /// - `dom_kind` omitted: from `context` (server→server, client→client);
    ///   for plugin/elevated (or none) by mode: edit→edit, run/test/play→server.
    /// - `context` omitted: the native context of the resolved dom kind
    ///   (edit→plugin, server→server, client→client).
    pub fn resolve(&self) -> Result<Resolved> {
        use DomKind as K;
        use RunContext as C;
        use StudioMode as M;

        let mode = self.mode.unwrap_or(match (self.dom_kind, self.context) {
            (Some(K::Server), _) => M::Run,
            (Some(K::Client), _) => M::Test,
            (Some(K::Edit), _) => M::Edit,
            (None, Some(C::Client)) => M::Test,
            (None, Some(C::Server)) => M::Run,
            (None, _) => M::Edit,
        });

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

        // Validity: which (mode, dom_kind) pairs exist, and which contexts a
        // dom kind can host.
        match (mode, dom_kind) {
            (M::Edit, K::Edit) => {}
            (M::Edit, k) => bail!(
                "mode edit has no {} DOM — drop --dom-kind or pick run/test/play",
                k.as_str()
            ),
            (M::Run, K::Server) => {}
            (M::Run, k) => bail!("mode run has no {} DOM (edit + server only)", k.as_str()),
            (M::Test, K::Server | K::Client) => {}
            (M::Play, K::Server | K::Client) => {}
            (m, K::Edit) => bail!(
                "the edit DOM is not addressable in mode {} — use mode edit",
                m.as_str()
            ),
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

        if self.clients.is_some() && mode != M::Play {
            bail!("--clients only applies to mode play (multiplayer session sizing)");
        }

        Ok(Resolved {
            mode,
            dom_kind,
            context,
            clients: self.clients,
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
        clients: Option<u32>,
    ) -> RouteSpec {
        RouteSpec { mode, dom_kind, context, clients }
    }

    #[test]
    fn defaults_table() {
        // (input spec, expected resolved (mode, dom_kind, context))
        let cases: &[(RouteSpec, (M, K, C))] = &[
            // bare run = edit plugin
            (spec(None, None, None, None), (M::Edit, K::Edit, C::Plugin)),
            // context alone implies mode + dom kind
            (spec(None, None, Some(C::Client), None), (M::Test, K::Client, C::Client)),
            (spec(None, None, Some(C::Server), None), (M::Run, K::Server, C::Server)),
            (spec(None, None, Some(C::Elevated), None), (M::Edit, K::Edit, C::Elevated)),
            (spec(None, None, Some(C::Plugin), None), (M::Edit, K::Edit, C::Plugin)),
            // dom kind alone implies mode + native context
            (spec(None, Some(K::Server), None, None), (M::Run, K::Server, C::Server)),
            (spec(None, Some(K::Client), None, None), (M::Test, K::Client, C::Client)),
            // mode alone → primary DOM + native context
            (spec(Some(M::Run), None, None, None), (M::Run, K::Server, C::Server)),
            (spec(Some(M::Test), None, None, None), (M::Test, K::Server, C::Server)),
            (spec(Some(M::Play), None, None, None), (M::Play, K::Server, C::Server)),
            (spec(Some(M::Edit), None, None, None), (M::Edit, K::Edit, C::Plugin)),
            // the old three-segment targets
            (spec(Some(M::Run), None, Some(C::Plugin), None), (M::Run, K::Server, C::Plugin)),
            (spec(Some(M::Test), Some(K::Client), Some(C::Plugin), None), (M::Test, K::Client, C::Plugin)),
            (spec(Some(M::Test), None, Some(C::Elevated), None), (M::Test, K::Server, C::Elevated)),
            (spec(Some(M::Test), Some(K::Client), Some(C::Elevated), None), (M::Test, K::Client, C::Elevated)),
            // mode + context implying dom kind
            (spec(Some(M::Test), None, Some(C::Client), None), (M::Test, K::Client, C::Client)),
            (spec(Some(M::Play), None, Some(C::Client), None), (M::Play, K::Client, C::Client)),
            // play sizing
            (spec(Some(M::Play), Some(K::Client), Some(C::Client), Some(2)), (M::Play, K::Client, C::Client)),
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
            spec(Some(M::Edit), Some(K::Server), None, None),
            spec(Some(M::Edit), Some(K::Client), None, None),
            spec(Some(M::Edit), None, Some(C::Client), None),
            spec(Some(M::Edit), None, Some(C::Server), None),
            // run mode has no client DOM
            spec(Some(M::Run), Some(K::Client), None, None),
            spec(Some(M::Run), None, Some(C::Client), None),
            // context/dom-kind mismatches
            spec(None, Some(K::Server), Some(C::Client), None),
            spec(None, Some(K::Client), Some(C::Server), None),
            // clients outside play
            spec(Some(M::Test), Some(K::Client), None, Some(2)),
            spec(None, None, None, Some(1)),
        ];
        for input in cases {
            assert!(input.resolve().is_err(), "{input:?} should be invalid");
        }
    }

    #[test]
    fn from_strings_roundtrip() {
        let s = RouteSpec::from_strings(Some("play"), Some("client"), Some("plugin"), Some(3)).unwrap();
        assert_eq!(
            s,
            spec(Some(M::Play), Some(K::Client), Some(C::Plugin), Some(3))
        );
        // empty strings are None
        assert!(RouteSpec::from_strings(Some(""), None, Some(""), None).unwrap().is_empty());
        // unknown words error
        assert!(RouteSpec::from_strings(Some("editt"), None, None, None).is_err());
        assert!(RouteSpec::from_strings(None, Some("edit"), None, None).is_err());
        assert!(RouteSpec::from_strings(None, None, Some("identity"), None).is_err());
    }
}
