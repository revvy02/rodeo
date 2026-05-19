use rodeo_proto::runtime_types as rt;

/// Handle `roblox.export`. Plugin sends binary bytes from
/// `SerializeInstancesAsync` + a destination path. If the path ends in
/// `.rbxmx`/`.rbxlx`, re-serialize the binary DOM as XML via rbx-binary →
/// rbx-xml; otherwise write the binary bytes through. Writes directly via
/// `std::fs::write` — this is the only RPC for `roblox.export`, no fs/stream
/// round-trip needed.
pub fn roblox_export(req: &rt::RobloxExportRequest) -> Result<rt::Ok, String> {
    let lower = req.path.to_lowercase();
    let is_xml = lower.ends_with(".rbxmx") || lower.ends_with(".rbxlx");

    let bytes_to_write: Vec<u8> = if is_xml {
        let dom = rbx_binary::from_reader(req.data.as_slice())
            .map_err(|e| format!("rbx-binary decode: {e}"))?;
        let root_refs: Vec<_> = dom.root().children().to_vec();
        let mut out = Vec::new();
        rbx_xml::to_writer_default(&mut out, &dom, &root_refs)
            .map_err(|e| format!("rbx-xml encode: {e}"))?;
        out
    } else {
        req.data.clone()
    };

    std::fs::write(&req.path, &bytes_to_write)
        .map_err(|e| format!("write {}: {e}", req.path))?;

    Ok(rt::Ok::default())
}
