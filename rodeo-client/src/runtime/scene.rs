//! Scene codecs. The wire packet is u32 JSON length + JSON, then one
//! length-prefixed RMSH blob per mesh and one RGBA8 blob per image. It travels
//! through ordinary chunked streams so scene size never sets the RPC size.
//! TODO(#25): replace the JSON descriptor with the shared protobuf schema,
//! making it the source of truth rather than adding a second parallel model.
use super::{
    mesh::{self, Mat4, MeshData, IDENTITY},
    stream, SharedRpcState, StreamHandler,
};
use rodeo_proto::runtime_types as rt;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;

#[path = "scene_motion.rs"]
mod motion;

#[derive(Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Scene {
    #[serde(default)]
    pub name: String,
    pub nodes: Vec<Node>,
    pub roots: Vec<usize>,
    pub meshes: Vec<MeshInfo>,
    pub materials: Vec<Material>,
    pub images: Vec<ImageInfo>,
    pub warnings: Vec<String>,
    #[serde(default)]
    pub animations: Vec<motion::Animation>,
}
#[derive(Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Node {
    #[serde(default)]
    pub class_name: Option<String>,
    pub name: String,
    pub transform: [f32; 12],
    #[serde(default)]
    pub children: Vec<usize>,
    #[serde(default)]
    pub parts: Vec<Binding>,
    pub source_index: Option<usize>,
    /// Full world frame, before Roblox's size/rigid-pivot split. Rich scene
    /// export keeps this frame so animation channels stay in source local space.
    pub world: Option<Mat4>,
    pub local_scale: Option<[f32; 3]>,
    pub rest: Option<motion::Trs>,
}
#[derive(Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Binding {
    pub mesh: usize,
    pub material: Option<usize>,
    pub matrix: Mat4,
    #[serde(default)]
    pub poses: Vec<[f32; 12]>,
    #[serde(default)]
    pub joint_nodes: Vec<usize>,
    #[serde(default)]
    pub weights: Vec<f32>,
}
#[derive(Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct MeshInfo {
    pub mesh_index: Option<usize>,
    pub primitive_index: Option<usize>,
    pub skin_index: Option<usize>,
    #[serde(default)]
    pub joint_nodes: Vec<usize>,
    #[serde(default)]
    pub morph: motion::Morph,
}
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ImageInfo {
    pub width: u32,
    pub height: u32,
    pub source_index: Option<usize>,
    pub channel: Option<String>,
}
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Material {
    pub name: String,
    pub source_index: Option<usize>,
    pub color: [f32; 4],
    pub double_sided: bool,
    pub alpha_mode: String,
    #[serde(default = "one")]
    pub roughness: f32,
    #[serde(default)]
    pub metalness: f32,
    #[serde(default)]
    pub native_material: Option<String>,
    #[serde(default)]
    pub maps: HashMap<String, usize>,
}

fn one() -> f32 {
    1.
}

pub async fn decode(
    state: SharedRpcState,
    req: &rt::RobloxSceneDecodeRequest,
) -> Result<rt::Ok, String> {
    let path = req.path.clone();
    let bytes = tokio::task::spawn_blocking(move || {
        let (scene, meshes, images) = read_scene(&path)?;
        pack(&scene, &meshes, &images)
    })
    .await
    .map_err(|e| e.to_string())??;
    state.lock().await.stream_handlers.insert(
        req.handle.clone(),
        StreamHandler::FileReader {
            reader: Box::new(std::io::Cursor::new(bytes)),
        },
    );
    Ok(rt::Ok::default())
}

pub async fn encode(
    state: SharedRpcState,
    req: &rt::RobloxSceneEncodeRequest,
) -> Result<rt::Ok, String> {
    let (path, bytes) = stream::take_file_writer(&state, &req.handle).await?;
    tokio::task::spawn_blocking(move || {
        let (scene, meshes, images) = unpack(&bytes)?;
        write_scene(&scene, &meshes, &images, &path)
    })
    .await
    .map_err(|e| e.to_string())??;
    Ok(rt::Ok::default())
}

fn pack(scene: &Scene, meshes: &[MeshData], images: &[Vec<u8>]) -> Result<Vec<u8>, String> {
    let mut bytes = Vec::new();
    let mut push = |chunk: &[u8]| -> Result<(), String> {
        let len = u32::try_from(chunk.len()).map_err(|_| "scene resource exceeds 4 GiB")?;
        bytes.extend_from_slice(&len.to_le_bytes());
        bytes.extend_from_slice(chunk);
        Ok(())
    };
    push(&serde_json::to_vec(scene).map_err(|e| e.to_string())?)?;
    for mesh in meshes {
        push(&mesh::encode_blob(mesh))?;
    }
    for image in images {
        push(image)?;
    }
    Ok(bytes)
}
fn unpack(bytes: &[u8]) -> Result<(Scene, Vec<MeshData>, Vec<Vec<u8>>), String> {
    let mut pos = 0usize;
    let mut next = || -> Result<&[u8], String> {
        let len = bytes
            .get(pos..pos + 4)
            .ok_or("truncated scene packet length")?;
        let len = u32::from_le_bytes(len.try_into().unwrap()) as usize;
        pos += 4;
        let chunk = bytes
            .get(pos..pos + len)
            .ok_or("truncated scene packet resource")?;
        pos += len;
        Ok(chunk)
    };
    let scene: Scene =
        serde_json::from_slice(next()?).map_err(|e| format!("scene metadata: {e}"))?;
    let meshes = (0..scene.meshes.len())
        .map(|_| mesh::decode_blob(next()?))
        .collect::<Result<Vec<_>, _>>()?;
    let images = scene
        .images
        .iter()
        .map(|i| {
            let data = next()?;
            if u64::from(i.width) * u64::from(i.height) * 4 != data.len() as u64 {
                return Err("scene image dimensions do not match pixels".into());
            }
            Ok(data.to_vec())
        })
        .collect::<Result<Vec<_>, String>>()?;
    if pos != bytes.len() {
        return Err("trailing scene packet bytes".into());
    }
    Ok((scene, meshes, images))
}

