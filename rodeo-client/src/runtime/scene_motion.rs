//! Portable glTF motion data. Curves stay in node-local space; morph deltas
//! stay in mesh space. Neither is resampled into Roblox bone/FACS poses.
use super::*;
use std::collections::HashSet;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(in crate::runtime) struct Trs {
    pub translation: [f32; 3],
    pub rotation: [f32; 4],
    pub scale: [f32; 3],
}
impl Trs {
    pub fn from_node(node: &gltf::Node) -> Self {
        let (translation, rotation, scale) = node.transform().decomposed();
        Self {
            translation,
            rotation,
            scale,
        }
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub(in crate::runtime) struct Morph {
    #[serde(default)]
    pub targets: Vec<Target>,
    pub tangents: Option<Vec<[f32; 4]>>,
}
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub(in crate::runtime) struct Target {
    pub name: Option<String>,
    pub positions: Option<Vec<[f32; 3]>>,
    pub normals: Option<Vec<[f32; 3]>>,
    pub tangents: Option<Vec<[f32; 3]>>,
}
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub(in crate::runtime) struct Animation {
    pub name: String,
    pub source_index: Option<usize>,
    pub channels: Vec<Channel>,
}
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub(in crate::runtime) struct Channel {
    pub node: usize,
    pub path: String,
    pub interpolation: String,
    pub times: Vec<f32>,
    /// Flat scalars: xyzw for rotations; in/value/out triples for cubic keys.
    pub values: Vec<f32>,
}

pub(super) fn read_morph(
    primitive: &gltf::Primitive,
    gmesh: &gltf::Mesh,
    buffers: &[Vec<u8>],
    reflected: bool,
) -> Result<Morph, String> {
    let reader = primitive.reader(|b| buffers.get(b.index()).map(Vec::as_slice));
    let extras: Value = gmesh
        .extras()
        .as_ref()
        .map(|e| serde_json::from_str(e.get()))
        .transpose()
        .map_err(|e| e.to_string())?
        .unwrap_or(Value::Null);
    let mut targets = Vec::new();
    for (i, (p, n, t)) in reader.read_morph_targets().enumerate() {
        let mut target = Target {
            name: extras["targetNames"][i].as_str().map(str::to_owned),
            positions: p.map(Iterator::collect),
            normals: n.map(Iterator::collect),
            tangents: t.map(Iterator::collect),
        };
        // A declared but unreadable accessor must not turn into an omitted delta.
        let declared = primitive.morph_targets().nth(i).unwrap();
        if (declared.positions().is_some() && target.positions.is_none())
            || (declared.normals().is_some() && target.normals.is_none())
            || (declared.tangents().is_some() && target.tangents.is_none())
        {
            return Err(format!("morph target {i}: unreadable accessor"));
        }
        if reflected {
            for values in [
                &mut target.positions,
                &mut target.normals,
                &mut target.tangents,
            ]
            .into_iter()
            .flatten()
            {
                for v in values {
                    v[0] = -v[0];
                }
            }
        }
        targets.push(target);
    }
    let mut tangents: Option<Vec<[f32; 4]>> = reader.read_tangents().map(Iterator::collect);
    if primitive.get(&gltf::Semantic::Tangents).is_some() && tangents.is_none() {
        return Err("unreadable base tangent accessor".into());
    }
    if reflected {
        if let Some(values) = &mut tangents {
            for v in values {
                v[0] = -v[0];
                v[3] = -v[3];
            }
        }
    }
    Ok(Morph { targets, tangents })
}

pub(super) fn read_animations(
    gltf: &gltf::Gltf,
    buffers: &[Vec<u8>],
    node_ids: &HashMap<usize, usize>,
    warnings: &mut Vec<String>,
) -> Result<Vec<Animation>, String> {
    use gltf::animation::{util::ReadOutputs, Property};
    let mut animations = Vec::new();
    for animation in gltf.animations() {
        let mut channels = Vec::new();
        for channel in animation.channels() {
            let source = channel.target().node().index();
            let Some(node) = node_ids.get(&source) else {
                warnings.push(format!("animation {}: channel for node {source} outside the selected scene was omitted", animation.index()));
                continue;
            };
            let reader = channel.reader(|b| buffers.get(b.index()).map(Vec::as_slice));
            let times = reader
                .read_inputs()
                .ok_or("unreadable animation times")?
                .collect();
            let values = match reader.read_outputs().ok_or("unreadable animation values")? {
                ReadOutputs::Translations(v) | ReadOutputs::Scales(v) => v.flatten().collect(),
                ReadOutputs::Rotations(v) => v.into_f32().flatten().collect(),
                ReadOutputs::MorphTargetWeights(v) => v.into_f32().collect(),
            };
            let path = match channel.target().property() {
                Property::Translation => "translation",
                Property::Rotation => "rotation",
                Property::Scale => "scale",
                Property::MorphTargetWeights => "weights",
            }
            .into();
            let interpolation = match channel.sampler().interpolation() {
                gltf::animation::Interpolation::Linear => "LINEAR",
                gltf::animation::Interpolation::Step => "STEP",
                gltf::animation::Interpolation::CubicSpline => "CUBICSPLINE",
            }
            .into();
            channels.push(Channel {
                node: *node,
                path,
                interpolation,
                times,
                values,
            });
        }
        if !channels.is_empty() {
            animations.push(Animation {
                name: animation.name().unwrap_or("Animation").into(),
                source_index: Some(animation.index()),
                channels,
            });
        }
    }
    Ok(animations)
}

fn dimensions(scene: &Scene, channel: &Channel) -> Result<usize, String> {
    let node = scene
        .nodes
        .get(channel.node)
        .ok_or("animation target node out of range")?;
    match channel.path.as_str() {
        "translation" | "scale" => Ok(3),
        "rotation" => Ok(4),
        "weights" => {
            let binding = node
                .parts
                .first()
                .ok_or("weight animation target has no mesh")?;
            let count = scene.meshes[binding.mesh].morph.targets.len();
            if count == 0
                || node
                    .parts
                    .iter()
                    .any(|p| scene.meshes[p.mesh].morph.targets.len() != count)
            {
                return Err(
                    "weight animation target has inconsistent/missing morph targets".into(),
                );
            }
            Ok(count)
        }
        _ => Err(format!("unknown animation path {}", channel.path)),
    }
}

pub(super) fn validate(scene: &Scene, meshes: &[MeshData]) -> Result<(), String> {
    if scene.meshes.len() != meshes.len() {
        return Err("scene mesh metadata count mismatch".into());
    }
    for (info, mesh) in scene.meshes.iter().zip(meshes) {
        let check = |count: usize, finite: bool| -> Result<(), String> {
            if count != mesh.positions.len() {
                return Err("morph/tangent vertex count mismatch".into());
            }
            if !finite {
                return Err("non-finite morph/tangent data".into());
            }
            Ok(())
        };
        if let Some(v) = &info.morph.tangents {
            check(v.len(), v.iter().flatten().all(|x| x.is_finite()))?;
        }
        for target in &info.morph.targets {
            if target.positions.is_none() && target.normals.is_none() && target.tangents.is_none() {
                return Err("morph target has no attributes".into());
            }
            for v in [&target.positions, &target.normals, &target.tangents]
                .into_iter()
                .flatten()
            {
                check(v.len(), v.iter().flatten().all(|x| x.is_finite()))?;
            }
            if target.normals.is_some() && mesh.normals.is_none() {
                return Err("morph normals require base normals".into());
            }
            if target.tangents.is_some() && info.morph.tangents.is_none() {
                return Err("morph tangents require base tangents".into());
            }
        }
    }
    for node in &scene.nodes {
        for binding in &node.parts {
            let info = scene
                .meshes
                .get(binding.mesh)
                .ok_or("node mesh index out of range")?;
            if !binding.weights.is_empty() && binding.weights.len() != info.morph.targets.len() {
                return Err("morph weight count mismatch".into());
            }
            if binding.weights.iter().any(|v| !v.is_finite()) {
                return Err("non-finite morph weights".into());
            }
        }
    }
    for animation in &scene.animations {
        if animation.channels.is_empty() {
            return Err("animation has no channels".into());
        }
        let mut targets = HashSet::new();
        for channel in &animation.channels {
            let components = dimensions(scene, channel)?;
            if !targets.insert((channel.node, &channel.path)) {
                return Err("duplicate animation channel target/path".into());
            }
            let cubic = match channel.interpolation.as_str() {
                "CUBICSPLINE" => true,
                "LINEAR" | "STEP" => false,
                _ => {
                    return Err(format!(
                        "unknown animation interpolation {}",
                        channel.interpolation
                    ))
                }
            };
            if channel.times.is_empty()
                || (cubic && channel.times.len() < 2)
                || channel.times.iter().any(|t| !t.is_finite() || *t < 0.)
                || channel.times.windows(2).any(|w| w[0] >= w[1])
            {
                return Err("animation times must be finite, nonnegative and strictly increasing (cubic needs two keys)".into());
            }
            let stride = components * if cubic { 3 } else { 1 };
            if channel.values.len() != channel.times.len() * stride {
                return Err(
                    "animation value count does not match times/components/interpolation".into(),
                );
            }
            if channel.values.iter().any(|v| !v.is_finite()) {
                return Err("non-finite animation values".into());
            }
            if channel.path == "rotation" {
                for key in channel.values.chunks_exact(stride) {
                    let q = if cubic { &key[4..8] } else { key };
                    if (q.iter().map(|v| v * v).sum::<f32>() - 1.).abs() > 0.002 {
                        return Err(
                            "animation rotation values must be unit quaternions (xyzw)".into()
                        );
                    }
                }
            }
        }
    }
    Ok(())
}

fn accessor(
    root: &mut Value,
    binary: &mut Vec<u8>,
    values: &[f32],
    components: usize,
    bounds: bool,
    vertex: bool,
) -> usize {
    while binary.len() % 4 != 0 {
        binary.push(0);
    }
    let offset = binary.len();
    for v in values {
        binary.extend(v.to_le_bytes());
    }
    let view = root["bufferViews"].as_array().unwrap().len();
    root["bufferViews"]
        .as_array_mut()
        .unwrap()
        .push(json!({"buffer":0,"byteOffset":offset,"byteLength":values.len()*4}));
    if vertex {
        root["bufferViews"][view]["target"] = json!(34962);
    }
    let kind = match components {
        1 => "SCALAR",
        3 => "VEC3",
        4 => "VEC4",
        _ => unreachable!(),
    };
    let mut a =
        json!({"bufferView":view,"componentType":5126,"count":values.len()/components,"type":kind});
    if bounds {
        let mut min = vec![f32::MAX; components];
        let mut max = vec![f32::MIN; components];
        for row in values.chunks_exact(components) {
            for k in 0..components {
                min[k] = min[k].min(row[k]);
                max[k] = max[k].max(row[k]);
            }
        }
        a["min"] = json!(min);
        a["max"] = json!(max);
    }
    let id = root["accessors"].as_array().unwrap().len();
    root["accessors"].as_array_mut().unwrap().push(a);
    id
}
pub(super) fn write_morph(
    morph: &Morph,
    primitive: &mut Value,
    root: &mut Value,
    binary: &mut Vec<u8>,
) -> Result<(), String> {
    if let Some(v) = &morph.tangents {
        primitive["attributes"]["TANGENT"] = json!(accessor(
            root,
            binary,
            &v.iter().flatten().copied().collect::<Vec<_>>(),
            4,
            false,
            true
        ));
    }
    if !morph.targets.is_empty() {
        let mut targets = Vec::new();
        for target in &morph.targets {
            let mut out = json!({});
            for (semantic, v) in [
                ("POSITION", &target.positions),
                ("NORMAL", &target.normals),
                ("TANGENT", &target.tangents),
            ] {
                if let Some(v) = v {
                    out[semantic] = json!(accessor(
                        root,
                        binary,
                        &v.iter().flatten().copied().collect::<Vec<_>>(),
                        3,
                        semantic == "POSITION",
                        true
                    ));
                }
            }
            targets.push(out);
        }
        primitive["targets"] = json!(targets);
    }
    Ok(())
}
pub(super) fn write_morph_names(morph: &Morph, mesh: &mut Value) {
    if morph.targets.iter().any(|t| t.name.is_some()) {
        mesh["extras"] = json!({"targetNames":morph.targets.iter().map(|t| t.name.as_deref().unwrap_or("")).collect::<Vec<_>>()});
    }
}
pub(super) fn is_identity(m: &Mat4) -> bool {
    m.iter()
        .flatten()
        .zip(IDENTITY.iter().flatten())
        .all(|(a, b)| (a - b).abs() < 1e-5)
}
pub(super) fn write_trs(
    node: &mut Value,
    local: Mat4,
    sign_hint: Option<[f32; 3]>,
) -> Result<(), String> {
    let (mut rotation, mut scale) = decompose(local).map_err(|e| format!("animated node: {e}"))?;
    // Several TRS factorizations represent the same matrix. Keep the source
    // scale signs so the original rotation/scale curves keep their meaning.
    if let Some(hint) = sign_hint {
        for k in 0..3 {
            if scale[k].is_sign_negative() != hint[k].is_sign_negative() {
                scale[k] = -scale[k];
                for row in 0..3 {
                    rotation[k][row] = -rotation[k][row];
                }
            }
        }
        let determinant = rotation[0][0]
            * (rotation[1][1] * rotation[2][2] - rotation[1][2] * rotation[2][1])
            - rotation[1][0] * (rotation[0][1] * rotation[2][2] - rotation[0][2] * rotation[2][1])
            + rotation[2][0] * (rotation[0][1] * rotation[1][2] - rotation[0][2] * rotation[1][1]);
        if determinant < 0. {
            return Err(
                "animated node reflection changed; update its animation coordinate frame".into(),
            );
        }
    }
    node["translation"] = json!([local[3][0], local[3][1], local[3][2]]);
    node["rotation"] = json!(mesh::quat_from_mat(&rotation));
    node["scale"] = json!(scale);
    Ok(())
}
pub(super) fn write_animations(
    scene: &Scene,
    geometry_nodes: &[Vec<usize>],
    root: &mut Value,
    binary: &mut Vec<u8>,
) -> Result<(), String> {
    if scene.animations.is_empty() {
        return Ok(());
    }
    let mut animations = Vec::new();
    for animation in &scene.animations {
        let mut samplers = Vec::new();
        let mut channels = Vec::new();
        for channel in &animation.channels {
            let components = if channel.path == "weights" {
                1
            } else {
                dimensions(scene, channel)?
            };
            let input = accessor(root, binary, &channel.times, 1, true, false);
            let output = accessor(root, binary, &channel.values, components, false, false);
            let sampler = samplers.len();
            samplers
                .push(json!({"input":input,"output":output,"interpolation":channel.interpolation}));
            let targets = if channel.path == "weights" {
                geometry_nodes[channel.node].clone()
            } else {
                vec![channel.node]
            };
            for node in targets {
                channels
                    .push(json!({"sampler":sampler,"target":{"node":node,"path":channel.path}}));
            }
        }
        animations.push(json!({"name":animation.name,"channels":channels,"samplers":samplers}));
    }
    root["animations"] = json!(animations);
    Ok(())
}
