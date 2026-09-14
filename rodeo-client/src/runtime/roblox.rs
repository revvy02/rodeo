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

/// Finalize a `roblox.capture`. The plugin loaded the exact frame the
/// CaptureScreenshot callback named into an EditableImage, read its RGBA8
/// pixels, and streamed them into a FileWriter on the output path (chunked
/// `stream.writeBytes`); this consumes that handle in place of `stream_close`.
///
/// On a high-DPI display the frame is a whole multiple of the reported
/// `Camera.ViewportSize` (2x on Retina); a frame from before a viewport change
/// is not a multiple at all — that is the stale-frame case, reported as an
/// error rather than retried. The image is resampled to exactly the viewport,
/// so a capture has the same pixel size on every machine and offset-based UI
/// maps 1:1 onto pixels, then PNG-encoded and written atomically.
pub async fn roblox_capture_finalize(
    state: SharedRpcState,
    req: &rt::RobloxCaptureFinalizeRequest,
) -> Result<rt::RobloxCaptureFinalizeResponse, String> {
    let (path, rgba) = stream::take_file_writer(&state, &req.handle).await?;
    let req = req.clone();
    tokio::task::spawn_blocking(move || {
        finalize_pixels(rgba, req.source_width, req.source_height, req.width, req.height, &path)
    })
    .await
    .map_err(|e| format!("capture finalize task failed: {e}"))?
}

/// Pure core of the finalize step (see `roblox_capture_finalize`): `rgba` is
/// the `source_width` x `source_height` RGBA8 frame, `(width, height)` the
/// viewport it must be a whole multiple of and the size written to `output`.
fn finalize_pixels(
    rgba: Vec<u8>,
    source_width: u32,
    source_height: u32,
    width: u32,
    height: u32,
    output: &str,
) -> Result<rt::RobloxCaptureFinalizeResponse, String> {
    use fast_image_resize::images::Image;
    use fast_image_resize::{FilterType, PixelType, ResizeAlg, ResizeOptions, Resizer};
    use image::ImageEncoder;

    if width == 0 || height == 0 {
        return Err(format!("capture finalize: invalid viewport {width}x{height}"));
    }
    let expected_len = source_width as usize * source_height as usize * 4;
    if source_width == 0 || source_height == 0 || rgba.len() != expected_len {
        return Err(format!(
            "capture finalize: frame buffer is {} bytes, expected {expected_len} for a {source_width}x{source_height} RGBA8 frame",
            rgba.len()
        ));
    }

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

    let pixels: Vec<u8> = if (source_width, source_height) == (width, height) {
        rgba
    } else {
        let src = Image::from_vec_u8(source_width, source_height, rgba, PixelType::U8x4)
            .map_err(|e| format!("capture resize source: {e}"))?;
        let mut dst = Image::new(width, height, PixelType::U8x4);
        Resizer::new()
            .resize(
                &src,
                &mut dst,
                &ResizeOptions::new().resize_alg(ResizeAlg::Convolution(FilterType::Lanczos3)),
            )
            .map_err(|e| format!("capture resize: {e}"))?;
        dst.into_vec()
    };

    let mut png = Vec::new();
    image::codecs::png::PngEncoder::new_with_quality(
        &mut png,
        image::codecs::png::CompressionType::Fast,
        image::codecs::png::FilterType::Adaptive,
    )
    .write_image(&pixels, width, height, image::ExtendedColorType::Rgba8)
    .map_err(|e| format!("encode capture: {e}"))?;

    if let Some(parent) = std::path::Path::new(output).parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)
                .map_err(|e| format!("create parent dirs for {}: {e}", parent.display()))?;
        }
    }
    let tmp = format!("{output}.tmp");
    std::fs::write(&tmp, &png).map_err(|e| format!("write {tmp}: {e}"))?;
    std::fs::rename(&tmp, output).map_err(|e| {
        let _ = std::fs::remove_file(&tmp);
        format!("rename {tmp} -> {output}: {e}")
    })?;

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

    fn frame(w: u32, h: u32) -> Vec<u8> {
        let mut v = Vec::with_capacity((w * h * 4) as usize);
        for y in 0..h {
            for x in 0..w {
                v.extend_from_slice(&[(x % 256) as u8, (y % 256) as u8, 128, 255]);
            }
        }
        v
    }

    fn scratch(name: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("rodeo-capture-finalize-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn finalize(dir: &std::path::Path, sw: u32, sh: u32, w: u32, h: u32) -> Result<rt::RobloxCaptureFinalizeResponse, String> {
        let output = dir.join("nested").join("out.png");
        finalize_pixels(frame(sw, sh), sw, sh, w, h, &output.to_string_lossy())
    }

    #[test]
    fn retina_frame_is_resampled_to_the_viewport() {
        let dir = scratch("retina");
        let res = finalize(&dir, 400, 200, 200, 100).expect("2x frame finalizes");
        assert_eq!((res.width, res.height, res.source_width, res.source_height), (200, 100, 400, 200));
        let out = image::open(dir.join("nested/out.png")).unwrap();
        assert_eq!((out.width(), out.height()), (200, 100));
    }

    #[test]
    fn exact_frame_is_encoded_as_is() {
        let dir = scratch("exact");
        let res = finalize(&dir, 200, 100, 200, 100).expect("1x frame finalizes");
        assert_eq!((res.width, res.height), (200, 100));
        let out = image::open(dir.join("nested/out.png")).unwrap().into_rgba8();
        assert_eq!((out.width(), out.height()), (200, 100));
        assert_eq!(out.into_raw(), frame(200, 100), "1x pixels round-trip untouched");
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

    #[test]
    fn buffer_length_must_match_the_frame() {
        let dir = scratch("len");
        let output = dir.join("out.png");
        let err = finalize_pixels(vec![0; 100], 10, 10, 10, 10, &output.to_string_lossy()).expect_err("short buffer");
        assert!(err.contains("100 bytes") && err.contains("400"), "{err}");
    }
}