fn extension(path: &str) -> Result<(), String> {
    if !path.to_lowercase().ends_with(".glb") && !path.to_lowercase().ends_with(".gltf") {
        return Err("editable scenes require .gltf or .glb".into());
    }
    Ok(())
}
fn dot(a: &[f32; 4], b: &[f32; 4]) -> f32 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}
/// Roblox parts have a rigid pose and three size axes; refuse shear instead
/// of silently moving geometry. Reflections are baked into unskinned meshes.
fn decompose(m: Mat4) -> Result<(Mat4, [f32; 3]), String> {
    if m.iter().flatten().any(|v| !v.is_finite()) {
        return Err("non-finite node transform".into());
    }
    let mut r = m;
    let mut scale = [0.; 3];
    for k in 0..3 {
        scale[k] = dot(&m[k], &m[k]).sqrt();
        if scale[k] < 1e-8 {
            return Err("zero-scale node transform".into());
        }
        for j in 0..3 {
            r[k][j] /= scale[k];
        }
    }
    if dot(&r[0], &r[1]).abs() > 1e-4
        || dot(&r[0], &r[2]).abs() > 1e-4
        || dot(&r[1], &r[2]).abs() > 1e-4
    {
        return Err("node world transform contains shear; bake transforms before importing".into());
    }
    let det = r[0][0] * (r[1][1] * r[2][2] - r[1][2] * r[2][1])
        - r[1][0] * (r[0][1] * r[2][2] - r[0][2] * r[2][1])
        + r[2][0] * (r[0][1] * r[1][2] - r[0][2] * r[1][1]);
    if det < 0. {
        scale[0] = -scale[0];
        for j in 0..3 {
            r[0][j] = -r[0][j];
        }
    }
    Ok((r, scale))
}
pub(super) fn uri_bytes(uri: &str, path: &str) -> Result<Vec<u8>, String> {
    use base64::Engine;
    if uri.starts_with("data:") {
        let (header, data) = uri.split_once(',').ok_or("invalid data URI")?;
        if !header.ends_with(";base64") {
            return Err("only base64 data URIs are supported".into());
        }
        return base64::engine::general_purpose::STANDARD
            .decode(data)
            .map_err(|e| e.to_string());
    }
    if uri.contains("://") {
        return Err(format!("remote glTF resource is unsupported: {uri}"));
    }
    let mut decoded = Vec::new();
    let b = uri.as_bytes();
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' {
            let hex = b.get(i + 1..i + 3).ok_or("truncated URI escape")?;
            decoded.push(
                u8::from_str_radix(std::str::from_utf8(hex).map_err(|e| e.to_string())?, 16)
                    .map_err(|e| e.to_string())?,
            );
            i += 3;
        } else {
            decoded.push(b[i]);
            i += 1;
        }
    }
    let relative = String::from_utf8(decoded).map_err(|e| e.to_string())?;
    let base = std::path::Path::new(path)
        .parent()
        .unwrap_or(std::path::Path::new("."));
    std::fs::read(base.join(relative)).map_err(|e| format!("glTF resource {uri}: {e}"))
}

fn parse_gltf(bytes: &[u8]) -> Result<gltf::Gltf, String> {
    let (mut json, blob): (Value, _) = if bytes.starts_with(b"glTF") {
        let glb = gltf::binary::Glb::from_slice(bytes).map_err(|e| e.to_string())?;
        (
            serde_json::from_slice(&glb.json).map_err(|e| e.to_string())?,
            glb.bin.map(|b| b.into_owned()),
        )
    } else {
        (
            serde_json::from_slice(bytes).map_err(|e| e.to_string())?,
            None,
        )
    };
    // gltf-json 1.4 omits serde(default) on Scene.nodes even though glTF makes
    // it optional. Normalize for that reader only; empty arrays are not valid
    // glTF output, so the writer still omits them from the actual file.
    if let Some(scenes) = json["scenes"].as_array_mut() {
        for scene in scenes {
            if let Some(object) = scene.as_object_mut() {
                object.entry("nodes").or_insert(json!([]));
            }
        }
    }
    let root = serde_json::from_value(json).map_err(|e| e.to_string())?;
    Ok(gltf::Gltf {
        document: gltf::Document::from_json(root).map_err(|e| e.to_string())?,
        blob,
    })
}

