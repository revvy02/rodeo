//! `--show-widgets` Studio UI strip: patch `~/Library/Preferences/com.roblox.RobloxStudio.plist`
//! so Studio opens with only an allow-listed set of dock widgets visible
//! (Explorer / Properties / Toolbox / Output / etc. hidden by default).
//!
//! # Semantics
//!
//! `--show-widgets` is an allow-list. Whatever isn't named is hidden:
//!
//! - `--show-widgets none`            → hide everything (dock widgets + ribbon + command bar)
//! - `--show-widgets output`          → show only Output; the rest hidden
//! - `--show-widgets output,ribbon`   → show Output and keep the top ribbon
//!
//! Names are friendly aliases (see [`resolve_alias`]), the specials `ribbon`
//! and `commandbar`, or a raw Qtitan panel ID (e.g.
//! `edit_user_rodeo.rbxm_Rodeo-44873`) for anything unmapped.
//!
//! # Where this lives in the plist
//!
//! Studio persists its Qtitan dock layout in three keys:
//!
//! - `LayoutSettings.Docking.3.edit_`   — edit mode
//! - `LayoutSettings.Docking.3.play_`   — play-test mode
//! - `LayoutSettings.Docking.3.pserv_`  — server-run mode
//!
//! Each is `Data` (raw bytes) containing a UTF-8 XML document of the form:
//!
//! ```xml
//! <DockPanelLayouts xmlns:Qtitan="..." version="1.3">
//!   <Panels Count="113">
//!     <Panel ID="Layout0" Type="1" ...><Panels Count="1">...</Panels></Panel>
//!     ...
//!     <Panel ID="propertiesWidgetPanel" Type="Qtitan::DockWidgetPanel" Active="True">...</Panel>
//!     ...
//!   </Panels>
//! </DockPanelLayouts>
//! ```
//!
//! We hide every Qtitan dock panel — both `Qtitan::DockWidgetPanel`
//! (Properties / Explorer / Toolbox / Output / plugin UIs) and
//! `Qtitan::DockDocumentPanel` (the script editor tabset) — *except* the panel
//! IDs in the keep-set. Structural layout containers (`Type="1"/"2"/"4"/"5"`)
//! and the panel *definitions* at the top of `<DockPanelLayouts>` are
//! preserved — only the reference stubs inside layout containers are removed.
//! The transform:
//! 1. Scans all `<Panel>` definitions; any with a `Type` attribute starting
//!    with `Qtitan::Dock` whose ID is *not* in the keep-set is marked hidden.
//! 2. Walks every `<Panels Count="N">` container; removes reference stubs
//!    (`<Panel ID="…"/>` with no Type attr) pointing at hidden panels and
//!    updates `Count` accordingly. Leaves panel definitions (with a Type)
//!    alone — removing them invalidates the layout and Studio regenerates
//!    defaults.
//! 3. Strips `Active="True"` from hidden panels' own definition blocks.
//!
//! Computed on the fly rather than embedding a captured XML, so machine-
//! specific `DockCX`/`DockCY` sizing is preserved.
//!
//! # Caveat
//!
//! Studio writes layout back on close. [`filepatch`]'s restore clobbers that
//! write (by design). Layout changes made inside a rodeo-launched
//! `--show-widgets` Studio do not persist to the user's on-disk plist. This is
//! intentional — leaves the user's normal Studio launches unaffected.

use anyhow::{Context, Result};
use std::collections::HashSet;
use std::path::PathBuf;
use xmltree::{Element, XMLNode};

/// Type-attribute prefix identifying every dock panel we strip. Matches both
/// `Qtitan::DockWidgetPanel` (Properties/Explorer/Toolbox/plugin UIs) and
/// `Qtitan::DockDocumentPanel` (the script editor tabset). Layout-container
/// panels (numeric Type values "1"/"2"/"4"/"5") don't match this prefix and
/// are left intact as structural scaffolding.
const HIDE_TYPE_PREFIX: &str = "Qtitan::Dock";

