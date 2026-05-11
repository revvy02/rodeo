//! Opportunistic test that validates `studio::layout::transform` against a
//! real plist snapshot captured at `/tmp/rodeo-plist-snapshot-1.plist`.
//! Skipped when the snapshot isn't present (CI and most dev machines).

#[test]
fn transform_real_snapshot_hides_more_panels() {
    let orig_path = "/tmp/rodeo-plist-snapshot-1.plist";
    if !std::path::Path::new(orig_path).exists() {
        eprintln!("skip: {orig_path} not present");
        return;
    }
    let orig = std::fs::read(orig_path).unwrap();
    let stripped = rbx_control::studio::layout::transform(&orig).expect("transform");

    let orig_val = plist::Value::from_reader(std::io::Cursor::new(&orig)).unwrap();
    let out_val = plist::Value::from_reader(std::io::Cursor::new(&stripped)).unwrap();

    for key in [
        "LayoutSettings.Docking.3.edit_",
        "LayoutSettings.Docking.3.play_",
        "LayoutSettings.Docking.3.pserv_",
    ] {
        let Some(orig_entry) = orig_val.as_dictionary().unwrap().get(key) else { continue };
        let orig_data = orig_entry.as_data().unwrap();
        let out_data = out_val
            .as_dictionary()
            .unwrap()
            .get(key)
            .unwrap()
            .as_data()
            .unwrap();

        let orig_s = std::str::from_utf8(orig_data).unwrap();
        let out_s = std::str::from_utf8(out_data).unwrap();

        let orig_empty = orig_s.matches("<Panels Count=\"0\"").count();
        let out_empty = out_s.matches("<Panels Count=\"0\"").count();
        eprintln!("{key}: orig Count=0 = {orig_empty}, stripped Count=0 = {out_empty}");

        assert!(
            out_empty >= orig_empty,
            "{key}: stripped should have >= empty containers than orig (got {out_empty} vs {orig_empty})"
        );
    }

    // Verify the top ribbon collapse bit is set to true in the output plist.
    let ribbon = out_val
        .as_dictionary()
        .unwrap()
        .get("rbxRibbonMinimized")
        .expect("rbxRibbonMinimized key missing from output plist");
    assert_eq!(
        ribbon.as_boolean(),
        Some(true),
        "expected rbxRibbonMinimized=true, got {ribbon:?}"
    );
}