pub(super) fn read_scene(path: &str) -> Result<(Scene, Vec<MeshData>, Vec<Vec<u8>>), String> {
    extension(path)?;
    let bytes = std::fs::read(path).map_err(|e| e.to_string())?;
    let gltf = parse_gltf(&bytes).map_err(|e| format!("glTF: {e}"))?;
    let raw: Value = serde_json::to_value(gltf.document.as_json()).map_err(|e| e.to_string())?;
    if let Some(required) = raw["extensionsRequired"].as_array() {
        if !required.is_empty() {
            return Err(format!(
                "required glTF extensions are unsupported: {required:?}"
            ));
        }
    }
    let buffers = mesh::load_buffers(&gltf, path)?;
    let selected = gltf
        .default_scene()
        .or_else(|| gltf.scenes().next())
        .ok_or("glTF has no scene")?;
    let mut scene = Scene {
        name: selected.name().unwrap_or("Scene").into(),
        ..Default::default()
    };
    let mut meshes = Vec::new();
    let mut pixels = Vec::new();
    if gltf.scenes().len() > 1 {
        scene
            .warnings
            .push("Only the default (or first) glTF scene was imported".into());
    }
    if raw["extensionsUsed"]
        .as_array()
        .is_some_and(|v| !v.is_empty())
    {
        scene.warnings.push(format!(
            "glTF extensions are unsupported: {}",
            raw["extensionsUsed"]
        ));
    }
    let mut parents = vec![None; gltf.nodes().len()];
    for node in gltf.nodes() {
        for child in node.children() {
            if parents[child.index()].replace(node.index()).is_some() {
                return Err("glTF node has multiple parents".into());
            }
        }
    }
    let mut worlds = HashMap::new();
    let mut order = Vec::new();
    fn visit(
        node: gltf::Node,
        world: Mat4,
        worlds: &mut HashMap<usize, Mat4>,
        order: &mut Vec<usize>,
    ) -> Result<(), String> {
        let world = mesh::mat_mul(&world, &node.transform().matrix());
        if worlds.insert(node.index(), world).is_some() {
            return Err("glTF scene has repeated or cyclic nodes".into());
        }
        order.push(node.index());
        for child in node.children() {
            visit(child, world, worlds, order)?;
        }
        Ok(())
    }
    for node in selected.nodes() {
        visit(node, IDENTITY, &mut worlds, &mut order)?;
    }
    // Geometry-only children emitted by this codec separate mesh size from the
    // source node frame. Fold only explicitly marked children, never guess
    // semantics from an arbitrary external empty/mesh node's shape.
    let mut geometry_children = HashMap::new();
    for &source in &order {
        if let Some(child) = raw["nodes"][source]["extras"]["rodeo"]["geometryChild"].as_u64() {
            let child = child as usize;
            let node = gltf.nodes().nth(source).unwrap();
            let geometry = gltf
                .nodes()
                .nth(child)
                .ok_or("invalid Rodeo geometry child")?;
            if node.mesh().is_some()
                || !node.children().any(|n| n.index() == child)
                || geometry.mesh().is_none()
                || geometry.children().len() != 0
            {
                return Err("invalid Rodeo geometry child".into());
            }
            geometry_children.insert(source, child);
        }
    }
    order.retain(|id| !geometry_children.values().any(|child| child == id));
    let mut node_ids: HashMap<_, _> = order.iter().enumerate().map(|(i, id)| (*id, i)).collect();
    for (&parent, &child) in &geometry_children {
        node_ids.insert(child, node_ids[&parent]);
    }
    scene.roots = selected.nodes().map(|n| node_ids[&n.index()]).collect();
    let mut geometries = HashMap::new();
    let mut materials = HashMap::new();
    let mut image_cache: HashMap<String, usize> = HashMap::new();
    let mut source_images: HashMap<usize, image::RgbaImage> = HashMap::new();
    for source in order {
        let node = gltf.nodes().nth(source).unwrap();
        let (rigid, _) = decompose(worlds[&source])
            .map_err(|e| format!("node {source} ({}): {e}", node.name().unwrap_or("unnamed")))?;
        let mut out = Node {
            name: node.name().unwrap_or("Node").to_string(),
            class_name: raw["nodes"][source]["extras"]["rodeo"]["class"]
                .as_str()
                .map(str::to_owned),
            source_index: Some(source),
            transform: mesh::cframe_from_mat(&rigid),
            children: node
                .children()
                .filter(|n| geometry_children.get(&source) != Some(&n.index()))
                .map(|n| node_ids[&n.index()])
                .collect(),
            parts: vec![],
            world: Some(worlds[&source]),
            local_scale: Some(node.transform().decomposed().2),
            rest: Some(motion::Trs::from_node(&node)),
        };
        if node.camera().is_some() {
            scene
                .warnings
                .push(format!("node {source}: camera is unsupported"));
        }
        let geometry_source = geometry_children.get(&source).copied().unwrap_or(source);
        let geometry_node = gltf.nodes().nth(geometry_source).unwrap();
        let (geometry_rigid, scale) = decompose(worlds[&geometry_source])?;
        if let Some(gmesh) = geometry_node.mesh() {
            for primitive in gmesh.primitives() {
                let skin = geometry_node.skin();
                if skin.is_some() && scale.iter().any(|s| (*s - 1.).abs() > 1e-4) {
                    return Err(format!("node {source}: scaled skins are unsupported; apply scale to the rig before importing"));
                }
                let reflected = scale[0] < 0.;
                let weights = geometry_node
                    .weights()
                    .or_else(|| gmesh.weights())
                    .map(|w| w.to_vec())
                    .unwrap_or_else(|| vec![0.; primitive.morph_targets().len()]);
                let key = (
                    gmesh.index(),
                    primitive.index(),
                    skin.as_ref().map(|s| s.index()),
                    reflected,
                );
                let mesh_id = if let Some(id) = geometries.get(&key) {
                    *id
                } else {
                    let (mut data, joint_nodes) = mesh::read_gltf_parts(
                        &gltf,
                        &buffers,
                        &[mesh::MeshInstance {
                            node: geometry_source,
                            world: IDENTITY,
                        }],
                        &parents,
                        Some(primitive.index()),
                    )?;
                    if data
                        .positions
                        .iter()
                        .flatten()
                        .chain(data.normals.iter().flatten().flatten())
                        .any(|v| !v.is_finite())
                    {
                        return Err(format!(
                            "mesh {} primitive {}: non-finite geometry",
                            gmesh.index(),
                            primitive.index()
                        ));
                    }
                    if reflected {
                        for p in &mut data.positions {
                            p[0] = -p[0];
                        }
                        if let Some(normals) = &mut data.normals {
                            for n in normals {
                                n[0] = -n[0];
                            }
                        }
                        for f in data.indices.chunks_exact_mut(3) {
                            f.swap(1, 2);
                        }
                    }
                    for b in &data.bones {
                        let (_, scale) = decompose(mesh::mat_from_cframe(&b.cframe))
                            .map_err(|e| format!("bone {}: {e}", b.name))?;
                        if scale.iter().any(|v| (*v - 1.).abs() > 1e-4) {
                            return Err(format!(
                                "bone {}: scaled bind poses are unsupported",
                                b.name
                            ));
                        }
                    }
                    if skin.is_some() && (data.joints.is_none() || data.weights.is_none()) {
                        return Err(format!(
                            "mesh {} primitive {}: skin requires JOINTS_0 and WEIGHTS_0",
                            gmesh.index(),
                            primitive.index()
                        ));
                    }
                    let id = meshes.len();
                    meshes.push(data);
                    scene.meshes.push(MeshInfo {
                        mesh_index: Some(gmesh.index()),
                        primitive_index: Some(primitive.index()),
                        skin_index: skin.as_ref().map(|s| s.index()),
                        joint_nodes,
                        morph: motion::read_morph(&primitive, &gmesh, &buffers, reflected)?,
                    });
                    geometries.insert(key, id);
                    id
                };
                for (semantic, _) in primitive.attributes() {
                    if !matches!(
                        semantic,
                        gltf::Semantic::Positions
                            | gltf::Semantic::Normals
                            | gltf::Semantic::Tangents
                            | gltf::Semantic::TexCoords(0)
                            | gltf::Semantic::Colors(0)
                            | gltf::Semantic::Joints(0)
                            | gltf::Semantic::Weights(0)
                    ) {
                        scene.warnings.push(format!(
                            "mesh {} primitive {}: {semantic:?} is unsupported",
                            gmesh.index(),
                            primitive.index()
                        ));
                    }
                }
                let mat = primitive.material();
                let mat_key = mat.index();
                let material = if let Some(id) = materials.get(&mat_key) {
                    *id
                } else {
                    let pbr = mat.pbr_metallic_roughness();
                    let mut record = Material {
                        name: mat.name().unwrap_or("Material").into(),
                        source_index: mat.index(),
                        color: pbr.base_color_factor(),
                        double_sided: mat.double_sided(),
                        alpha_mode: format!("{:?}", mat.alpha_mode()).to_uppercase(),
                        roughness: pbr.roughness_factor(),
                        metalness: pbr.metallic_factor(),
                        native_material: mat.index().and_then(|id| {
                            raw["materials"][id]["extras"]["rodeo"]["material"]
                                .as_str()
                                .map(str::to_owned)
                        }),
                        maps: HashMap::new(),
                    };
                    if mat.alpha_mode() == gltf::material::AlphaMode::Opaque {
                        record.color[3] = 1.;
                    } else if mat.alpha_mode() == gltf::material::AlphaMode::Mask
                        && pbr.base_color_texture().is_none()
                    {
                        record.color[3] = if record.color[3] >= mat.alpha_cutoff().unwrap_or(0.5) {
                            1.
                        } else {
                            0.
                        };
                    }
                    let label = format!("material {:?}", mat.index());
                    let mut add_image = |texture: Option<gltf::Texture>,
                                         channel: &str,
                                         factor: f32|
                     -> Result<usize, String> {
                        let source_id = texture.as_ref().map(|t| t.source().index());
                        let key = format!(
                            "{source_id:?}:{channel}:{factor}:{}:{:?}:{}",
                            record.alpha_mode,
                            mat.alpha_cutoff(),
                            pbr.base_color_factor()[3]
                        );
                        if let Some(id) = image_cache.get(&key) {
                            return Ok(*id);
                        }
                        let mut image = if let Some(texture) = texture {
                            let sampler = texture.sampler();
                            if sampler.wrap_s() != gltf::texture::WrappingMode::Repeat
                                || sampler.wrap_t() != gltf::texture::WrappingMode::Repeat
                            {
                                scene.warnings.push(format!(
                                    "{label}: non-repeat texture wrapping is unsupported"
                                ));
                            }
                            if sampler.mag_filter() == Some(gltf::texture::MagFilter::Nearest)
                                || matches!(
                                    sampler.min_filter(),
                                    Some(
                                        gltf::texture::MinFilter::Nearest
                                            | gltf::texture::MinFilter::NearestMipmapNearest
                                            | gltf::texture::MinFilter::NearestMipmapLinear
                                    )
                                )
                            {
                                scene.warnings.push(format!(
                                    "{label}: nearest texture filtering is unsupported"
                                ));
                            }
                            let src = texture.source();
                            if !source_images.contains_key(&src.index()) {
                                let bytes = match src.source() {
                                    gltf::image::Source::Uri { uri, .. } => uri_bytes(uri, path)?,
                                    gltf::image::Source::View { view, .. } => buffers
                                        .get(view.buffer().index())
                                        .and_then(|b| {
                                            b.get(view.offset()..view.offset() + view.length())
                                        })
                                        .ok_or("image bufferView exceeds buffer")?
                                        .to_vec(),
                                };
                                source_images.insert(
                                    src.index(),
                                    image::load_from_memory(&bytes)
                                        .map_err(|e| format!("image {}: {e}", src.index()))?
                                        .into_rgba8(),
                                );
                            }
                            source_images[&src.index()].clone()
                        } else {
                            image::RgbaImage::from_pixel(1, 1, image::Rgba([255; 4]))
                        };
                        for pixel in image.pixels_mut() {
                            if channel == "roughness" || channel == "metalness" {
                                let v =
                                    (f32::from(pixel[if channel == "roughness" { 1 } else { 2 }])
                                        * factor)
                                        .round()
                                        .clamp(0., 255.) as u8;
                                *pixel = image::Rgba([v, v, v, 255]);
                            } else if channel == "color" {
                                if mat.alpha_mode() == gltf::material::AlphaMode::Opaque {
                                    pixel[3] = 255;
                                }
                                if mat.alpha_mode() == gltf::material::AlphaMode::Mask {
                                    pixel[3] = if f32::from(pixel[3]) / 255.
                                        * pbr.base_color_factor()[3]
                                        >= mat.alpha_cutoff().unwrap_or(0.5)
                                    {
                                        255
                                    } else {
                                        0
                                    };
                                }
                            }
                        }
                        let id = pixels.len();
                        scene.images.push(ImageInfo {
                            width: image.width(),
                            height: image.height(),
                            source_index: source_id,
                            channel: Some(channel.into()),
                        });
                        pixels.push(image.into_raw());
                        image_cache.insert(key, id);
                        Ok(id)
                    };
                    if let Some(t) = pbr.base_color_texture() {
                        if t.tex_coord() != 0 {
                            return Err(format!(
                                "{label}: base color requires unsupported TEXCOORD_{}",
                                t.tex_coord()
                            ));
                        }
                        record
                            .maps
                            .insert("color".into(), add_image(Some(t.texture()), "color", 1.)?);
                    }
                    if let Some(t) = mat.normal_texture() {
                        if t.tex_coord() != 0 {
                            return Err(format!(
                                "{label}: normal map requires unsupported TEXCOORD_{}",
                                t.tex_coord()
                            ));
                        }
                        record
                            .maps
                            .insert("normal".into(), add_image(Some(t.texture()), "normal", 1.)?);
                    }
                    let mr = pbr.metallic_roughness_texture();
                    if mr.as_ref().is_some_and(|t| t.tex_coord() != 0) {
                        return Err(format!(
                            "{label}: metallic/roughness requires unsupported UV set"
                        ));
                    }
                    if mr.is_some() || !record.maps.is_empty() {
                        record.maps.insert(
                            "roughness".into(),
                            add_image(
                                mr.as_ref().map(|t| t.texture()),
                                "roughness",
                                pbr.roughness_factor(),
                            )?,
                        );
                        record.maps.insert(
                            "metalness".into(),
                            add_image(
                                mr.as_ref().map(|t| t.texture()),
                                "metalness",
                                pbr.metallic_factor(),
                            )?,
                        );
                        // The generated channels already contain the scalar factors.
                        record.roughness = 1.;
                        record.metalness = 1.;
                    }
                    if mat.normal_texture().is_some_and(|t| t.scale() != 1.) {
                        scene
                            .warnings
                            .push(format!("{label}: normal texture scale is unsupported"));
                    }
                    if mat.occlusion_texture().is_some()
                        || mat.emissive_texture().is_some()
                        || mat.emissive_factor() != [0.; 3]
                    {
                        scene.warnings.push(format!(
                            "{label}: occlusion and emissive channels are unsupported"
                        ));
                    }
                    if mat.alpha_mode() == gltf::material::AlphaMode::Mask {
                        record.alpha_mode = "BLEND".into();
                        record.color[3] = 1.;
                        scene
                            .warnings
                            .push(format!("{label}: alpha mask was baked into image alpha"));
                    }
                    let id = scene.materials.len();
                    scene.materials.push(record);
                    materials.insert(mat_key, id);
                    id
                };
                let mut geometry_world = geometry_rigid;
                for k in 0..3 {
                    for row in 0..3 {
                        geometry_world[k][row] *= scale[k].abs();
                    }
                }
                let matrix = mesh::mat_mul(&mesh::mat_inverse(&rigid).unwrap(), &geometry_world);
                let poses = scene.meshes[mesh_id]
                    .joint_nodes
                    .iter()
                    .map(|j| {
                        let world = worlds.get(j).ok_or_else(|| {
                            format!("skin joint node {j} is outside the selected scene")
                        })?;
                        let local = mesh::mat_mul(&mesh::mat_inverse(&rigid).unwrap(), world);
                        let (r, s) = decompose(local)?;
                        if s.iter().any(|s| (*s - 1.).abs() > 1e-4) {
                            return Err(format!("skin joint {j} has unsupported scale"));
                        }
                        Ok(mesh::cframe_from_mat(&r))
                    })
                    .collect::<Result<Vec<_>, String>>()?;
                out.parts.push(Binding {
                    mesh: mesh_id,
                    material: Some(material),
                    matrix,
                    poses,
                    joint_nodes: vec![],
                    weights,
                });
            }
        }
        scene.nodes.push(out);
    }
    scene.animations = motion::read_animations(&gltf, &buffers, &node_ids, &mut scene.warnings)?;
    motion::validate(&scene, &meshes)?;
    Ok((scene, meshes, pixels))
}

