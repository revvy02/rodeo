use super::{SharedRpcState, StreamHandler};
use rodeo_proto::runtime_types as rt;
use std::io::{BufRead, Read};

const DEFAULT_CHUNK_SIZE: u32 = 4096;

pub async fn stream_open(state: SharedRpcState, req: &rt::StreamOpenRequest) -> Result<rt::StreamOpenResponse, String> {
    let handler = match req.mode.as_str() {
        "r" => {
            let file = std::fs::File::open(&req.path).map_err(|e| format!("open error: {e}"))?;
            StreamHandler::FileReader {
                reader: std::io::BufReader::new(file),
            }
        }
        "w" => StreamHandler::FileWriter {
            path: req.path.clone(),
            buffer: Vec::new(),
        },
        "a" => {
            let existing = if std::path::Path::new(&req.path).is_file() {
                std::fs::read(&req.path).unwrap_or_default()
            } else {
                Vec::new()
            };
            StreamHandler::FileAppender {
                path: req.path.clone(),
                buffer: existing,
            }
        }
        m => return Err(format!("invalid mode: {m}")),
    };
    state.lock().await.stream_handlers.insert(req.handle.clone(), handler);
    Ok(rt::StreamOpenResponse { handle: req.handle.clone(), ..Default::default() })
}

pub async fn stream_read_chunk(state: SharedRpcState, req: &rt::StreamReadChunkRequest) -> Result<rt::StreamReadChunkResponse, String> {
    let size = req.size.unwrap_or(DEFAULT_CHUNK_SIZE) as usize;

    if req.handle == "stdin" {
        return tokio::task::spawn_blocking(move || {
            let mut buf = vec![0u8; size];
            let n = std::io::stdin().lock().read(&mut buf).map_err(|e| format!("stdin read: {e}"))?;
            Ok(rt::StreamReadChunkResponse {
                data: String::from_utf8_lossy(&buf[..n]).to_string(),
                eof: n == 0,
                ..Default::default()
            })
        })
        .await
        .map_err(|e| format!("task error: {e}"))?;
    }

    let mut guard = state.lock().await;
    let handler = guard
        .stream_handlers
        .get_mut(&req.handle)
        .ok_or_else(|| format!("no reader for handle: {}", req.handle))?;

    match handler {
        StreamHandler::ProcessStdout { stdout } => {
            use tokio::io::AsyncReadExt;
            let reader = stdout.as_mut().ok_or("stdout not available")?;
            let mut chunk = vec![0u8; size];
            let n = reader.read(&mut chunk).await.map_err(|e| format!("read error: {e}"))?;
            Ok(rt::StreamReadChunkResponse {
                data: String::from_utf8_lossy(&chunk[..n]).to_string(),
                eof: n == 0,
                ..Default::default()
            })
        }
        StreamHandler::ProcessStderr { stderr } => {
            use tokio::io::AsyncReadExt;
            let reader = stderr.as_mut().ok_or("stderr not available")?;
            let mut chunk = vec![0u8; size];
            let n = reader.read(&mut chunk).await.map_err(|e| format!("read error: {e}"))?;
            Ok(rt::StreamReadChunkResponse {
                data: String::from_utf8_lossy(&chunk[..n]).to_string(),
                eof: n == 0,
                ..Default::default()
            })
        }
        StreamHandler::FileReader { reader } => {
            let mut chunk = vec![0u8; size];
            let n = reader.read(&mut chunk).map_err(|e| format!("read error: {e}"))?;
            Ok(rt::StreamReadChunkResponse {
                data: String::from_utf8_lossy(&chunk[..n]).to_string(),
                eof: n == 0,
                ..Default::default()
            })
        }
        _ => Err(format!("handle not readable: {}", req.handle)),
    }
}

pub async fn stream_read_line(state: SharedRpcState, req: &rt::StreamReadLineRequest) -> Result<rt::StreamReadLineResponse, String> {
    if req.handle == "stdin" {
        return tokio::task::spawn_blocking(|| {
            let mut line = String::new();
            let n = std::io::stdin().lock().read_line(&mut line).map_err(|e| format!("stdin read: {e}"))?;
            strip_newline(&mut line);
            Ok(rt::StreamReadLineResponse { data: line, eof: n == 0, ..Default::default() })
        })
        .await
        .map_err(|e| format!("task error: {e}"))?;
    }

    let mut guard = state.lock().await;
    let handler = guard
        .stream_handlers
        .get_mut(&req.handle)
        .ok_or_else(|| format!("no reader for handle: {}", req.handle))?;

    match handler {
        StreamHandler::ProcessStdout { stdout } => {
            read_line_async(stdout.as_mut().ok_or("stdout not available")?).await
        }
        StreamHandler::ProcessStderr { stderr } => {
            read_line_async(stderr.as_mut().ok_or("stderr not available")?).await
        }
        StreamHandler::FileReader { reader } => {
            let mut line = String::new();
            let n = reader.read_line(&mut line).map_err(|e| format!("read error: {e}"))?;
            strip_newline(&mut line);
            Ok(rt::StreamReadLineResponse { data: line, eof: n == 0, ..Default::default() })
        }
        _ => Err(format!("handle not readable: {}", req.handle)),
    }
}

