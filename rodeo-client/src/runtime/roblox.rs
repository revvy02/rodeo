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

/// Finalize a `roblox.capture`. The engine wrote its frame as a PNG in its
/// own temp directory; the plugin reports that path plus the
/// `Camera.ViewportSize` at capture time. On a high-DPI display the frame is
/// a whole multiple of the viewport (2x on Retina), and a frame from before a
/// viewport change is not a multiple at all — that is the stale-frame case,
/// reported as an error rather than retried. The image is resampled to
/// exactly the viewport, so a capture has the same pixel size on every
/// machine and offset-based UI maps 1:1 onto pixels, then written atomically
/// and the engine's copy deleted.
pub async fn roblox_capture_finalize(
    req: &rt::RobloxCaptureFinalizeRequest,
) -> Result<rt::RobloxCaptureFinalizeResponse, String> {
    let req = req.clone();
    tokio::task::spawn_blocking(move || finalize_capture(&req))
        .await
        .map_err(|e| format!("capture finalize task failed: {e}"))?
}

fn finalize_capture(req: &rt::RobloxCaptureFinalizeRequest) -> Result<rt::RobloxCaptureFinalizeResponse, String> {
    use fast_image_resize::images::Image;
    use fast_image_resize::{FilterType, PixelType, ResizeAlg, ResizeOptions, Resizer};
    use image::{ImageEncoder, ImageFormat};

    let (width, height) = (req.width, req.height);
    if width == 0 || height == 0 {
        return Err(format!("capture finalize: invalid viewport {width}x{height}"));
    }

    let bytes = std::fs::read(&req.source).map_err(|e| format!("read capture {}: {e}", req.source))?;
    let decoded = image::load_from_memory_with_format(&bytes, ImageFormat::Png)
        .map_err(|e| format!("decode capture {}: {e}", req.source))?;
    let (source_width, source_height) = (decoded.width(), decoded.height());

    // A genuine frame is the viewport times one display scale on both axes.
    let rx = source_width as f64 / width as f64;
    let ry = source_height as f64 / height as f64;
    if rx < 0.995 || ry < 0.995 || (rx - ry).abs() > 0.02 {
        return Err(format!(
            "captured frame is {source_width}x{source_height}, not a whole multiple of the {width}x{height} viewport \
             ({rx:.2}x by {ry:.2}x). Studio handed back a frame rendered before the viewport changed; \
             raise `settle` so the new size has rendered before the capture."
        ));
    }

    let output_bytes: Vec<u8> = if (source_width, source_height) == (width, height) {
        // Already the viewport size (1x display): keep the engine's encoding.
        bytes
    } else {
        let rgba = decoded.into_rgba8();
        let src = Image::from_vec_u8(source_width, source_height, rgba.into_raw(), PixelType::U8x4)
            .map_err(|e| format!("capture resize source: {e}"))?;
        let mut dst = Image::new(width, height, PixelType::U8x4);
        Resizer::new()
            .resize(
                &src,
                &mut dst,
                &ResizeOptions::new().resize_alg(ResizeAlg::Convolution(FilterType::Lanczos3)),
            )
            .map_err(|e| format!("capture resize: {e}"))?;
        let mut out = Vec::new();
        image::codecs::png::PngEncoder::new_with_quality(
            &mut out,
            image::codecs::png::CompressionType::Fast,
            image::codecs::png::FilterType::Adaptive,
        )
        .write_image(dst.buffer(), width, height, image::ExtendedColorType::Rgba8)
        .map_err(|e| format!("encode capture: {e}"))?;
        out
    };

    if let Some(parent) = std::path::Path::new(&req.output).parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)
                .map_err(|e| format!("create parent dirs for {}: {e}", parent.display()))?;
        }
    }
    let tmp = format!("{}.tmp", req.output);
    std::fs::write(&tmp, &output_bytes).map_err(|e| format!("write {tmp}: {e}"))?;
    std::fs::rename(&tmp, &req.output).map_err(|e| {
        let _ = std::fs::remove_file(&tmp);
        format!("rename {tmp} -> {}: {e}", req.output)
    })?;
    let _ = std::fs::remove_file(&req.source);

    Ok(rt::RobloxCaptureFinalizeResponse {
        width,
        height,
        source_width,
        source_height,
        ..Default::default()
    })
}

#[cfg(test)]
mod capture_finalize_tests {
    use super::*;

    fn write_png(path: &std::path::Path, w: u32, h: u32) {
        let img = image::RgbaImage::from_fn(w, h, |x, y| image::Rgba([(x % 256) as u8, (y % 256) as u8, 128, 255]));
        img.save(path).unwrap();
    }

    fn scratch(name: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("rodeo-capture-finalize-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn finalize(dir: &std::path::Path, src_w: u32, src_h: u32, w: u32, h: u32) -> Result<rt::RobloxCaptureFinalizeResponse, String> {
        let source = dir.join("source.png");
        write_png(&source, src_w, src_h);
        let output = dir.join("nested").join("out.png");
        finalize_capture(&rt::RobloxCaptureFinalizeRequest {
            source: source.to_string_lossy().into_owned(),
            output: output.to_string_lossy().into_owned(),
            width: w,
            height: h,
            ..Default::default()
        })
    }

    #[test]
    fn retina_frame_is_resampled_to_the_viewport() {
        let dir = scratch("retina");
        let res = finalize(&dir, 400, 200, 200, 100).expect("2x frame finalizes");
        assert_eq!((res.width, res.height, res.source_width, res.source_height), (200, 100, 400, 200));
        let out = image::open(dir.join("nested/out.png")).unwrap();
        assert_eq!((out.width(), out.height()), (200, 100));
        assert!(!dir.join("source.png").exists(), "engine copy is deleted");
    }

    #[test]
    fn exact_frame_is_written_as_is() {
        let dir = scratch("exact");
        let res = finalize(&dir, 200, 100, 200, 100).expect("1x frame finalizes");
        assert_eq!((res.width, res.height), (200, 100));
        let out = image::open(dir.join("nested/out.png")).unwrap();
        assert_eq!((out.width(), out.height()), (200, 100));
    }

    #[test]
    fn stale_frame_with_wrong_aspect_is_an_error() {
        let dir = scratch("stale");
        let err = finalize(&dir, 400, 200, 300, 300).expect_err("non-multiple frame must fail");
        assert!(err.contains("400x200") && err.contains("300x300") && err.contains("settle"), "{err}");
        assert!(!dir.join("nested/out.png").exists(), "nothing written on error");
    }

    #[test]
    fn frame_smaller_than_viewport_is_an_error() {
        let dir = scratch("small");
        let err = finalize(&dir, 100, 50, 200, 100).expect_err("upscaling is never silent");
        assert!(err.contains("100x50"), "{err}");
    }
}