pub(super) fn write_scene(
    scene: &Scene,
    meshes: &[MeshData],
    images: &[Vec<u8>],
    path: &str,
) -> Result<(), String> {
    extension(path)?;
    motion::validate(scene, meshes)?;
    let mut root = json!({"asset":{"version":"2.0","generator":"rodeo"},"scene":0,"scenes":[{"name":scene.name,"nodes":scene.roots}],"nodes":[],"meshes":[],"materials":[],"textures":[],"images":[],"samplers":[{"wrapS":10497,"wrapT":10497}],"accessors":[],"bufferViews":[],"skins":[]});
    let mut binary = Vec::new();
    let mut pieces = Vec::new();
    for (mesh_index, mesh) in meshes.iter().enumerate() {
        let (mut part, bytes) = mesh::build_gltf(mesh)?;
        while binary.len() % 4 != 0 {
            binary.push(0);
        }
        let byte_offset = binary.len();
        let view_offset = root["bufferViews"].as_array().unwrap().len();
        let accessor_offset = root["accessors"].as_array().unwrap().len();
        binary.extend(bytes);
        for v in part["bufferViews"].as_array_mut().unwrap() {
            v["byteOffset"] = json!(v["byteOffset"].as_u64().unwrap_or(0) + byte_offset as u64);
            root["bufferViews"].as_array_mut().unwrap().push(v.clone());
        }
        for a in part["accessors"].as_array_mut().unwrap() {
            a["bufferView"] = json!(a["bufferView"].as_u64().unwrap() + view_offset as u64);
            root["accessors"].as_array_mut().unwrap().push(a.clone());
        }
        let mut primitive = part["meshes"][0]["primitives"][0].clone();
        for a in primitive["attributes"]
            .as_object_mut()
            .unwrap()
            .values_mut()
        {
            *a = json!(a.as_u64().unwrap() + accessor_offset as u64);
        }
        primitive["indices"] =
            json!(primitive["indices"].as_u64().unwrap() + accessor_offset as u64);
        motion::write_morph(
            &scene.meshes[mesh_index].morph,
            &mut primitive,
            &mut root,
            &mut binary,
        )?;
        if let Some(skins) = part["skins"].as_array_mut() {
            for s in skins {
                s["inverseBindMatrices"] =
                    json!(s["inverseBindMatrices"].as_u64().unwrap() + accessor_offset as u64);
            }
        }
        pieces.push((primitive, part));
    }
    let mut image_ids = HashMap::new();
    for material in &scene.materials {
        let mut out = json!({"name":material.name,"pbrMetallicRoughness":{"baseColorFactor":material.color,"metallicFactor":material.metalness,"roughnessFactor":material.roughness},"doubleSided":material.double_sided,"alphaMode":material.alpha_mode});
        if let Some(native) = &material.native_material {
            out["extras"] = json!({"rodeo":{"material":native}});
        }
        for channel in ["color", "normal"] {
            if let Some(id) = material.maps.get(channel) {
                let texture = if let Some(t) = image_ids.get(id) {
                    *t
                } else {
                    let info = scene
                        .images
                        .get(*id)
                        .ok_or("material image index out of range")?;
                    let bytes = images.get(*id).ok_or("missing material pixels")?;
                    let t = embed_image(&mut root, &mut binary, info.width, info.height, bytes)?;
                    image_ids.insert(*id, t);
                    t
                };
                if channel == "color" {
                    out["pbrMetallicRoughness"]["baseColorTexture"] = json!({"index":texture});
                } else {
                    out["normalTexture"] = json!({"index":texture});
                }
            }
        }
        if material.maps.contains_key("roughness") || material.maps.contains_key("metalness") {
            let mut size = (1, 1);
            for channel in ["roughness", "metalness"] {
                if let Some(id) = material.maps.get(channel) {
                    let i = scene
                        .images
                        .get(*id)
                        .ok_or("material image index out of range")?;
                    size.0 = size.0.max(i.width);
                    size.1 = size.1.max(i.height);
                }
            }
            let mut combined =
                image::RgbaImage::from_pixel(size.0, size.1, image::Rgba([255, 255, 0, 255]));
            for (channel, component) in [("roughness", 1), ("metalness", 2)] {
                if let Some(id) = material.maps.get(channel) {
                    let i = &scene.images[*id];
                    let source = image::RgbaImage::from_raw(
                        i.width,
                        i.height,
                        images.get(*id).ok_or("missing map pixels")?.clone(),
                    )
                    .ok_or("invalid map pixels")?;
                    let scaled = image::imageops::resize(
                        &source,
                        size.0,
                        size.1,
                        image::imageops::FilterType::Triangle,
                    );
                    for (out, pixel) in combined.pixels_mut().zip(scaled.pixels()) {
                        out[component] = pixel[0];
                    }
                }
            }
            let t = embed_image(&mut root, &mut binary, size.0, size.1, &combined.into_raw())?;
            out["pbrMetallicRoughness"]["metallicRoughnessTexture"] = json!({"index":t});
        }
        root["materials"].as_array_mut().unwrap().push(out);
    }
    let mut parents = vec![None; scene.nodes.len()];
    for (i, node) in scene.nodes.iter().enumerate() {
        for child in &node.children {
            if *child >= parents.len() || parents[*child].replace(i).is_some() {
                return Err("scene has invalid/multiple node parents".into());
            }
        }
    }
    // A single primitive lives directly on its node. Compute child-local
    // transforms against that node's full affine transform, so mesh scale and
    // centering do not move attachments. Nodes with children keep a rigid frame;
    // geometry scale lives on a marked geometry child and cannot shear siblings.
    let worlds: Vec<Mat4> = scene
        .nodes
        .iter()
        .map(|node| {
            if let Some(world) = node.world {
                return world;
            }
            let world = mesh::mat_from_cframe(&node.transform);
            if node.parts.len() == 1 && node.children.is_empty() {
                mesh::mat_mul(&world, &node.parts[0].matrix)
            } else {
                world
            }
        })
        .collect();
    for (i, node) in scene.nodes.iter().enumerate() {
        let local = if let Some(p) = parents[i] {
            mesh::mat_mul(
                &mesh::mat_inverse(&worlds[p]).ok_or("singular parent")?,
                &worlds[i],
            )
        } else {
            worlds[i]
        };
        let mut output = json!({"name":node.name,"children":node.children});
        if let Some(class) = &node.class_name {
            output["extras"] = json!({"rodeo":{"class":class}});
        }
        if scene.animations.iter().any(|a| {
            a.channels
                .iter()
                .any(|c| c.node == i && c.path != "weights")
        }) {
            motion::write_trs(&mut output, local, node.local_scale)?;
        } else {
            output["matrix"] = json!(local.iter().flatten().copied().collect::<Vec<_>>());
        }
        root["nodes"].as_array_mut().unwrap().push(output);
    }
    let mut mesh_ids = HashMap::new();
    let mut geometry_nodes = vec![Vec::new(); scene.nodes.len()];
    for (i, node) in scene.nodes.iter().enumerate() {
        for binding in &node.parts {
            let (primitive, part) = pieces
                .get(binding.mesh)
                .ok_or("node mesh index out of range")?;
            let key = (binding.mesh, binding.material);
            let mesh_id = if let Some(id) = mesh_ids.get(&key) {
                *id
            } else {
                let mut primitive = primitive.clone();
                if let Some(m) = binding.material {
                    if m >= scene.materials.len() {
                        return Err("material index out of range".into());
                    }
                    primitive["material"] = json!(m);
                }
                let id = root["meshes"].as_array().unwrap().len();
                root["meshes"]
                    .as_array_mut()
                    .unwrap()
                    .push(json!({"primitives":[primitive]}));
                motion::write_morph_names(
                    &scene.meshes[binding.mesh].morph,
                    &mut root["meshes"][id],
                );
                mesh_ids.insert(key, id);
                id
            };
            let geometry_world =
                mesh::mat_mul(&mesh::mat_from_cframe(&node.transform), &binding.matrix);
            let relative = mesh::mat_mul(
                &mesh::mat_inverse(&worlds[i]).ok_or("singular node frame")?,
                &geometry_world,
            );
            let on_node = node.parts.len() == 1 && motion::is_identity(&relative);
            let geometry_id = if on_node {
                root["nodes"][i]["mesh"] = json!(mesh_id);
                i
            } else {
                let id = root["nodes"].as_array().unwrap().len();
                root["nodes"].as_array_mut().unwrap().push(json!({"name":"Geometry","mesh":mesh_id,"matrix":relative.iter().flatten().copied().collect::<Vec<_>>(),"children":[]}));
                if node.parts.len() == 1 && part["skins"].as_array().is_none_or(Vec::is_empty) {
                    root["nodes"][i]["extras"]["rodeo"]["geometryChild"] = json!(id);
                }
                root["nodes"][i]["children"]
                    .as_array_mut()
                    .unwrap()
                    .push(json!(id));
                id
            };
            geometry_nodes[i].push(geometry_id);
            if !binding.weights.is_empty() {
                root["nodes"][geometry_id]["weights"] = json!(binding.weights);
            }
            if let Some(skin) = part["skins"].as_array().and_then(|s| s.first()) {
                if !binding.joint_nodes.is_empty() {
                    if binding.joint_nodes.len() != meshes[binding.mesh].bones.len()
                        || binding.joint_nodes.iter().any(|n| *n >= scene.nodes.len())
                    {
                        return Err("invalid joint node mapping".into());
                    }
                    let skin_id = root["skins"].as_array().unwrap().len();
                    let mut skin = skin.clone();
                    skin["joints"] = json!(binding.joint_nodes);
                    skin.as_object_mut().unwrap().remove("skeleton");
                    root["skins"].as_array_mut().unwrap().push(skin);
                    root["nodes"][geometry_id]["skin"] = json!(skin_id);
                    continue;
                }
                let start = root["nodes"].as_array().unwrap().len();
                let bones = &meshes[binding.mesh].bones;
                let poses = if binding.poses.is_empty() {
                    bones.iter().map(|b| b.cframe).collect()
                } else {
                    binding.poses.clone()
                };
                if poses.len() != bones.len() {
                    return Err("bone pose count mismatch".into());
                }
                let mut skeleton_roots = Vec::new();
                for (j, bone) in bones.iter().enumerate() {
                    let current = mesh::mat_from_cframe(&poses[j]);
                    let local = if let Some(p) = bone.parent {
                        mesh::mat_mul(
                            &mesh::mat_inverse(&mesh::mat_from_cframe(&poses[p as usize]))
                                .ok_or("singular bone pose")?,
                            &current,
                        )
                    } else {
                        current
                    };
                    let children: Vec<_> = bones
                        .iter()
                        .enumerate()
                        .filter_map(|(k, b)| {
                            if b.parent == Some(j as u32) {
                                Some(start + k)
                            } else {
                                None
                            }
                        })
                        .collect();
                    root["nodes"].as_array_mut().unwrap().push(json!({"name":bone.name,"matrix":local.iter().flatten().copied().collect::<Vec<_>>(),"children":children}));
                    if bone.parent.is_none() {
                        skeleton_roots.push(start + j);
                    }
                }
                root["nodes"][geometry_id]["children"]
                    .as_array_mut()
                    .unwrap()
                    .extend(skeleton_roots.into_iter().map(|n| json!(n)));
                let skin_id = root["skins"].as_array().unwrap().len();
                let mut skin = skin.clone();
                skin["joints"] = json!((start..start + bones.len()).collect::<Vec<_>>());
                skin.as_object_mut().unwrap().remove("skeleton");
                root["skins"].as_array_mut().unwrap().push(skin);
                root["nodes"][geometry_id]["skin"] = json!(skin_id);
            }
        }
    }
    motion::write_animations(scene, &geometry_nodes, &mut root, &mut binary)?;
    // glTF optional arrays have minItems=1; omit empty child/root lists.
    for node in root["nodes"].as_array_mut().unwrap() {
        if node["children"].as_array().is_some_and(Vec::is_empty) {
            node.as_object_mut().unwrap().remove("children");
        }
    }
    if scene.roots.is_empty() {
        root["scenes"][0].as_object_mut().unwrap().remove("nodes");
    }
    for key in [
        "nodes",
        "skins",
        "materials",
        "textures",
        "images",
        "samplers",
        "meshes",
        "accessors",
        "bufferViews",
    ] {
        if root[key].as_array().is_some_and(|v| v.is_empty()) {
            root.as_object_mut().unwrap().remove(key);
        }
    }
    // Validate the final graph/accessors before replacing an existing output.
    root["buffers"] = json!([{"byteLength":binary.len().max(1)}]);
    if binary.is_empty() {
        binary.push(0);
    }
    parse_gltf(&serde_json::to_vec(&root).map_err(|e| e.to_string())?)
        .map_err(|e| format!("exported glTF: {e}"))?;
    mesh::write_document(root, binary, path)
}
fn embed_image(
    root: &mut Value,
    binary: &mut Vec<u8>,
    width: u32,
    height: u32,
    bytes: &[u8],
) -> Result<usize, String> {
    use image::ImageEncoder;
    let mut png = Vec::new();
    image::codecs::png::PngEncoder::new(&mut png)
        .write_image(bytes, width, height, image::ExtendedColorType::Rgba8)
        .map_err(|e| e.to_string())?;
    while binary.len() % 4 != 0 {
        binary.push(0);
    }
    let view = root["bufferViews"].as_array().unwrap().len();
    root["bufferViews"]
        .as_array_mut()
        .unwrap()
        .push(json!({"buffer":0,"byteOffset":binary.len(),"byteLength":png.len()}));
    binary.extend(png);
    let image = root["images"].as_array().unwrap().len();
    root["images"]
        .as_array_mut()
        .unwrap()
        .push(json!({"bufferView":view,"mimeType":"image/png"}));
    let texture = root["textures"].as_array().unwrap().len();
    root["textures"]
        .as_array_mut()
        .unwrap()
        .push(json!({"source":image,"sampler":0}));
    Ok(texture)
}