/// Resolve a friendly widget name to its Qtitan panel ID. Returns `None` for
/// names that aren't aliases (specials like `ribbon`/`commandbar` are handled
/// separately; anything else is treated as a raw panel ID). Alias targets are
/// the stable IDs verified across edit / play layouts.
fn resolve_alias(name: &str) -> Option<&'static str> {
    Some(match name {
        "output" => "outputWidgetPanel",
        "properties" => "propertiesWidgetPanel",
        "explorer" => "rplg_sabuiltin_ExplorerPlugin.rbxm_ExplorerPlugin",
        "editor" | "scripts" => "ideDocDocumentPanel",
        "toolbox" => "edit_builtin_Toolbox.rbxm_Toolbox",
        "assistant" => "rplg_sabuiltin_Assistant.rbxm_Assistant",
        _ => return None,
    })
}

/// Parsed `--show-widgets` allow-list: which dock panels to keep, plus whether
/// to keep the top ribbon and bottom command bar.
#[derive(Debug, Default)]
pub struct KeepSpec {
    /// Panel IDs to leave visible. Empty = hide every dock widget.
    panel_ids: HashSet<String>,
    keep_ribbon: bool,
    keep_commandbar: bool,
}

impl KeepSpec {
    /// Parse a comma-separated `--show-widgets` spec. `none` (and empty
    /// entries) contribute nothing, so `--show-widgets none` yields an empty
    /// keep-set (hide everything). Names are friendly aliases, the specials
    /// `ribbon` / `commandbar`, or raw panel IDs (case-sensitive).
    pub fn parse(spec: &str) -> Self {
        let mut keep = KeepSpec::default();
        for raw in spec.split(',') {
            let name = raw.trim();
            if name.is_empty() || name.eq_ignore_ascii_case("none") {
                continue;
            }
            match name.to_ascii_lowercase().as_str() {
                "ribbon" => keep.keep_ribbon = true,
                "commandbar" => keep.keep_commandbar = true,
                lower => {
                    if let Some(id) = resolve_alias(lower) {
                        keep.panel_ids.insert(id.to_string());
                    } else {
                        // Not an alias — treat as a raw Qtitan panel ID.
                        keep.panel_ids.insert(name.to_string());
                    }
                }
            }
        }
        keep
    }
}

/// The three plist keys we strip. Applied uniformly so `--show-widgets` stays
/// effective across edit / play-test / server-run transitions.
const LAYOUT_KEYS: &[&str] = &[
    "LayoutSettings.Docking.3.edit_",
    "LayoutSettings.Docking.3.play_",
    "LayoutSettings.Docking.3.pserv_",
];

/// Boolean plist key that collapses Studio's top ribbon (File / Home / Model
/// / Test menu bar). Set to `true` unless the spec keeps `ribbon`.
const RIBBON_MINIMIZED_KEY: &str = "rbxRibbonMinimized";

/// Plist keys holding the `QMainWindow::saveState` blob that contains named
/// toolbar visibility flags — including `commandToolBar` (the Luau command bar
/// at the bottom of Studio). Studio keeps a separate blob per ribbon UI:
/// `window_state_ribbon` (classic) and `window_state_beta_ribbon` (ribbon
/// beta, gated by `IsEnrolledInRibbonBeta`). Only one is live at a time, so we
/// patch whichever exist — otherwise a user on the other UI gets no effect.
const WINDOW_STATE_KEYS: &[&str] = &[
    "LayoutSettings.window_state_ribbon",
    "LayoutSettings.window_state_beta_ribbon",
];

/// Locate Studio's preferences plist.
fn plist_path() -> Result<PathBuf> {
    let home = dirs::home_dir().context("could not resolve home dir")?;
    Ok(home
        .join("Library")
        .join("Preferences")
        .join("com.roblox.RobloxStudio.plist"))
}