pub async fn stream_read_all(state: SharedRpcState, req: &rt::StreamReadAllRequest) -> Result<rt::StreamReadAllResponse, String> {
    if req.handle == "stdin" {
        return tokio::task::spawn_blocking(|| {
            let mut buf = String::new();
            std::io::stdin().lock().read_to_string(&mut buf).map_err(|e| format!("stdin read: {e}"))?;
            Ok(rt::StreamReadAllResponse { data: buf, ..Default::default() })
        })
        .await
        .map_err(|e| format!("task error: {e}"))?;
    }

    let mut guard = state.lock().await;
    let handler = guard
        .stream_handlers
        .get_mut(&req.handle)
        .ok_or_else(|| format!("no reader for handle: {}", req.handle))?;

    match handler {
        StreamHandler::ProcessStdout { stdout } => {
            use tokio::io::AsyncReadExt;
            let reader = stdout.as_mut().ok_or("stdout not available")?;
            let mut buf = String::new();
            reader.read_to_string(&mut buf).await.map_err(|e| format!("read error: {e}"))?;
            Ok(rt::StreamReadAllResponse { data: buf, ..Default::default() })
        }
        StreamHandler::ProcessStderr { stderr } => {
            use tokio::io::AsyncReadExt;
            let reader = stderr.as_mut().ok_or("stderr not available")?;
            let mut buf = String::new();
            reader.read_to_string(&mut buf).await.map_err(|e| format!("read error: {e}"))?;
            Ok(rt::StreamReadAllResponse { data: buf, ..Default::default() })
        }
        StreamHandler::FileReader { reader } => {
            let mut buf = String::new();
            reader.read_to_string(&mut buf).map_err(|e| format!("read error: {e}"))?;
            Ok(rt::StreamReadAllResponse { data: buf, ..Default::default() })
        }
        _ => Err(format!("handle not readable: {}", req.handle)),
    }
}

pub async fn stream_write(state: SharedRpcState, req: &rt::StreamWriteRequest) -> Result<rt::Ok, String> {
    let mut guard = state.lock().await;
    // Capture the sender up-front — `handler` below holds a mutable borrow
    // on stream_handlers that would conflict with a later `guard.` access.
    let captured_tx = guard.captured_output_tx.clone();
    if let Some(handler) = guard.stream_handlers.get_mut(&req.handle) {
        match handler {
            StreamHandler::Stdout => {
                let _ = captured_tx.send((super::CapturedStreamKind::Stdout, req.data.as_bytes().to_vec()));
            }
            StreamHandler::Stderr => {
                let _ = captured_tx.send((super::CapturedStreamKind::Stderr, req.data.as_bytes().to_vec()));
            }
            StreamHandler::FileWriter { buffer, .. } => {
                buffer.extend_from_slice(req.data.as_bytes());
            }
            StreamHandler::FileAppender { buffer, .. } => {
                buffer.extend_from_slice(req.data.as_bytes());
            }
            StreamHandler::ProcessStdin { stdin } => {
                use tokio::io::AsyncWriteExt;
                if let Some(writer) = stdin.as_mut() {
                    let _ = writer.write_all(req.data.as_bytes()).await;
                    let _ = writer.flush().await;
                }
            }
            _ => {
                tracing::debug!("stream.write: no writer for '{}'", req.handle);
            }
        }
    } else {
        tracing::debug!("stream.write: no handler for '{}'", req.handle);
    }
    Ok(rt::Ok::default())
}