#[cfg(test)]
mod tests {
    use super::*;
    struct Temp(String);
    impl Temp {
        fn new(ext: &str) -> Self {
            Self(
                std::env::temp_dir()
                    .join(format!("rodeo-scene-{}.{ext}", uuid::Uuid::new_v4()))
                    .to_string_lossy()
                    .into_owned(),
            )
        }
    }
    impl Drop for Temp {
        fn drop(&mut self) {
            let _ = std::fs::remove_file(&self.0);
        }
    }
    fn triangle() -> MeshData {
        MeshData {
            positions: vec![[2., 0., 0.], [4., 0., 0.], [2., 2., 0.]],
            indices: vec![0, 1, 2],
            uvs: Some(vec![[0., 0.], [1., 0.], [0., 1.]]),
            ..Default::default()
        }
    }
    fn fixture() -> (Scene, Vec<MeshData>, Vec<Vec<u8>>) {
        let mut transform = mesh::cframe_from_mat(&IDENTITY);
        transform[0] = 10.;
        let scene = Scene {
            roots: vec![0],
            nodes: vec![
                Node {
                    name: "Group".into(),
                    transform,
                    children: vec![1, 2],
                    parts: vec![],
                    source_index: None,
                    ..Default::default()
                },
                Node {
                    name: "First".into(),
                    transform,
                    children: vec![],
                    parts: vec![Binding {
                        mesh: 0,
                        material: Some(0),
                        matrix: IDENTITY,
                        poses: vec![],
                        joint_nodes: vec![],
                        ..Default::default()
                    }],
                    source_index: None,
                    ..Default::default()
                },
                Node {
                    name: "Second".into(),
                    transform: {
                        let mut v = transform;
                        v[1] = 8.;
                        v
                    },
                    children: vec![],
                    parts: vec![Binding {
                        mesh: 0,
                        material: Some(0),
                        matrix: IDENTITY,
                        poses: vec![],
                        joint_nodes: vec![],
                        ..Default::default()
                    }],
                    source_index: None,
                    ..Default::default()
                },
            ],
            meshes: vec![MeshInfo::default()],
            images: vec![ImageInfo {
                width: 2,
                height: 1,
                source_index: None,
                channel: None,
            }],
            materials: vec![Material {
                name: "Paint".into(),
                source_index: None,
                color: [0.2, 0.4, 0.8, 0.5],
                double_sided: true,
                alpha_mode: "BLEND".into(),
                roughness: 1.,
                metalness: 0.,
                native_material: None,
                maps: HashMap::from([("color".into(), 0)]),
            }],
            warnings: vec![],
            ..Default::default()
        };
        (
            scene,
            vec![triangle()],
            vec![vec![255, 0, 0, 255, 0, 255, 0, 128]],
        )
    }
    #[test]
    fn scene_roundtrip_preserves_hierarchy_instancing_materials_and_pixels() {
        for ext in ["glb", "gltf"] {
            let f = Temp::new(ext);
            let (scene, meshes, pixels) = fixture();
            write_scene(&scene, &meshes, &pixels, &f.0).unwrap();
            let (out, geometry, images) = read_scene(&f.0).unwrap();
            assert_eq!(out.nodes.len(), 3);
            assert_eq!(out.nodes[0].children, vec![1, 2]);
            assert_eq!(out.nodes[2].transform[1], 8.);
            assert_eq!(geometry.len(), 1);
            assert_eq!(geometry[0], meshes[0]);
            assert_eq!(out.nodes[1].parts[0].mesh, out.nodes[2].parts[0].mesh);
            assert_eq!(out.materials[0].color, [0.2, 0.4, 0.8, 0.5]);
            assert_eq!(images[out.materials[0].maps["color"]], pixels[0]);
            write_scene(&out, &geometry, &images, &f.0).unwrap();
            assert_eq!(read_scene(&f.0).unwrap().0.nodes.len(), 3);
        }
    }
    #[test]
    fn separate_primitives_keep_partial_attributes_and_source_indices() {
        let f = Temp::new("glb");
        let (mut json, bin) = mesh::build_gltf(&triangle()).unwrap();
        let mut second = json["meshes"][0]["primitives"][0].clone();
        second["attributes"]
            .as_object_mut()
            .unwrap()
            .remove("TEXCOORD_0");
        json["meshes"][0]["primitives"]
            .as_array_mut()
            .unwrap()
            .push(second);
        mesh::write_document(json, bin, &f.0).unwrap();
        let (scene, meshes, _) = read_scene(&f.0).unwrap();
        assert_eq!(meshes.len(), 2);
        assert!(meshes[0].uvs.is_some());
        assert!(meshes[1].uvs.is_none());
        assert_eq!(scene.meshes[1].primitive_index, Some(1));
    }
    #[test]
    fn reflected_static_geometry_keeps_front_faces() {
        let f = Temp::new("glb");
        let (mut scene, meshes, pixels) = fixture();
        scene.nodes[1].parts[0].matrix[0][0] = -2.;
        write_scene(&scene, &meshes, &pixels, &f.0).unwrap();
        let (scene, meshes, _) = read_scene(&f.0).unwrap();
        assert_eq!(scene.nodes[1].parts[0].matrix[0][0], 2.);
        assert_eq!(meshes[0].positions[0], [-2., 0., 0.]);
        assert_eq!(meshes[0].indices, vec![0, 2, 1]);
    }
    #[test]
    fn skins_preserve_bind_poses_weights_and_source_joints() {
        let f = Temp::new("glb");
        let (mut scene, mut meshes, pixels) = fixture();
        scene.nodes[0].children = vec![1];
        scene.nodes.truncate(2);
        meshes[0].bones = vec![mesh::Bone {
            name: "Root".into(),
            parent: None,
            cframe: mesh::cframe_from_mat(&IDENTITY),
            is_virtual: false,
        }];
        meshes[0].joints = Some(vec![[0, mesh::NONE, mesh::NONE, mesh::NONE]; 3]);
        meshes[0].weights = Some(vec![[1., 0., 0., 0.]; 3]);
        write_scene(&scene, &meshes, &pixels, &f.0).unwrap();
        let (out, data, _) = read_scene(&f.0).unwrap();
        assert_eq!(data[0].joints, meshes[0].joints);
        assert_eq!(data[0].bones, meshes[0].bones);
        assert_eq!(out.meshes[0].joint_nodes.len(), 1);
        assert_eq!(
            out.nodes[1].parts[0].poses[0],
            mesh::cframe_from_mat(&IDENTITY)
        );
    }
    #[test]
    fn rejects_shear_required_extensions_and_truncated_packets() {
        let mut shear = IDENTITY;
        shear[1][0] = 0.5;
        assert!(decompose(shear).unwrap_err().contains("shear"));
        let (scene, meshes, images) = fixture();
        let packet = pack(&scene, &meshes, &images).unwrap();
        assert!(unpack(&packet[..packet.len() - 1]).is_err());
        let f = Temp::new("gltf");
        let (mut json, bin) = mesh::build_gltf(&triangle()).unwrap();
        json["extensionsRequired"] = json!(["KHR_materials_unlit"]);
        json["extensionsUsed"] = json!(["KHR_materials_unlit"]);
        mesh::write_document(json, bin, &f.0).unwrap();
        assert!(read_scene(&f.0).err().unwrap().contains("extension"));
    }
    #[test]
    fn empty_scene_and_packet_roundtrip() {
        let (scene, meshes, images) = fixture();
        let packet = pack(&scene, &meshes, &images).unwrap();
        let (out, m, p) = unpack(&packet).unwrap();
        assert_eq!(out.nodes.len(), 3);
        assert_eq!(m, meshes);
        assert_eq!(p, images);
        let f = Temp::new("gltf");
        write_scene(&Scene::default(), &[], &[], &f.0).unwrap();
        assert!(read_scene(&f.0).unwrap().0.nodes.is_empty());
        let json: Value = serde_json::from_slice(&std::fs::read(&f.0).unwrap()).unwrap();
        assert!(json.get("nodes").is_none());
        assert!(json["scenes"][0].get("nodes").is_none());
    }