/// Apply the UI strip for a `--show-widgets` spec, returning a handle that
/// restores the plist on drop. Everything not named in `spec` is hidden;
/// `spec = "none"` hides everything.
///
/// Returns `Ok(None)` only in the unlikely case that the plist doesn't exist
/// at all (a fresh Studio install that's never run). In that case there's no
/// layout to strip yet — Studio will generate defaults on first launch.
pub fn apply_show_widgets(spec: &str) -> Result<Option<filepatch::Handle>> {
    let keep = KeepSpec::parse(spec);
    let path = plist_path()?;
    if !path.exists() {
        tracing::warn!(path = %path.display(), "show-widgets: plist absent; skipping");
        return Ok(None);
    }

    let handle = filepatch::apply(&path, move |orig| {
        let bytes = orig.context("show-widgets: plist disappeared between check and apply")?;
        transform(bytes, &keep)
    })?;
    tracing::info!(path = %path.display(), "show-widgets: plist patched");
    Ok(Some(handle))
}

/// Apply the panel-strip transform to the entire plist payload, keeping the
/// panels named in `keep`. Public for unit testing.
pub fn transform(orig: &[u8], keep: &KeepSpec) -> Result<Vec<u8>> {
    let is_binary = orig.starts_with(b"bplist");

    let mut value = plist::Value::from_reader(std::io::Cursor::new(orig))
        .context("parse Studio plist")?;

    let dict = value
        .as_dictionary_mut()
        .context("plist root is not a dictionary")?;

    for key in LAYOUT_KEYS {
        let Some(entry) = dict.get_mut(*key) else { continue };
        let Some(data_bytes) = entry.as_data() else { continue };
        let stripped = strip_panels(data_bytes, keep).with_context(|| format!("strip {key}"))?;
        *entry = plist::Value::Data(stripped);
    }

    // Collapse the top ribbon (File / Home / Model / Test menu bar) unless kept.
    // Forced both ways so the allow-list is authoritative regardless of the
    // user's saved ribbon state: listed `ribbon` -> shown, unlisted -> minimized.
    dict.insert(RIBBON_MINIMIZED_KEY.to_string(), plist::Value::Boolean(!keep.keep_ribbon));

    // Hide the command bar (unless kept) by flipping its visibility byte inside
    // the QMainWindow::saveState blob — for both ribbon-UI variants.
    if !keep.keep_commandbar {
        for key in WINDOW_STATE_KEYS {
            if let Some(entry) = dict.get_mut(*key) {
                if let Some(bytes) = entry.as_data() {
                    let patched = hide_command_toolbar(bytes);
                    *entry = plist::Value::Data(patched);
                }
            }
        }
    }

    let mut out = Vec::with_capacity(orig.len());
    if is_binary {
        plist::to_writer_binary(&mut out, &value).context("serialize plist (binary)")?;
    } else {
        plist::to_writer_xml(&mut out, &value).context("serialize plist (xml)")?;
    }
    Ok(out)
}

/// Flip the visibility byte of the `commandToolBar` entry in a
/// `QMainWindow::saveState` blob from `0x01` (visible) to `0x00` (hidden).
///
/// Qt serializes each toolbar as: `<4-byte BE length> <UTF-16 BE name bytes>
/// <1-byte visibility> <… rest …>`. We locate the UTF-16 BE byte sequence for
/// `"commandToolBar"` and clear the byte that immediately follows it. No-op
/// if the pattern isn't found (different Qt/Studio version) — leaves the
/// blob unchanged.
fn hide_command_toolbar(bytes: &[u8]) -> Vec<u8> {
    let name_utf16_be: Vec<u8> = "commandToolBar"
        .encode_utf16()
        .flat_map(|u| u.to_be_bytes())
        .collect();

    let mut out = bytes.to_vec();
    if let Some(pos) = find_subslice(&out, &name_utf16_be) {
        let flag_idx = pos + name_utf16_be.len();
        if flag_idx < out.len() && out[flag_idx] == 0x01 {
            out[flag_idx] = 0x00;
        }
    }
    out
}

fn find_subslice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    if needle.is_empty() || needle.len() > haystack.len() {
        return None;
    }
    haystack
        .windows(needle.len())
        .position(|w| w == needle)
}