pub async fn stream_read_bytes(state: SharedRpcState, req: &rt::StreamReadBytesRequest) -> Result<rt::StreamReadBytesResponse, String> {
    if req.handle == "stdin" {
        return tokio::task::spawn_blocking(|| {
            let mut buf = Vec::new();
            std::io::stdin().lock().read_to_end(&mut buf).map_err(|e| format!("stdin read: {e}"))?;
            Ok(rt::StreamReadBytesResponse { data: buf, ..Default::default() })
        })
        .await
        .map_err(|e| format!("task error: {e}"))?;
    }

    let mut guard = state.lock().await;
    let handler = guard
        .stream_handlers
        .get_mut(&req.handle)
        .ok_or_else(|| format!("no reader for handle: {}", req.handle))?;

    match handler {
        StreamHandler::ProcessStdout { stdout } => {
            use tokio::io::AsyncReadExt;
            let reader = stdout.as_mut().ok_or("stdout not available")?;
            let mut buf = Vec::new();
            reader.read_to_end(&mut buf).await.map_err(|e| format!("read error: {e}"))?;
            Ok(rt::StreamReadBytesResponse { data: buf, ..Default::default() })
        }
        StreamHandler::ProcessStderr { stderr } => {
            use tokio::io::AsyncReadExt;
            let reader = stderr.as_mut().ok_or("stderr not available")?;
            let mut buf = Vec::new();
            reader.read_to_end(&mut buf).await.map_err(|e| format!("read error: {e}"))?;
            Ok(rt::StreamReadBytesResponse { data: buf, ..Default::default() })
        }
        StreamHandler::FileReader { reader } => {
            let mut buf = Vec::new();
            reader.read_to_end(&mut buf).map_err(|e| format!("read error: {e}"))?;
            Ok(rt::StreamReadBytesResponse { data: buf, ..Default::default() })
        }
        _ => Err(format!("handle not readable: {}", req.handle)),
    }
}

pub async fn stream_write_bytes(state: SharedRpcState, req: &rt::StreamWriteBytesRequest) -> Result<rt::Ok, String> {
    let mut guard = state.lock().await;
    let captured_tx = guard.captured_output_tx.clone();
    if let Some(handler) = guard.stream_handlers.get_mut(&req.handle) {
        match handler {
            StreamHandler::Stdout => {
                let _ = captured_tx.send((super::CapturedStreamKind::Stdout, req.data.clone()));
            }
            StreamHandler::Stderr => {
                let _ = captured_tx.send((super::CapturedStreamKind::Stderr, req.data.clone()));
            }
            StreamHandler::FileWriter { buffer, .. } => {
                buffer.extend_from_slice(&req.data);
            }
            StreamHandler::FileAppender { buffer, .. } => {
                buffer.extend_from_slice(&req.data);
            }
            StreamHandler::ProcessStdin { stdin } => {
                use tokio::io::AsyncWriteExt;
                if let Some(writer) = stdin.as_mut() {
                    let _ = writer.write_all(&req.data).await;
                    let _ = writer.flush().await;
                }
            }
            _ => {
                tracing::debug!("stream.writeBytes: no writer for '{}'", req.handle);
            }
        }
    } else {
        tracing::debug!("stream.writeBytes: no handler for '{}'", req.handle);
    }
    Ok(rt::Ok::default())
}

pub async fn stream_close(state: SharedRpcState, req: &rt::StreamCloseRequest) -> Result<rt::Ok, String> {
    let mut guard = state.lock().await;
    if let Some(handler) = guard.stream_handlers.remove(&req.handle) {
        match handler {
            StreamHandler::FileWriter { path, buffer } => {
                std::fs::write(&path, &buffer).map_err(|e| format!("write error: {e}"))?;
            }
            StreamHandler::FileAppender { path, buffer } => {
                std::fs::write(&path, &buffer).map_err(|e| format!("write error: {e}"))?;
            }
            _ => {}
        }
    }
    Ok(rt::Ok::default())
}

// --- helpers ---

fn strip_newline(s: &mut String) {
    if s.ends_with('\n') { s.pop(); }
    if s.ends_with('\r') { s.pop(); }
}

async fn read_line_async<R: tokio::io::AsyncRead + Unpin>(reader: &mut R) -> Result<rt::StreamReadLineResponse, String> {
    use tokio::io::AsyncReadExt;
    let mut line = Vec::new();
    let mut byte = [0u8; 1];
    loop {
        match reader.read(&mut byte).await {
            Ok(0) => {
                return Ok(rt::StreamReadLineResponse {
                    data: String::from_utf8_lossy(&line).to_string(),
                    eof: true,
                    ..Default::default()
                });
            }
            Ok(_) => {
                if byte[0] == b'\n' {
                    if line.last() == Some(&b'\r') { line.pop(); }
                    return Ok(rt::StreamReadLineResponse {
                        data: String::from_utf8_lossy(&line).to_string(),
                        eof: false,
                        ..Default::default()
                    });
                }
                line.push(byte[0]);
            }
            Err(e) => return Err(format!("read error: {e}")),
        }
    }
}