    fn motion_fixture() -> (Scene, Vec<MeshData>, Vec<Vec<u8>>) {
        read_scene(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../tests-new/fixtures/pkg/scenes/motion.gltf"
        ))
        .unwrap()
    }

    #[test]
    fn curves_sparse_morphs_tangents_and_instance_weights_roundtrip() {
        for extension in ["glb", "gltf"] {
            let (scene, meshes, images) = motion_fixture();
            assert_eq!(scene.animations[0].channels.len(), 4);
            assert_eq!(
                scene.meshes[0].morph.targets[0].positions.as_ref().unwrap(),
                &vec![[0., 0., 0.], [0., 0., 0.], [0., 2., 0.]]
            );
            assert_eq!(
                scene.meshes[0].morph.targets[0].name.as_deref(),
                Some("Tall")
            );
            assert_ne!(
                scene.nodes[1].parts[0].weights,
                scene.nodes[2].parts[0].weights
            );
            let file = Temp::new(extension);
            write_scene(&scene, &meshes, &images, &file.0).unwrap();
            let (out, geometry, _) = read_scene(&file.0).unwrap();
            assert_eq!(scene.animations, out.animations);
            assert_eq!(scene.meshes[0].morph, out.meshes[0].morph);
            assert_eq!(meshes, geometry);
            for (a, b) in scene.nodes.iter().zip(&out.nodes) {
                assert_eq!(a.world, b.world);
                assert_eq!(
                    a.parts.iter().map(|p| &p.weights).collect::<Vec<_>>(),
                    b.parts.iter().map(|p| &p.weights).collect::<Vec<_>>()
                );
            }
        }
    }

    #[test]
    fn cubic_quaternions_and_weight_channels_keep_tangents_and_fan_out_primitives() {
        let (mut scene, meshes, images) = motion_fixture();
        let (mesh, matrix) = (scene.nodes[1].parts[0].mesh, scene.nodes[1].parts[0].matrix);
        scene.nodes[1].parts.push(Binding {
            mesh,
            matrix,
            weights: vec![0.25, 0.5],
            ..Default::default()
        });
        scene.animations[0].channels[1] = motion::Channel {
            node: 2,
            path: "rotation".into(),
            interpolation: "CUBICSPLINE".into(),
            times: vec![0., 2.],
            values: vec![
                0., 0., 0., 0., 0., 0., 0., 1., 0., 0., 0.5, 0., 0., 0., 0.5, 0., 0., 0., 1., 0.,
                0., 0., 0., 0.,
            ],
        };
        let file = Temp::new("glb");
        write_scene(&scene, &meshes, &images, &file.0).unwrap();
        let (out, _, _) = read_scene(&file.0).unwrap();
        assert_eq!(out.animations[0].channels.len(), 5);
        let original = &scene.animations[0].channels[1];
        let channel = out.animations[0]
            .channels
            .iter()
            .find(|c| c.path == "rotation")
            .unwrap();
        assert_eq!(channel.values, original.values);
        let weights: Vec<_> = out.animations[0]
            .channels
            .iter()
            .filter(|c| c.path == "weights")
            .collect();
        assert_eq!(weights.len(), 2);
        assert_eq!(weights[0].values, weights[1].values);
        assert_ne!(weights[0].node, weights[1].node);
    }

    #[test]
    fn animated_negative_scale_keeps_original_trs_basis() {
        let mut matrix = IDENTITY;
        matrix[1][1] = -2.;
        let mut node = json!({});
        motion::write_trs(&mut node, matrix, Some([1., -2., 1.])).unwrap();
        assert_eq!(node["scale"], json!([1., -2., 1.]));
        assert_eq!(node["rotation"], json!([0., 0., 0., 1.]));
    }

    #[test]
    fn invalid_motion_data_errors_before_replacing_destination() {
        let (mut scene, mut meshes, images) = motion_fixture();
        let file = Temp::new("glb");
        std::fs::write(&file.0, b"keep me").unwrap();
        scene.animations[0].channels[0].times[1] = 0.;
        assert!(write_scene(&scene, &meshes, &images, &file.0)
            .unwrap_err()
            .contains("increasing"));
        scene.animations[0].channels[0].times[1] = 1.;
        scene.meshes[0].morph.targets[0]
            .positions
            .as_mut()
            .unwrap()
            .pop();
        assert!(write_scene(&scene, &meshes, &images, &file.0)
            .unwrap_err()
            .contains("vertex count"));
        scene.meshes[0].morph.targets[0]
            .positions
            .as_mut()
            .unwrap()
            .push([0., 2., 0.]);
        scene.nodes[1].parts[0].weights.push(1.);
        assert!(write_scene(&scene, &meshes, &images, &file.0)
            .unwrap_err()
            .contains("weight count"));
        scene.nodes[1].parts[0].weights.pop();
        meshes[0].normals = None;
        assert!(write_scene(&scene, &meshes, &images, &file.0)
            .unwrap_err()
            .contains("base normals"));
        assert_eq!(std::fs::read(&file.0).unwrap(), b"keep me");
    }
}