/// Apply the hide transform to a single dock layout XML payload (the bytes
/// stored in one of the `LayoutSettings.Docking.3.*_` keys). Panels whose ID is
/// in `keep.panel_ids` are left visible.
fn strip_panels(xml: &[u8], keep: &KeepSpec) -> Result<Vec<u8>> {
    let mut root = Element::parse(xml).context("parse dock layout XML")?;

    // Pass 1: collect IDs of every widget panel (definition has a Type attr
    // equal to HIDE_TYPE) that isn't in the keep-set. These are the IDs we
    // remove from containers and deactivate in their definitions.
    let mut hidden: HashSet<String> = Default::default();
    collect_hidden(&root, &keep.panel_ids, &mut hidden);

    // Pass 2: walk containers → drop hidden child references, decrement
    // Count. Walk widget definitions → strip Active="True".
    walk(&mut root, &hidden);

    let mut out = Vec::with_capacity(xml.len());
    root.write(&mut out).context("serialize dock layout XML")?;
    Ok(out)
}

/// Collect every ID whose definition is a widget panel (to be hidden), except
/// those in `keep`. A definition is distinguished by having a `Type` attribute.
fn collect_hidden(elem: &Element, keep: &HashSet<String>, out: &mut HashSet<String>) {
    if elem.name == "Panel" {
        let (Some(id), Some(ty)) = (elem.attributes.get("ID"), elem.attributes.get("Type")) else {
            // Not a definition — either a child reference or a layout container.
            for child in &elem.children {
                if let XMLNode::Element(c) = child {
                    collect_hidden(c, keep, out);
                }
            }
            return;
        };
        // All Qtitan::Dock*Panel types are hidden (Widget + Document) unless
        // kept. Layout-container panels (numeric Type values) don't match this
        // prefix and stay intact.
        if ty.starts_with(HIDE_TYPE_PREFIX) && !keep.contains(id) {
            out.insert(id.clone());
        }
    }
    for child in &elem.children {
        if let XMLNode::Element(c) = child {
            collect_hidden(c, keep, out);
        }
    }
}

