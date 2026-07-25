use super::{stream, SharedRpcState};
use rodeo_proto::runtime_types as rt;

/// Finalize a `roblox.export`. The plugin has streamed the binary bytes from
/// `SerializeInstancesAsync` into a FileWriter via chunked
/// `stream.writeBytes`; this consumes the handle in place of `stream_close`.
/// If the destination ends in `.rbxmx`/`.rbxlx`, re-serialize the binary DOM
/// as XML via rbx-binary → rbx-xml; otherwise write the binary bytes through.
/// Writes atomically (`.tmp` + rename) so a failed export leaves no partial
/// file.
pub async fn roblox_export(state: SharedRpcState, req: &rt::RobloxExportRequest) -> Result<rt::Ok, String> {
    let (path, buffer) = stream::take_file_writer(&state, &req.handle).await?;

    let lower = path.to_lowercase();
    let is_xml = lower.ends_with(".rbxmx") || lower.ends_with(".rbxlx");

    let bytes_to_write: Vec<u8> = if is_xml {
        let dom = rbx_binary::from_reader(buffer.as_slice())
            .map_err(|e| format!("rbx-binary decode: {e}"))?;
        let root_refs: Vec<_> = dom.root().children().to_vec();
        let mut out = Vec::new();
        rbx_xml::to_writer_default(&mut out, &dom, &root_refs)
            .map_err(|e| format!("rbx-xml encode: {e}"))?;
        out
    } else {
        buffer
    };

    if let Some(parent) = std::path::Path::new(&path).parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)
                .map_err(|e| format!("create parent dirs for {}: {e}", parent.display()))?;
        }
    }

    let tmp = format!("{path}.tmp");
    std::fs::write(&tmp, &bytes_to_write).map_err(|e| format!("write {tmp}: {e}"))?;
    std::fs::rename(&tmp, &path).map_err(|e| {
        let _ = std::fs::remove_file(&tmp);
        format!("rename {tmp} -> {path}: {e}")
    })?;

    Ok(rt::Ok::default())
}
