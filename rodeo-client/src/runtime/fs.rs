use rodeo_proto::runtime_types as rt;

pub fn fs_remove(req: &rt::FsRemoveRequest) -> Result<rt::Ok, String> {
    std::fs::remove_file(&req.path).map_err(|e| format!("remove error: {e}"))?;
    Ok(rt::Ok::default())
}

pub fn fs_stat(req: &rt::FsStatRequest) -> Result<rt::FsStatResponse, String> {
    let meta = std::fs::metadata(&req.path).map_err(|e| format!("stat error: {e}"))?;

    let file_type = if meta.is_file() { "file" } else if meta.is_dir() { "dir" } else { "unknown" };

    let to_ms = |t: std::io::Result<std::time::SystemTime>| -> Option<i64> {
        t.ok()?.duration_since(std::time::UNIX_EPOCH).ok().map(|d| d.as_millis() as i64)
    };

    Ok(rt::FsStatResponse {
        r#type: file_type.to_string(),
        size: meta.len() as i64,
        created_millis: to_ms(meta.created()),
        modified_millis: to_ms(meta.modified()),
        accessed_millis: to_ms(meta.accessed()),
        ..Default::default()
    })
}

pub fn fs_type(req: &rt::FsTypeRequest) -> Result<rt::FsTypeResponse, String> {
    let p = std::path::Path::new(&req.path);
    Ok(rt::FsTypeResponse {
        r#type: if p.is_file() {
            Some("file".to_string())
        } else if p.is_dir() {
            Some("dir".to_string())
        } else {
            None
        },
        ..Default::default()
    })
}

pub fn fs_mkdir(req: &rt::FsMkdirRequest) -> Result<rt::Ok, String> {
    std::fs::create_dir_all(&req.path).map_err(|e| format!("mkdir error: {e}"))?;
    Ok(rt::Ok::default())
}

pub fn fs_exists(req: &rt::FsExistsRequest) -> Result<rt::FsExistsResponse, String> {
    Ok(rt::FsExistsResponse {
        exists: std::path::Path::new(&req.path).exists(),
        ..Default::default()
    })
}

pub fn fs_copy(req: &rt::FsCopyRequest) -> Result<rt::Ok, String> {
    std::fs::copy(&req.src, &req.dest).map_err(|e| format!("copy error: {e}"))?;
    Ok(rt::Ok::default())
}

pub fn fs_listdir(req: &rt::FsListdirRequest) -> Result<rt::FsListdirResponse, String> {
    let entries: Vec<rt::FsDirEntry> = std::fs::read_dir(&req.path)
        .map_err(|e| format!("listdir error: {e}"))?
        .filter_map(|entry| {
            let entry = entry.ok()?;
            let name = entry.file_name().to_string_lossy().to_string();
            let entry_type = if entry.path().is_file() { "file" } else if entry.path().is_dir() { "dir" } else { "unknown" };
            Some(rt::FsDirEntry { name, r#type: entry_type.to_string(), ..Default::default() })
        })
        .collect();
    Ok(rt::FsListdirResponse { entries, ..Default::default() })
}

pub fn fs_rmdir(req: &rt::FsRmdirRequest) -> Result<rt::Ok, String> {
    std::fs::remove_dir(&req.path).map_err(|e| format!("rmdir error: {e}"))?;
    Ok(rt::Ok::default())
}