fn walk(elem: &mut Element, hidden: &std::collections::HashSet<String>) {
    // If this is a widget-panel definition in the hidden set, strip Active.
    if elem.name == "Panel" {
        let is_hidden = elem
            .attributes
            .get("ID")
            .map(|id| hidden.contains(id))
            .unwrap_or(false);
        if is_hidden {
            elem.attributes.remove("Active");
        }
    }

    // If this is a <Panels> container listing child references, drop
    // references to hidden panels and update Count.
    //
    // Crucial distinction: `<Panel ID=X/>` (no Type attr) is a reference
    // stub inside a layout container — remove if hidden. `<Panel ID=X
    // Type=…>` is a full panel definition in the top-level list — keep
    // all of them (Studio needs every definition to exist; we strip Active
    // in the Panel-matching branch above instead).
    if elem.name == "Panels" {
        elem.children.retain(|node| match node {
            XMLNode::Element(c) if c.name == "Panel" => {
                let is_reference_stub = !c.attributes.contains_key("Type");
                let is_hidden = c
                    .attributes
                    .get("ID")
                    .map(|id| hidden.contains(id))
                    .unwrap_or(false);
                // Drop only reference stubs to hidden panels.
                !(is_reference_stub && is_hidden)
            }
            _ => true,
        });
        let new_count = elem
            .children
            .iter()
            .filter(|n| matches!(n, XMLNode::Element(_)))
            .count();
        elem.attributes
            .insert("Count".to_string(), new_count.to_string());
    }

    for child in elem.children.iter_mut() {
        if let XMLNode::Element(c) = child {
            walk(c, hidden);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strip_hides_all_widget_panels() {
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<DockPanelLayouts xmlns:Qtitan="https://www.devmachines.com/qt/qtitan" type="layoutPanel" version="1.3">
    <Panels Count="3">
        <Panel ID="Layout2" Type="2" DockCX="1447" DockCY="189">
            <Panels Count="1">
                <Panel ID="outputWidgetPanel"/>
            </Panels>
        </Panel>
        <Panel ID="Layout48" Type="2" DockCX="-1" DockCY="-1">
            <Panels Count="1">
                <Panel ID="pserv_cloud_6045494621_qwreey.plugins.iconpack"/>
            </Panels>
        </Panel>
        <Panel ID="outputWidgetPanel" Type="Qtitan::DockWidgetPanel" DockCX="-1" DockCY="-1" Active="True">
            <Layouts><DockingLayout ID="Layout2"/></Layouts>
        </Panel>
        <Panel ID="pserv_cloud_6045494621_qwreey.plugins.iconpack" Type="Qtitan::DockWidgetPanel" DockCX="-1" DockCY="-1" Active="True"/>
    </Panels>
</DockPanelLayouts>"#;

        let out = strip_panels(xml.as_bytes(), &KeepSpec::default()).unwrap();
        let out_str = String::from_utf8(out).unwrap();

        // Both widget-panel containers are emptied. Count updates to 0.
        assert!(
            out_str.matches(r#"<Panels Count="0""#).count() >= 2,
            "expected 2+ empty containers; got:\n{out_str}"
        );
        // No Active="True" survives on any widget (user plugin included).
        assert!(
            !out_str.contains(r#"Active="True""#),
            "expected Active stripped on all widget panels; got:\n{out_str}"
        );
    }

    #[test]
    fn strip_removes_hidden_from_tabbed_container() {
        // propertiesWidgetPanel tabbed with Assistant — our walker drops
        // both (both are widget panels), leaving the container empty.
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<DockPanelLayouts>
    <Panels Count="3">
        <Panel ID="Layout48" Type="2">
            <Panels Count="2">
                <Panel ID="propertiesWidgetPanel"/>
                <Panel ID="rplg_sabuiltin_Assistant.rbxm_Assistant"/>
            </Panels>
        </Panel>
        <Panel ID="propertiesWidgetPanel" Type="Qtitan::DockWidgetPanel" Active="True"/>
        <Panel ID="rplg_sabuiltin_Assistant.rbxm_Assistant" Type="Qtitan::DockWidgetPanel" Active="True"/>
    </Panels>
</DockPanelLayouts>"#;

        let out = strip_panels(xml.as_bytes(), &KeepSpec::default()).unwrap();
        let out_str = String::from_utf8(out).unwrap();
        assert!(out_str.contains(r#"<Panels Count="0""#));
        assert!(!out_str.contains(r#"Active="True""#));
    }

    #[test]
    fn strip_hides_document_panel_reference_but_keeps_definition() {
        // DockDocumentPanel is hidden like other widget panels — reference
        // stub removed from its container, Active stripped from its
        // definition. The DEFINITION itself is preserved (removing it
        // breaks Qtitan's layout validation).
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<DockPanelLayouts>
    <Panels Count="2">
        <Panel ID="Layout22" Type="2">
            <Panels Count="1">
                <Panel ID="ideDocDocumentPanel"/>
            </Panels>
        </Panel>
        <Panel ID="ideDocDocumentPanel" Type="Qtitan::DockDocumentPanel" Active="True"/>
    </Panels>
</DockPanelLayouts>"#;

        let out = strip_panels(xml.as_bytes(), &KeepSpec::default()).unwrap();
        let out_str = String::from_utf8(out).unwrap();
        // Reference stub's container now empty.
        assert!(out_str.contains(r#"<Panels Count="0""#));
        // Active stripped.
        assert!(!out_str.contains(r#"Active="True""#));
        // But the DEFINITION survives (layout-validity requirement).
        assert!(out_str.contains(r#"Type="Qtitan::DockDocumentPanel""#));
    }

    #[test]
    fn hide_command_toolbar_flips_visibility_byte() {
        let name: Vec<u8> = "commandToolBar"
            .encode_utf16()
            .flat_map(|u| u.to_be_bytes())
            .collect();
        let mut blob = vec![0xff, 0xfe, 0x00, 0x00, 0x00, 0x1c];
        blob.extend(&name);
        blob.extend(&[0x01, 0xde, 0xad]);
        let out = hide_command_toolbar(&blob);
        let flag_idx = 6 + name.len();
        assert_eq!(out[flag_idx], 0x00, "visibility byte should flip to 0x00");
        assert_eq!(&out[..6], &blob[..6], "prefix preserved");
        assert_eq!(&out[flag_idx + 1..], &blob[flag_idx + 1..], "suffix preserved");
    }

    #[test]
    fn hide_command_toolbar_noop_if_name_absent() {
        let blob = vec![0xde, 0xad, 0xbe, 0xef];
        assert_eq!(hide_command_toolbar(&blob), blob);
    }

    #[test]
    fn keep_set_leaves_allowlisted_panel_visible() {
        // outputWidgetPanel is in the keep-set; propertiesWidgetPanel is not.
        // The Output reference + Active survive; Properties is stripped.
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<DockPanelLayouts>
    <Panels Count="4">
        <Panel ID="Layout2" Type="2">
            <Panels Count="1"><Panel ID="outputWidgetPanel"/></Panels>
        </Panel>
        <Panel ID="Layout3" Type="2">
            <Panels Count="1"><Panel ID="propertiesWidgetPanel"/></Panels>
        </Panel>
        <Panel ID="outputWidgetPanel" Type="Qtitan::DockWidgetPanel" Active="True"/>
        <Panel ID="propertiesWidgetPanel" Type="Qtitan::DockWidgetPanel" Active="True"/>
    </Panels>
</DockPanelLayouts>"#;

        let keep = KeepSpec::parse("output");
        let out = strip_panels(xml.as_bytes(), &keep).unwrap();
        let out_str = String::from_utf8(out).unwrap();
        // Output's reference stub survives; Properties' container is emptied.
        assert!(out_str.contains(r#"<Panel ID="outputWidgetPanel" />"#),
            "expected output reference kept; got:\n{out_str}");
        assert!(out_str.contains(r#"<Panels Count="0""#),
            "expected properties container emptied; got:\n{out_str}");
        // Exactly one Active="True" survives — the kept Output panel.
        // (xmltree may reorder attributes, so assert order-independently.)
        assert_eq!(out_str.matches(r#"Active="True""#).count(), 1,
            "expected only Output to stay Active; got:\n{out_str}");
        assert!(out_str.contains(r#"ID="outputWidgetPanel""#) && out_str.contains(r#"Active="True""#),
            "expected Output to be the Active panel; got:\n{out_str}");
    }

    #[test]
    fn parse_maps_aliases_specials_and_raw_ids() {
        let keep = KeepSpec::parse("output, ribbon, edit_user_rodeo.rbxm_Rodeo-44873, commandbar");
        assert!(keep.panel_ids.contains("outputWidgetPanel"));
        assert!(keep.panel_ids.contains("edit_user_rodeo.rbxm_Rodeo-44873"));
        assert!(keep.keep_ribbon);
        assert!(keep.keep_commandbar);

        let none = KeepSpec::parse("none");
        assert!(none.panel_ids.is_empty());
        assert!(!none.keep_ribbon && !none.keep_commandbar);
    }

    #[test]
    fn strip_leaves_layout_containers_alone() {
        // Layout containers (Type="1"/"2"/…) must NOT be in the hidden set —
        // they're the structural scaffolding, not the panels we're stripping.
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<DockPanelLayouts>
    <Panels Count="2">
        <Panel ID="Layout0" Type="1" Horizontal="True">
            <Panels Count="1"><Panel ID="Layout1"/></Panels>
        </Panel>
        <Panel ID="Layout1" Type="2"><Panels Count="0"/></Panel>
    </Panels>
</DockPanelLayouts>"#;

        let out = strip_panels(xml.as_bytes(), &KeepSpec::default()).unwrap();
        let out_str = String::from_utf8(out).unwrap();
        // Both layout containers survive intact (including their cross-refs).
        assert!(out_str.contains(r#"ID="Layout0""#));
        assert!(out_str.contains(r#"ID="Layout1""#));
    }
}
