//! `roblox.exportEditableMesh` / `roblox.importEditableMesh`: glTF 2.0 on the
//! host side, `EditableMesh` on the Studio side, joined by a packed
//! little-endian interchange blob that the plugin reads and writes with
//! `buffer.*` and streams over the ordinary fs/stream RPCs.
//!
//! glTF was chosen because its conventions are Roblox's (Y-up, right-handed,
//! UV origin top-left, CCW front faces) so nothing is converted, and because
//! it carries everything EditableMesh exposes except FACS poses: positions,
//! per-vertex normals / UVs / RGBA colors, triangles, and skinning (bones with
//! bind poses and up to four influences per vertex via JOINTS_0 / WEIGHTS_0).
//!
//! # BLOB LAYOUT (all little-endian; mirrored in rodeo-plugin/src/library/runner/roblox.luau)
//!
//! ```text
//! u32 magic "RMSH" (0x4853_4D52)   u32 version = 1
//! u32 vertexCount   u32 indexCount (multiple of 3)   u32 flags   u32 boneCount
//! f32[3*V] positions
//! f32[3*V] normals            if flags & NORMALS
//! f32[2*V] uvs                if flags & UVS
//! f32[4*V] colors (rgba)      if flags & COLORS
//! u32[4*V] joints (NONE = unused slot)   if flags & SKIN
//! f32[4*V] weights                       if flags & SKIN
//! u32[indexCount] indices (0-based vertex indices, CCW triangles)
//! per bone (parents always precede children):
//!   u32 parent (NONE = root)   u8 virtual   u8[3] pad
//!   f32[12] CFrame components (x y z R00 R01 R02 R10 R11 R12 R20 R21 R22), bind pose, mesh-local
//!   u32 nameLen   u8[nameLen] name (UTF-8)   pad to 4
//! ```
//!
//! Vertices are glTF-style: every attribute is per vertex and faces index
//! vertices. EditableMesh attributes are per face corner, so the plugin splits
//! corners into unique (vertex, normal, uv, color) tuples on export and binds
//! each corner to its vertex's attribute ids on import.

use super::{stream, SharedRpcState, StreamHandler};
use rodeo_proto::runtime_types as rt;

const MAGIC: u32 = 0x4853_4D52;
const VERSION: u32 = 1;
const F_NORMALS: u32 = 1;
const F_UVS: u32 = 2;
const F_COLORS: u32 = 4;
const F_SKIN: u32 = 8;
pub const NONE: u32 = u32::MAX;

#[derive(Debug, Clone, PartialEq, Default)]
pub struct Bone {
    pub name: String,
    pub parent: Option<u32>,
    /// CFrame:GetComponents() order: x y z R00 R01 R02 R10 R11 R12 R20 R21 R22.
    pub cframe: [f32; 12],
    pub is_virtual: bool,
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct MeshData {
    pub positions: Vec<[f32; 3]>,
    pub normals: Option<Vec<[f32; 3]>>,
    pub uvs: Option<Vec<[f32; 2]>>,
    pub colors: Option<Vec<[f32; 4]>>,
    pub joints: Option<Vec<[u32; 4]>>,
    pub weights: Option<Vec<[f32; 4]>>,
    pub indices: Vec<u32>,
    pub bones: Vec<Bone>,
}

// ---------------------------------------------------------------------------
// RPC entry points
// ---------------------------------------------------------------------------

/// `roblox.exportEditableMesh`: consume the FileWriter the plugin streamed the
/// blob into, write its path as glTF.
pub async fn roblox_mesh_encode(
    state: SharedRpcState,
    req: &rt::RobloxMeshEncodeRequest,
) -> Result<rt::RobloxMeshEncodeResponse, String> {
    let (path, blob) = stream::take_file_writer(&state, &req.handle).await?;
    tokio::task::spawn_blocking(move || {
        let mesh = decode_blob(&blob).map_err(|e| format!("exportEditableMesh: {e}"))?;
        let dropped = write_mesh(&mesh, &path).map_err(|e| format!("exportEditableMesh: {e}"))?;
        Ok(rt::RobloxMeshEncodeResponse { dropped, ..Default::default() })
    })
    .await
    .map_err(|e| format!("mesh encode task failed: {e}"))?
}

/// Write `mesh` in the format the extension names: glTF (`.glb`, `.gltf`) or
/// Wavefront OBJ (`.obj`). Returns the features the format could not carry.
pub fn write_mesh(mesh: &MeshData, path: &str) -> Result<Vec<String>, String> {
    let lower = path.to_lowercase();
    if lower.ends_with(".obj") {
        write_obj(mesh, path)
    } else if lower.ends_with(".glb") || lower.ends_with(".gltf") {
        write_gltf(mesh, path)?;
        Ok(Vec::new())
    } else {
        Err(format!("only .glb, .gltf or .obj output is supported (got '{path}')"))
    }
}

/// Read the format the extension names: `.obj` as Wavefront OBJ, anything
/// else as glTF (`.glb` or `.gltf`).
pub fn read_mesh(path: &str) -> Result<MeshData, String> {
    if path.to_lowercase().ends_with(".obj") { read_obj(path) } else { read_gltf(path) }
}

/// `roblox.importEditableMesh`: read the glTF, register the blob under the
/// caller-minted handle for chunked reads.
pub async fn roblox_mesh_decode(
    state: SharedRpcState,
    req: &rt::RobloxMeshDecodeRequest,
) -> Result<rt::RobloxMeshDecodeResponse, String> {
    let path = req.path.clone();
    let mesh = tokio::task::spawn_blocking(move || read_mesh(&path))
        .await
        .map_err(|e| format!("mesh decode task failed: {e}"))?
        .map_err(|e| format!("importEditableMesh: {e}"))?;
    let response = rt::RobloxMeshDecodeResponse {
        vertex_count: mesh.positions.len() as u32,
        face_count: (mesh.indices.len() / 3) as u32,
        bone_count: mesh.bones.len() as u32,
        ..Default::default()
    };
    let blob = encode_blob(&mesh);
    let mut guard = state.lock().await;
    if guard.stream_handlers.contains_key(&req.handle) {
        return Err(format!("handle already open: {}", req.handle));
    }
    guard.stream_handlers.insert(
        req.handle.clone(),
        StreamHandler::FileReader { reader: Box::new(std::io::Cursor::new(blob)) },
    );
    Ok(response)
}

// ---------------------------------------------------------------------------
// Blob codec
// ---------------------------------------------------------------------------

pub fn encode_blob(mesh: &MeshData) -> Vec<u8> {
    let mut out = Vec::new();
    let mut flags = 0;
    if mesh.normals.is_some() { flags |= F_NORMALS; }
    if mesh.uvs.is_some() { flags |= F_UVS; }
    if mesh.colors.is_some() { flags |= F_COLORS; }
    if mesh.joints.is_some() && mesh.weights.is_some() { flags |= F_SKIN; }
    for v in [MAGIC, VERSION, mesh.positions.len() as u32, mesh.indices.len() as u32, flags, mesh.bones.len() as u32] {
        out.extend_from_slice(&v.to_le_bytes());
    }
    for p in &mesh.positions { for c in p { out.extend_from_slice(&c.to_le_bytes()); } }
    if let Some(n) = &mesh.normals { for v in n { for c in v { out.extend_from_slice(&c.to_le_bytes()); } } }
    if let Some(u) = &mesh.uvs { for v in u { for c in v { out.extend_from_slice(&c.to_le_bytes()); } } }
    if let Some(cs) = &mesh.colors { for v in cs { for c in v { out.extend_from_slice(&c.to_le_bytes()); } } }
    if flags & F_SKIN != 0 {
        for j in mesh.joints.as_ref().unwrap() { for c in j { out.extend_from_slice(&c.to_le_bytes()); } }
        for w in mesh.weights.as_ref().unwrap() { for c in w { out.extend_from_slice(&c.to_le_bytes()); } }
    }
    for i in &mesh.indices { out.extend_from_slice(&i.to_le_bytes()); }
    for b in &mesh.bones {
        out.extend_from_slice(&b.parent.unwrap_or(NONE).to_le_bytes());
        out.push(b.is_virtual as u8);
        out.extend_from_slice(&[0, 0, 0]);
        for c in &b.cframe { out.extend_from_slice(&c.to_le_bytes()); }
        let name = b.name.as_bytes();
        out.extend_from_slice(&(name.len() as u32).to_le_bytes());
        out.extend_from_slice(name);
        while out.len() % 4 != 0 { out.push(0); }
    }
    out
}

struct Cursor<'a> { data: &'a [u8], pos: usize }

impl<'a> Cursor<'a> {
    fn take(&mut self, n: usize, what: &str) -> Result<&'a [u8], String> {
        let end = self.pos.checked_add(n).ok_or("blob length overflow")?;
        if end > self.data.len() {
            return Err(format!("mesh blob truncated reading {what} ({} bytes needed at {}, {} available)", n, self.pos, self.data.len()));
        }
        let s = &self.data[self.pos..end];
        self.pos = end;
        Ok(s)
    }
    fn u32(&mut self, what: &str) -> Result<u32, String> {
        Ok(u32::from_le_bytes(self.take(4, what)?.try_into().unwrap()))
    }
    fn f32(&mut self, what: &str) -> Result<f32, String> {
        Ok(f32::from_le_bytes(self.take(4, what)?.try_into().unwrap()))
    }
    fn f32s<const N: usize>(&mut self, count: usize, what: &str) -> Result<Vec<[f32; N]>, String> {
        let mut v = Vec::with_capacity(count);
        for _ in 0..count {
            let mut a = [0f32; N];
            for c in a.iter_mut() { *c = self.f32(what)?; }
            v.push(a);
        }
        Ok(v)
    }
}

pub fn decode_blob(data: &[u8]) -> Result<MeshData, String> {
    let mut c = Cursor { data, pos: 0 };
    if c.u32("magic")? != MAGIC { return Err("not a rodeo mesh blob (bad magic)".into()); }
    let version = c.u32("version")?;
    if version != VERSION { return Err(format!("unsupported mesh blob version {version}")); }
    let vertex_count = c.u32("vertexCount")? as usize;
    let index_count = c.u32("indexCount")? as usize;
    let flags = c.u32("flags")?;
    let bone_count = c.u32("boneCount")? as usize;
    if index_count % 3 != 0 { return Err(format!("index count {index_count} is not a multiple of 3")); }

    let positions = c.f32s::<3>(vertex_count, "positions")?;
    let normals = if flags & F_NORMALS != 0 { Some(c.f32s::<3>(vertex_count, "normals")?) } else { None };
    let uvs = if flags & F_UVS != 0 { Some(c.f32s::<2>(vertex_count, "uvs")?) } else { None };
    let colors = if flags & F_COLORS != 0 { Some(c.f32s::<4>(vertex_count, "colors")?) } else { None };
    let (joints, weights) = if flags & F_SKIN != 0 {
        let mut j = Vec::with_capacity(vertex_count);
        for _ in 0..vertex_count {
            let mut a = [NONE; 4];
            for s in a.iter_mut() { *s = c.u32("joints")?; }
            j.push(a);
        }
        (Some(j), Some(c.f32s::<4>(vertex_count, "weights")?))
    } else { (None, None) };
    let mut indices = Vec::with_capacity(index_count);
    for _ in 0..index_count {
        let i = c.u32("indices")?;
        if i as usize >= vertex_count { return Err(format!("face index {i} out of range for {vertex_count} vertices")); }
        indices.push(i);
    }
    let mut bones = Vec::with_capacity(bone_count);
    for b in 0..bone_count {
        let parent = c.u32("bone parent")?;
        let is_virtual = c.take(4, "bone flags")?[0] != 0;
        let mut cframe = [0f32; 12];
        for v in cframe.iter_mut() { *v = c.f32("bone cframe")?; }
        let name_len = c.u32("bone name length")? as usize;
        let name = String::from_utf8(c.take(name_len, "bone name")?.to_vec()).map_err(|e| format!("bone name: {e}"))?;
        let padded = (name_len + 3) / 4 * 4;
        c.take(padded - name_len, "bone name padding")?;
        if parent != NONE && parent as usize >= b {
            return Err(format!("bone '{name}' references parent {parent}, but parents must precede children"));
        }
        bones.push(Bone { name, parent: if parent == NONE { None } else { Some(parent) }, cframe, is_virtual });
    }
    if let Some(j) = &joints {
        for (vi, slots) in j.iter().enumerate() {
            for s in slots {
                if *s != NONE && *s as usize >= bone_count {
                    return Err(format!("vertex {vi} references bone {s}, but there are {bone_count} bones"));
                }
            }
        }
    }
    Ok(MeshData { positions, normals, uvs, colors, joints, weights, indices, bones })
}

// ---------------------------------------------------------------------------
// Matrix helpers (column-major [col][row], as glTF and gltf::scene::Transform)
// ---------------------------------------------------------------------------

type Mat4 = [[f32; 4]; 4];

const IDENTITY: Mat4 = [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]];

fn mat_mul(a: &Mat4, b: &Mat4) -> Mat4 {
    let mut m = [[0f32; 4]; 4];
    for c in 0..4 {
        for r in 0..4 {
            m[c][r] = (0..4).map(|k| a[k][r] * b[c][k]).sum();
        }
    }
    m
}

fn transform_point(m: &Mat4, p: [f32; 3]) -> [f32; 3] {
    let mut out = [0f32; 3];
    for r in 0..3 {
        out[r] = m[0][r] * p[0] + m[1][r] * p[1] + m[2][r] * p[2] + m[3][r];
    }
    out
}

fn normalize(v: [f32; 3]) -> [f32; 3] {
    let len = (v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).sqrt();
    if len > 1e-12 { [v[0] / len, v[1] / len, v[2] / len] } else { v }
}

/// General 4x4 inverse (cofactor expansion). Returns None when singular.
fn mat_inverse(m: &Mat4) -> Option<Mat4> {
    // Flatten column-major into a[row][col] for readability.
    let a = |r: usize, c: usize| m[c][r];
    let mut inv = [[0f32; 4]; 4];
    let s0 = a(0, 0) * a(1, 1) - a(1, 0) * a(0, 1);
    let s1 = a(0, 0) * a(1, 2) - a(1, 0) * a(0, 2);
    let s2 = a(0, 0) * a(1, 3) - a(1, 0) * a(0, 3);
    let s3 = a(0, 1) * a(1, 2) - a(1, 1) * a(0, 2);
    let s4 = a(0, 1) * a(1, 3) - a(1, 1) * a(0, 3);
    let s5 = a(0, 2) * a(1, 3) - a(1, 2) * a(0, 3);
    let c5 = a(2, 2) * a(3, 3) - a(3, 2) * a(2, 3);
    let c4 = a(2, 1) * a(3, 3) - a(3, 1) * a(2, 3);
    let c3 = a(2, 1) * a(3, 2) - a(3, 1) * a(2, 2);
    let c2 = a(2, 0) * a(3, 3) - a(3, 0) * a(2, 3);
    let c1 = a(2, 0) * a(3, 2) - a(3, 0) * a(2, 2);
    let c0 = a(2, 0) * a(3, 1) - a(3, 0) * a(2, 1);
    let det = s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0;
    if det.abs() < 1e-12 { return None; }
    let d = 1.0 / det;
    let set = |inv: &mut Mat4, r: usize, c: usize, v: f32| inv[c][r] = v * d;
    set(&mut inv, 0, 0, a(1, 1) * c5 - a(1, 2) * c4 + a(1, 3) * c3);
    set(&mut inv, 0, 1, -a(0, 1) * c5 + a(0, 2) * c4 - a(0, 3) * c3);
    set(&mut inv, 0, 2, a(3, 1) * s5 - a(3, 2) * s4 + a(3, 3) * s3);
    set(&mut inv, 0, 3, -a(2, 1) * s5 + a(2, 2) * s4 - a(2, 3) * s3);
    set(&mut inv, 1, 0, -a(1, 0) * c5 + a(1, 2) * c2 - a(1, 3) * c1);
    set(&mut inv, 1, 1, a(0, 0) * c5 - a(0, 2) * c2 + a(0, 3) * c1);
    set(&mut inv, 1, 2, -a(3, 0) * s5 + a(3, 2) * s2 - a(3, 3) * s1);
    set(&mut inv, 1, 3, a(2, 0) * s5 - a(2, 2) * s2 + a(2, 3) * s1);
    set(&mut inv, 2, 0, a(1, 0) * c4 - a(1, 1) * c2 + a(1, 3) * c0);
    set(&mut inv, 2, 1, -a(0, 0) * c4 + a(0, 1) * c2 - a(0, 3) * c0);
    set(&mut inv, 2, 2, a(3, 0) * s4 - a(3, 1) * s2 + a(3, 3) * s0);
    set(&mut inv, 2, 3, -a(2, 0) * s4 + a(2, 1) * s2 - a(2, 3) * s0);
    set(&mut inv, 3, 0, -a(1, 0) * c3 + a(1, 1) * c1 - a(1, 2) * c0);
    set(&mut inv, 3, 1, a(0, 0) * c3 - a(0, 1) * c1 + a(0, 2) * c0);
    set(&mut inv, 3, 2, -a(3, 0) * s3 + a(3, 1) * s1 - a(3, 2) * s0);
    set(&mut inv, 3, 3, a(2, 0) * s3 - a(2, 1) * s1 + a(2, 2) * s0);
    Some(inv)
}

/// Normal matrix: inverse-transpose of the upper 3x3, applied as a direction.
fn transform_normal(m: &Mat4, n: [f32; 3]) -> [f32; 3] {
    let inv = match mat_inverse(m) { Some(i) => i, None => return n };
    // (M^-1)^T applied to n: out[r] = sum_k inv[r][k] * n[k] in [col][row] storage → inv[r][k] is column r, row k.
    let mut out = [0f32; 3];
    for r in 0..3 {
        out[r] = inv[r][0] * n[0] + inv[r][1] * n[1] + inv[r][2] * n[2];
    }
    normalize(out)
}

/// Roblox CFrame components (x y z R00..R22, rows) from a column-major matrix.
fn cframe_from_mat(m: &Mat4) -> [f32; 12] {
    let mut c = [0f32; 12];
    c[0] = m[3][0]; c[1] = m[3][1]; c[2] = m[3][2];
    for r in 0..3 {
        for col in 0..3 {
            c[3 + r * 3 + col] = m[col][r];
        }
    }
    c
}

fn mat_from_cframe(c: &[f32; 12]) -> Mat4 {
    let mut m = IDENTITY;
    m[3][0] = c[0]; m[3][1] = c[1]; m[3][2] = c[2];
    for r in 0..3 {
        for col in 0..3 {
            m[col][r] = c[3 + r * 3 + col];
        }
    }
    m
}

/// Unit quaternion (x, y, z, w) from the rotation part of a column-major matrix.
fn quat_from_mat(m: &Mat4) -> [f32; 4] {
    let r = |row: usize, col: usize| m[col][row];
    let trace = r(0, 0) + r(1, 1) + r(2, 2);
    let q = if trace > 0.0 {
        let s = (trace + 1.0).sqrt() * 2.0;
        [(r(2, 1) - r(1, 2)) / s, (r(0, 2) - r(2, 0)) / s, (r(1, 0) - r(0, 1)) / s, 0.25 * s]
    } else if r(0, 0) > r(1, 1) && r(0, 0) > r(2, 2) {
        let s = (1.0 + r(0, 0) - r(1, 1) - r(2, 2)).sqrt() * 2.0;
        [0.25 * s, (r(0, 1) + r(1, 0)) / s, (r(0, 2) + r(2, 0)) / s, (r(2, 1) - r(1, 2)) / s]
    } else if r(1, 1) > r(2, 2) {
        let s = (1.0 + r(1, 1) - r(0, 0) - r(2, 2)).sqrt() * 2.0;
        [(r(0, 1) + r(1, 0)) / s, 0.25 * s, (r(1, 2) + r(2, 1)) / s, (r(0, 2) - r(2, 0)) / s]
    } else {
        let s = (1.0 + r(2, 2) - r(0, 0) - r(1, 1)).sqrt() * 2.0;
        [(r(0, 2) + r(2, 0)) / s, (r(1, 2) + r(2, 1)) / s, 0.25 * s, (r(1, 0) - r(0, 1)) / s]
    };
    let len = (q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]).sqrt();
    [q[0] / len, q[1] / len, q[2] / len, q[3] / len]
}

// ---------------------------------------------------------------------------
// glTF read
// ---------------------------------------------------------------------------

fn load_buffers(gltf: &gltf::Gltf, path: &str) -> Result<Vec<Vec<u8>>, String> {
    use base64::Engine;
    let base = std::path::Path::new(path).parent().map(|p| p.to_path_buf()).unwrap_or_default();
    let mut out = Vec::new();
    for buffer in gltf.buffers() {
        let bytes = match buffer.source() {
            gltf::buffer::Source::Bin => gltf.blob.clone().ok_or("GLB declares a BIN buffer but has no BIN chunk")?,
            gltf::buffer::Source::Uri(uri) => {
                if let Some(rest) = uri.strip_prefix("data:") {
                    let comma = rest.find(',').ok_or("malformed data URI buffer")?;
                    base64::engine::general_purpose::STANDARD
                        .decode(&rest[comma + 1..])
                        .map_err(|e| format!("data URI buffer: {e}"))?
                } else {
                    let p = base.join(uri);
                    std::fs::read(&p).map_err(|e| format!("read buffer {}: {e}", p.display()))?
                }
            }
        };
        out.push(bytes);
    }
    Ok(out)
}

struct MeshInstance {
    node: usize,
    world: Mat4,
}

fn visit(node: gltf::Node, parent_world: &Mat4, parent: Option<usize>, parents: &mut Vec<Option<usize>>, instances: &mut Vec<MeshInstance>) {
    let world = mat_mul(parent_world, &node.transform().matrix());
    if node.index() >= parents.len() { parents.resize(node.index() + 1, None); }
    parents[node.index()] = parent;
    if node.mesh().is_some() {
        instances.push(MeshInstance { node: node.index(), world });
    }
    for child in node.children() {
        visit(child, &world, Some(node.index()), parents, instances);
    }
}

/// Read a .glb or .gltf into `MeshData`: triangles only, node transforms baked
/// into positions and normals (unskinned meshes), all primitives merged, one
/// skin at most. An attribute is kept only if every primitive carries it.
pub fn read_gltf(path: &str) -> Result<MeshData, String> {
    let bytes = std::fs::read(path).map_err(|e| format!("read {path}: {e}"))?;
    let gltf = gltf::Gltf::from_slice(&bytes).map_err(|e| format!("parse glTF {path}: {e}"))?;
    let buffers = load_buffers(&gltf, path)?;

    let scene = gltf.default_scene().or_else(|| gltf.scenes().next()).ok_or("glTF has no scene")?;
    let mut parents: Vec<Option<usize>> = vec![None; gltf.nodes().len()];
    let mut instances = Vec::new();
    for node in scene.nodes() {
        visit(node, &IDENTITY, None, &mut parents, &mut instances);
    }
    if instances.is_empty() {
        return Err("glTF scene contains no mesh".into());
    }

    let mut mesh = MeshData::default();
    let mut normals: Vec<[f32; 3]> = Vec::new();
    let mut uvs: Vec<[f32; 2]> = Vec::new();
    let mut colors: Vec<[f32; 4]> = Vec::new();
    let mut joints: Vec<[u16; 4]> = Vec::new();
    let mut weights: Vec<[f32; 4]> = Vec::new();
    let (mut all_normals, mut all_uvs, mut all_colors, mut all_skinned) = (true, true, true, true);
    let mut skin_index: Option<usize> = None;
    let mut any_primitive = false;

    for inst in &instances {
        let node = gltf.nodes().nth(inst.node).unwrap();
        let skin = node.skin();
        if let Some(s) = &skin {
            match skin_index {
                None => skin_index = Some(s.index()),
                Some(existing) if existing != s.index() => return Err("glTF uses more than one skin; EditableMesh holds a single skeleton".into()),
                _ => {}
            }
        }
        let gmesh = node.mesh().unwrap();
        for prim in gmesh.primitives() {
            if prim.mode() != gltf::mesh::Mode::Triangles {
                return Err(format!("primitive mode {:?} is not supported; export triangles", prim.mode()));
            }
            any_primitive = true;
            let reader = prim.reader(|b| buffers.get(b.index()).map(|v| v.as_slice()));
            let positions: Vec<[f32; 3]> = reader.read_positions().ok_or("primitive has no POSITION")?.collect();
            let base = mesh.positions.len() as u32;
            let count = positions.len();
            let bake = skin.is_none();
            mesh.positions.extend(positions.iter().map(|p| if bake { transform_point(&inst.world, *p) } else { *p }));

            match reader.read_normals() {
                Some(n) if all_normals => normals.extend(n.map(|v| if bake { transform_normal(&inst.world, v) } else { v })),
                _ => all_normals = false,
            }
            match reader.read_tex_coords(0) {
                Some(t) if all_uvs => uvs.extend(t.into_f32()),
                _ => all_uvs = false,
            }
            match reader.read_colors(0) {
                Some(c) if all_colors => colors.extend(c.into_rgba_f32()),
                _ => all_colors = false,
            }
            match (reader.read_joints(0), reader.read_weights(0)) {
                (Some(j), Some(w)) if all_skinned && skin.is_some() => {
                    joints.extend(j.into_u16());
                    weights.extend(w.into_f32());
                }
                _ => all_skinned = false,
            }
            let indices: Vec<u32> = match reader.read_indices() {
                Some(i) => i.into_u32().collect(),
                None => (0..count as u32).collect(),
            };
            if indices.len() % 3 != 0 { return Err("primitive index count is not a multiple of 3".into()); }
            for i in indices {
                if i as usize >= count { return Err(format!("primitive index {i} out of range for {count} vertices")); }
                mesh.indices.push(base + i);
            }
        }
    }
    if !any_primitive { return Err("glTF mesh has no primitives".into()); }

    if all_normals && normals.len() == mesh.positions.len() { mesh.normals = Some(normals); }
    if all_uvs && uvs.len() == mesh.positions.len() { mesh.uvs = Some(uvs); }
    if all_colors && colors.len() == mesh.positions.len() { mesh.colors = Some(colors); }

    if let Some(si) = skin_index {
        let skin = gltf.skins().nth(si).unwrap();
        let joint_nodes: Vec<gltf::Node> = skin.joints().collect();
        let reader = skin.reader(|b| buffers.get(b.index()).map(|v| v.as_slice()));
        let ibms: Vec<Mat4> = match reader.read_inverse_bind_matrices() {
            Some(m) => m.collect(),
            None => vec![IDENTITY; joint_nodes.len()],
        };
        if ibms.len() != joint_nodes.len() {
            return Err("skin inverseBindMatrices count does not match joints".into());
        }
        // Bind pose in mesh space = inverse(IBM). Parent = the joint whose node
        // is this node's parent, if that parent is itself a joint.
        let node_to_joint: std::collections::HashMap<usize, usize> =
            joint_nodes.iter().enumerate().map(|(j, n)| (n.index(), j)).collect();
        let mut raw: Vec<(Option<usize>, Bone)> = Vec::with_capacity(joint_nodes.len());
        let mut used_names = std::collections::HashSet::new();
        for (j, node) in joint_nodes.iter().enumerate() {
            let bind = mat_inverse(&ibms[j]).ok_or_else(|| format!("joint {j} has a singular inverseBindMatrix"))?;
            let parent = parents.get(node.index()).copied().flatten().and_then(|p| node_to_joint.get(&p).copied());
            let mut name = node.name().map(str::to_string).unwrap_or_else(|| format!("Bone{j}"));
            if name.len() > 100 { name.truncate(100); }
            let mut candidate = name.clone();
            let mut n = 2;
            while !used_names.insert(candidate.clone()) {
                candidate = format!("{name}_{n}");
                n += 1;
            }
            raw.push((parent, Bone { name: candidate, parent: None, cframe: cframe_from_mat(&bind), is_virtual: false }));
        }
        // Order parents before children; remap joint indices accordingly.
        let mut order: Vec<usize> = Vec::with_capacity(raw.len());
        let mut placed = vec![false; raw.len()];
        while order.len() < raw.len() {
            let before = order.len();
            for j in 0..raw.len() {
                if placed[j] { continue; }
                let ready = match raw[j].0 { None => true, Some(p) => placed[p] };
                if ready { placed[j] = true; order.push(j); }
            }
            if order.len() == before { return Err("skin joint hierarchy contains a cycle".into()); }
        }
        let mut new_index = vec![0u32; raw.len()];
        for (new, old) in order.iter().enumerate() { new_index[*old] = new as u32; }
        for old in &order {
            let (parent, mut bone) = raw[*old].clone();
            bone.parent = parent.map(|p| new_index[p]);
            mesh.bones.push(bone);
        }
        if all_skinned && joints.len() == mesh.positions.len() {
            let mut js = Vec::with_capacity(joints.len());
            let mut ws = Vec::with_capacity(joints.len());
            for (j4, w4) in joints.iter().zip(weights.iter()) {
                let mut slots = [NONE; 4];
                let mut wts = [0f32; 4];
                for k in 0..4 {
                    if w4[k] > 0.0 {
                        let old = j4[k] as usize;
                        if old >= raw.len() { return Err(format!("JOINTS_0 references joint {old}, skin has {}", raw.len())); }
                        slots[k] = new_index[old];
                        wts[k] = w4[k];
                    }
                }
                js.push(slots);
                ws.push(wts);
            }
            mesh.joints = Some(js);
            mesh.weights = Some(ws);
        }
    }
    Ok(mesh)
}

// ---------------------------------------------------------------------------
// glTF write
// ---------------------------------------------------------------------------

struct BinBuilder {
    data: Vec<u8>,
    views: Vec<serde_json::Value>,
    accessors: Vec<serde_json::Value>,
}

impl BinBuilder {
    fn view(&mut self, bytes: &[u8], target: Option<u32>) -> usize {
        while self.data.len() % 4 != 0 { self.data.push(0); }
        let mut v = serde_json::json!({ "buffer": 0, "byteOffset": self.data.len(), "byteLength": bytes.len() });
        if let Some(t) = target { v["target"] = serde_json::json!(t); }
        self.data.extend_from_slice(bytes);
        self.views.push(v);
        self.views.len() - 1
    }
    fn accessor(&mut self, view: usize, component_type: u32, count: usize, ty: &str, min: Option<Vec<f32>>, max: Option<Vec<f32>>) -> usize {
        let mut a = serde_json::json!({ "bufferView": view, "componentType": component_type, "count": count, "type": ty });
        if let Some(m) = min { a["min"] = serde_json::json!(m); }
        if let Some(m) = max { a["max"] = serde_json::json!(m); }
        self.accessors.push(a);
        self.accessors.len() - 1
    }
}

fn f32s_bytes<const N: usize>(v: &[[f32; N]]) -> Vec<u8> {
    let mut out = Vec::with_capacity(v.len() * N * 4);
    for a in v { for c in a { out.extend_from_slice(&c.to_le_bytes()); } }
    out
}

/// Write `mesh` as glTF 2.0: `.glb` (binary container) or `.gltf` (JSON with
/// the buffer embedded as a data URI). One mesh, one primitive; bones become a
/// node hierarchy plus a skin with inverse bind matrices.
pub fn write_gltf(mesh: &MeshData, path: &str) -> Result<(), String> {
    use base64::Engine;

    let lower = path.to_lowercase();
    let binary = if lower.ends_with(".glb") { true } else if lower.ends_with(".gltf") { false } else {
        return Err(format!("only .glb or .gltf output is supported (got '{path}')"));
    };
    let vcount = mesh.positions.len();
    if vcount == 0 || mesh.indices.is_empty() { return Err("mesh has no triangles".into()); }
    if mesh.bones.len() > u16::MAX as usize { return Err(format!("{} bones exceed glTF's 65535 joint limit", mesh.bones.len())); }

    let mut bin = BinBuilder { data: Vec::new(), views: Vec::new(), accessors: Vec::new() };
    let mut attributes = serde_json::Map::new();

    let mut min = [f32::MAX; 3];
    let mut max = [f32::MIN; 3];
    for p in &mesh.positions { for k in 0..3 { min[k] = min[k].min(p[k]); max[k] = max[k].max(p[k]); } }
    let v = bin.view(&f32s_bytes(&mesh.positions), Some(34962));
    let a = bin.accessor(v, 5126, vcount, "VEC3", Some(min.to_vec()), Some(max.to_vec()));
    attributes.insert("POSITION".into(), serde_json::json!(a));

    if let Some(n) = &mesh.normals {
        let v = bin.view(&f32s_bytes(n), Some(34962));
        let a = bin.accessor(v, 5126, vcount, "VEC3", None, None);
        attributes.insert("NORMAL".into(), serde_json::json!(a));
    }
    if let Some(u) = &mesh.uvs {
        let v = bin.view(&f32s_bytes(u), Some(34962));
        let a = bin.accessor(v, 5126, vcount, "VEC2", None, None);
        attributes.insert("TEXCOORD_0".into(), serde_json::json!(a));
    }
    if let Some(c) = &mesh.colors {
        let v = bin.view(&f32s_bytes(c), Some(34962));
        let a = bin.accessor(v, 5126, vcount, "VEC4", None, None);
        attributes.insert("COLOR_0".into(), serde_json::json!(a));
    }
    let skinned = !mesh.bones.is_empty() && mesh.joints.is_some() && mesh.weights.is_some();
    if skinned {
        let mut jbytes = Vec::with_capacity(vcount * 8);
        for slots in mesh.joints.as_ref().unwrap() {
            for s in slots { jbytes.extend_from_slice(&(if *s == NONE { 0u16 } else { *s as u16 }).to_le_bytes()); }
        }
        let v = bin.view(&jbytes, Some(34962));
        let a = bin.accessor(v, 5123, vcount, "VEC4", None, None);
        attributes.insert("JOINTS_0".into(), serde_json::json!(a));
        let v = bin.view(&f32s_bytes(mesh.weights.as_ref().unwrap()), Some(34962));
        let a = bin.accessor(v, 5126, vcount, "VEC4", None, None);
        attributes.insert("WEIGHTS_0".into(), serde_json::json!(a));
    }

    let mut ibytes = Vec::with_capacity(mesh.indices.len() * 4);
    for i in &mesh.indices { ibytes.extend_from_slice(&i.to_le_bytes()); }
    let v = bin.view(&ibytes, Some(34963));
    let indices_accessor = bin.accessor(v, 5125, mesh.indices.len(), "SCALAR", None, None);

    // Nodes: 0 = mesh node, then one per bone (bone i -> node i + 1).
    let mut nodes = vec![serde_json::json!({ "name": "Mesh", "mesh": 0 })];
    let mut scene_roots = vec![0usize];
    let mut skins = Vec::new();
    if !mesh.bones.is_empty() {
        let binds: Vec<Mat4> = mesh.bones.iter().map(|b| mat_from_cframe(&b.cframe)).collect();
        let mut children: Vec<Vec<usize>> = vec![Vec::new(); mesh.bones.len()];
        let mut roots = Vec::new();
        for (i, b) in mesh.bones.iter().enumerate() {
            match b.parent {
                Some(p) => children[p as usize].push(i + 1),
                None => roots.push(i + 1),
            }
        }
        for (i, b) in mesh.bones.iter().enumerate() {
            let local = match b.parent {
                Some(p) => mat_mul(&mat_inverse(&binds[p as usize]).ok_or_else(|| format!("bone '{}' has a singular bind pose", mesh.bones[p as usize].name))?, &binds[i]),
                None => binds[i],
            };
            let q = quat_from_mat(&local);
            let mut node = serde_json::json!({
                "name": b.name,
                "translation": [local[3][0], local[3][1], local[3][2]],
                "rotation": q,
            });
            if !children[i].is_empty() { node["children"] = serde_json::json!(children[i]); }
            if b.is_virtual { node["extras"] = serde_json::json!({ "rodeoVirtualBone": true }); }
            nodes.push(node);
        }
        scene_roots.extend(roots.iter().copied());
        if skinned {
            let ibms: Vec<Mat4> = binds.iter().enumerate().map(|(i, b)| mat_inverse(b).ok_or_else(|| format!("bone '{}' has a singular bind pose", mesh.bones[i].name))).collect::<Result<_, _>>()?;
            let mut mbytes = Vec::with_capacity(ibms.len() * 64);
            for m in &ibms { for col in m { for c in col { mbytes.extend_from_slice(&c.to_le_bytes()); } } }
            let v = bin.view(&mbytes, None);
            let a = bin.accessor(v, 5126, ibms.len(), "MAT4", None, None);
            let joints: Vec<usize> = (0..mesh.bones.len()).map(|i| i + 1).collect();
            let mut skin = serde_json::json!({ "joints": joints, "inverseBindMatrices": a });
            if let Some(r) = roots.first() { skin["skeleton"] = serde_json::json!(r); }
            skins.push(skin);
            nodes[0]["skin"] = serde_json::json!(0);
        }
    }

    let mut root = serde_json::json!({
        "asset": { "version": "2.0", "generator": "rodeo" },
        "scene": 0,
        "scenes": [{ "nodes": scene_roots }],
        "nodes": nodes,
        "meshes": [{ "name": "Mesh", "primitives": [{ "attributes": attributes, "indices": indices_accessor, "mode": 4 }] }],
        "bufferViews": bin.views,
        "accessors": bin.accessors,
    });
    if !skins.is_empty() { root["skins"] = serde_json::json!(skins); }

    while bin.data.len() % 4 != 0 { bin.data.push(0); }
    let output_bytes = if binary {
        root["buffers"] = serde_json::json!([{ "byteLength": bin.data.len() }]);
        let mut json = serde_json::to_vec(&root).map_err(|e| format!("glTF json: {e}"))?;
        while json.len() % 4 != 0 { json.push(b' '); }
        let total = 12 + 8 + json.len() + 8 + bin.data.len();
        let mut out = Vec::with_capacity(total);
        out.extend_from_slice(&0x4654_6C67u32.to_le_bytes());
        out.extend_from_slice(&2u32.to_le_bytes());
        out.extend_from_slice(&(total as u32).to_le_bytes());
        out.extend_from_slice(&(json.len() as u32).to_le_bytes());
        out.extend_from_slice(&0x4E4F_534Au32.to_le_bytes());
        out.extend_from_slice(&json);
        out.extend_from_slice(&(bin.data.len() as u32).to_le_bytes());
        out.extend_from_slice(&0x004E_4942u32.to_le_bytes());
        out.extend_from_slice(&bin.data);
        out
    } else {
        let uri = format!("data:application/octet-stream;base64,{}", base64::engine::general_purpose::STANDARD.encode(&bin.data));
        root["buffers"] = serde_json::json!([{ "byteLength": bin.data.len(), "uri": uri }]);
        serde_json::to_vec_pretty(&root).map_err(|e| format!("glTF json: {e}"))?
    };

    if let Some(parent) = std::path::Path::new(path).parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent).map_err(|e| format!("create parent dirs for {}: {e}", parent.display()))?;
        }
    }
    let tmp = format!("{path}.tmp");
    std::fs::write(&tmp, &output_bytes).map_err(|e| format!("write {tmp}: {e}"))?;
    std::fs::rename(&tmp, path).map_err(|e| {
        let _ = std::fs::remove_file(&tmp);
        format!("rename {tmp} -> {path}: {e}")
    })?;
    Ok(())
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Wavefront OBJ. Same per-vertex `MeshData` as glTF, so the plugin side and the
// interchange blob are untouched; only the file codec differs.
//
// OBJ carries no units or handedness. Blender and the common exporters write
// Y-up, right-handed, CCW files, which is Roblox's frame, so positions and
// winding pass through unchanged and one unit is one stud. The one conversion
// is UV V: OBJ's `vt` origin is bottom-left, Roblox's (and glTF's) top-left,
// so V is flipped both ways. Faces index positions, UVs and normals
// independently, which is EditableMesh's per-corner model: the reader splits
// corners into unique (v, vt, vn) tuples, so UV seams and hard edges survive,
// and the writer emits one tuple per vertex since the plugin already split
// corners on export. Polygons are fan-triangulated. `o`/`g` groups merge into
// the one mesh; `mtllib`, `usemtl`, `s`, lines and points are ignored. OBJ has
// no vertex colors or skinning: export drops them and says so.
// ---------------------------------------------------------------------------

pub fn read_obj(path: &str) -> Result<MeshData, String> {
    let text = std::fs::read_to_string(path).map_err(|e| format!("read {path}: {e}"))?;
    parse_obj(&text).map_err(|e| format!("{path}: {e}"))
}

/// A face corner as 0-based indices into the file's v / vt / vn lists.
type Corner = (u32, Option<u32>, Option<u32>);

fn parse_obj(text: &str) -> Result<MeshData, String> {
    let mut positions: Vec<[f32; 3]> = Vec::new();
    let mut uvs: Vec<[f32; 2]> = Vec::new();
    let mut normals: Vec<[f32; 3]> = Vec::new();
    let mut corners: Vec<Corner> = Vec::new();
    for (i, raw) in text.lines().enumerate() {
        let line_no = i + 1;
        let line = raw.split('#').next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        let mut parts = line.split_whitespace();
        let key = parts.next().unwrap_or("");
        let rest: Vec<&str> = parts.collect();
        match key {
            "v" => positions.push(parse_floats::<3>(&rest, "v", line_no)?),
            "vt" => {
                // `vt u [v [w]]`: v defaults to 0; extra components are ignored.
                let uv = parse_floats::<1>(&rest, "vt", line_no)?;
                let v = rest.get(1).map(|s| parse_float(s, "vt", line_no)).transpose()?.unwrap_or(0.0);
                uvs.push([uv[0], 1.0 - v]);
            }
            "vn" => normals.push(parse_floats::<3>(&rest, "vn", line_no)?),
            "f" => {
                if rest.len() < 3 {
                    return Err(format!("line {line_no}: face with {} corner(s); a face needs at least 3", rest.len()));
                }
                let mut polygon = Vec::with_capacity(rest.len());
                for token in &rest {
                    polygon.push(parse_corner(token, positions.len(), uvs.len(), normals.len(), line_no)?);
                }
                for k in 1..polygon.len() - 1 {
                    corners.push(polygon[0]);
                    corners.push(polygon[k]);
                    corners.push(polygon[k + 1]);
                }
            }
            // Groups merge into the one mesh; materials, smoothing groups,
            // lines, points and anything unknown are ignored.
            _ => {}
        }
    }
    if corners.is_empty() {
        return Err("no faces found".to_string());
    }
    // An attribute is kept only when every corner carries it, as the glTF
    // importer does across primitives; a partial set would leave holes.
    let all_uvs = corners.iter().all(|c| c.1.is_some());
    let all_normals = corners.iter().all(|c| c.2.is_some());
    let mut mesh = MeshData {
        normals: if all_normals { Some(Vec::new()) } else { None },
        uvs: if all_uvs { Some(Vec::new()) } else { None },
        indices: Vec::with_capacity(corners.len()),
        ..Default::default()
    };
    let mut seen: std::collections::HashMap<Corner, u32> = std::collections::HashMap::new();
    for corner in corners {
        let key: Corner = (corner.0, if all_uvs { corner.1 } else { None }, if all_normals { corner.2 } else { None });
        let index = match seen.get(&key) {
            Some(&index) => index,
            None => {
                mesh.positions.push(positions[key.0 as usize]);
                if let (Some(out), Some(vt)) = (mesh.uvs.as_mut(), key.1) {
                    out.push(uvs[vt as usize]);
                }
                if let (Some(out), Some(vn)) = (mesh.normals.as_mut(), key.2) {
                    out.push(normals[vn as usize]);
                }
                let index = (mesh.positions.len() - 1) as u32;
                seen.insert(key, index);
                index
            }
        };
        mesh.indices.push(index);
    }
    Ok(mesh)
}

fn parse_float(s: &str, key: &str, line_no: usize) -> Result<f32, String> {
    s.parse::<f32>().map_err(|_| format!("line {line_no}: '{key}' component '{s}' is not a number"))
}

/// The first N components of a `v`/`vt`/`vn` line; extra ones (a `w`, or the
/// nonstandard vertex colors some exporters append) are ignored.
fn parse_floats<const N: usize>(rest: &[&str], key: &str, line_no: usize) -> Result<[f32; N], String> {
    if rest.len() < N {
        return Err(format!("line {line_no}: '{key}' has {} component(s); {N} are needed", rest.len()));
    }
    let mut out = [0.0f32; N];
    for (slot, s) in out.iter_mut().zip(rest) {
        *slot = parse_float(s, key, line_no)?;
    }
    Ok(out)
}

/// Resolve one OBJ index: 1-based, or negative counting back from the items
/// defined so far. `count` is that number of items.
fn resolve_index(s: &str, count: usize, what: &str, line_no: usize) -> Result<u32, String> {
    let n: i64 = s.parse().map_err(|_| format!("line {line_no}: face corner '{s}' is not a {what} index"))?;
    let index = if n > 0 {
        n - 1
    } else if n < 0 {
        count as i64 + n
    } else {
        return Err(format!("line {line_no}: {what} index 0 is not valid (OBJ indices start at 1)"));
    };
    if index < 0 || index >= count as i64 {
        return Err(format!("line {line_no}: {what} index {n} is out of range ({count} defined so far)"));
    }
    Ok(index as u32)
}

/// One face corner: `v`, `v/vt`, `v//vn` or `v/vt/vn`.
fn parse_corner(token: &str, nv: usize, nvt: usize, nvn: usize, line_no: usize) -> Result<Corner, String> {
    let fields: Vec<&str> = token.split('/').collect();
    if fields.len() > 3 || fields[0].is_empty() {
        return Err(format!("line {line_no}: face corner '{token}' is not v, v/vt, v//vn or v/vt/vn"));
    }
    let v = resolve_index(fields[0], nv, "vertex", line_no)?;
    let vt = match fields.get(1) {
        Some(s) if !s.is_empty() => Some(resolve_index(s, nvt, "texture coordinate", line_no)?),
        _ => None,
    };
    let vn = match fields.get(2) {
        Some(s) if !s.is_empty() => Some(resolve_index(s, nvn, "normal", line_no)?),
        _ => None,
    };
    Ok((v, vt, vn))
}

/// Write `mesh` as OBJ. Returns the features OBJ cannot carry that the mesh
/// had, so the caller can be told: vertex colors, and skinning.
pub fn write_obj(mesh: &MeshData, path: &str) -> Result<Vec<String>, String> {
    use std::fmt::Write as _;
    if mesh.indices.len() % 3 != 0 {
        return Err(format!("{} indices is not a whole number of triangles", mesh.indices.len()));
    }
    let mut dropped = Vec::new();
    if mesh.colors.is_some() {
        dropped.push("vertex colors".to_string());
    }
    if !mesh.bones.is_empty() || mesh.joints.is_some() {
        dropped.push("skinning (bones and vertex weights)".to_string());
    }
    let mut out = String::new();
    out.push_str("# rodeo roblox.exportEditableMesh: studs, Y-up, right-handed, CCW; vt V flipped from Roblox's top-left origin\n");
    out.push_str("o mesh\n");
    for p in &mesh.positions {
        let _ = writeln!(out, "v {} {} {}", p[0], p[1], p[2]);
    }
    if let Some(uvs) = &mesh.uvs {
        for uv in uvs {
            let _ = writeln!(out, "vt {} {}", uv[0], 1.0 - uv[1]);
        }
    }
    if let Some(normals) = &mesh.normals {
        for n in normals {
            let _ = writeln!(out, "vn {} {} {}", n[0], n[1], n[2]);
        }
    }
    let (has_uv, has_n) = (mesh.uvs.is_some(), mesh.normals.is_some());
    for tri in mesh.indices.chunks_exact(3) {
        out.push('f');
        for &i in tri {
            let k = i + 1;
            match (has_uv, has_n) {
                (true, true) => { let _ = write!(out, " {k}/{k}/{k}"); }
                (true, false) => { let _ = write!(out, " {k}/{k}"); }
                (false, true) => { let _ = write!(out, " {k}//{k}"); }
                (false, false) => { let _ = write!(out, " {k}"); }
            }
        }
        out.push('\n');
    }
    write_atomic(path, out.as_bytes())?;
    Ok(dropped)
}

/// `.tmp` + rename, creating parent directories, so a failed export leaves no
/// partial file.
fn write_atomic(path: &str, bytes: &[u8]) -> Result<(), String> {
    if let Some(parent) = std::path::Path::new(path).parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent).map_err(|e| format!("create parent dirs for {}: {e}", parent.display()))?;
        }
    }
    let tmp = format!("{path}.tmp");
    std::fs::write(&tmp, bytes).map_err(|e| format!("write {tmp}: {e}"))?;
    std::fs::rename(&tmp, path).map_err(|e| {
        let _ = std::fs::remove_file(&tmp);
        format!("rename {tmp} -> {path}: {e}")
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn close(a: f32, b: f32) -> bool { (a - b).abs() < 1e-4 }

    fn sample(skinned: bool) -> MeshData {
        // A unit quad as two CCW triangles, one attribute of each kind.
        let mut m = MeshData {
            positions: vec![[0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [1.0, 1.0, 0.0], [0.0, 1.0, 0.0]],
            normals: Some(vec![[0.0, 0.0, 1.0]; 4]),
            uvs: Some(vec![[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]),
            colors: Some(vec![[1.0, 0.0, 0.0, 1.0], [0.0, 1.0, 0.0, 0.5], [0.0, 0.0, 1.0, 1.0], [1.0, 1.0, 1.0, 0.25]]),
            indices: vec![0, 1, 2, 0, 2, 3],
            ..Default::default()
        };
        if skinned {
            // Root at origin, child translated up 1 and rotated 90 degrees about Y.
            m.bones = vec![
                Bone { name: "Root".into(), parent: None, cframe: [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], is_virtual: false },
                Bone { name: "Child".into(), parent: Some(0), cframe: [0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 0.0], is_virtual: true },
            ];
            m.joints = Some(vec![[0, NONE, NONE, NONE], [0, 1, NONE, NONE], [1, NONE, NONE, NONE], [0, 1, NONE, NONE]]);
            m.weights = Some(vec![[1.0, 0.0, 0.0, 0.0], [0.5, 0.5, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0], [0.25, 0.75, 0.0, 0.0]]);
        }
        m
    }

    fn assert_geometry_eq(a: &MeshData, b: &MeshData) {
        assert_eq!(a.positions.len(), b.positions.len());
        for (p, q) in a.positions.iter().zip(&b.positions) { for k in 0..3 { assert!(close(p[k], q[k]), "position {p:?} vs {q:?}"); } }
        assert_eq!(a.indices, b.indices);
        match (&a.normals, &b.normals) {
            (Some(x), Some(y)) => for (p, q) in x.iter().zip(y) { for k in 0..3 { assert!(close(p[k], q[k]), "normal {p:?} vs {q:?}"); } },
            (None, None) => {}
            _ => panic!("normals presence differs"),
        }
        assert_eq!(a.uvs.is_some(), b.uvs.is_some());
        if let (Some(x), Some(y)) = (&a.uvs, &b.uvs) { for (p, q) in x.iter().zip(y) { for k in 0..2 { assert!(close(p[k], q[k])); } } }
        assert_eq!(a.colors.is_some(), b.colors.is_some());
        if let (Some(x), Some(y)) = (&a.colors, &b.colors) { for (p, q) in x.iter().zip(y) { for k in 0..4 { assert!(close(p[k], q[k]), "color {p:?} vs {q:?}"); } } }
    }

    fn scratch(name: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("rodeo-mesh-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn blob_round_trips_including_skin() {
        let m = sample(true);
        let back = decode_blob(&encode_blob(&m)).expect("decode");
        assert_eq!(back, m);
    }

    #[test]
    fn blob_rejects_child_before_parent() {
        let mut m = sample(true);
        m.bones.swap(0, 1);
        m.bones[0].parent = Some(1);
        m.bones[1].parent = None;
        let err = decode_blob(&encode_blob(&m)).expect_err("bad order");
        assert!(err.contains("parents must precede children"), "{err}");
    }

    #[test]
    fn glb_round_trips_geometry_and_skin() {
        let dir = scratch("glb");
        let path = dir.join("nested").join("mesh.glb");
        let m = sample(true);
        write_gltf(&m, &path.to_string_lossy()).expect("write glb");
        let head = std::fs::read(&path).unwrap();
        assert_eq!(&head[..4], b"glTF");
        let back = read_gltf(&path.to_string_lossy()).expect("read glb");
        assert_geometry_eq(&m, &back);
        assert_eq!(back.bones.len(), 2);
        assert_eq!(back.bones[0].name, "Root");
        assert_eq!(back.bones[1].name, "Child");
        assert_eq!(back.bones[1].parent, Some(0));
        for k in 0..12 { assert!(close(back.bones[1].cframe[k], m.bones[1].cframe[k]), "bind cframe component {k}: {} vs {}", back.bones[1].cframe[k], m.bones[1].cframe[k]); }
        assert_eq!(back.joints.as_ref().unwrap()[1], [0, 1, NONE, NONE]);
        let w = back.weights.as_ref().unwrap()[3];
        assert!(close(w[0], 0.25) && close(w[1], 0.75), "{w:?}");
    }

    #[test]
    fn gltf_text_round_trips_unskinned() {
        let dir = scratch("gltf");
        let path = dir.join("mesh.gltf");
        let m = sample(false);
        write_gltf(&m, &path.to_string_lossy()).expect("write gltf");
        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("data:application/octet-stream;base64,"));
        let back = read_gltf(&path.to_string_lossy()).expect("read gltf");
        assert_geometry_eq(&m, &back);
        assert!(back.bones.is_empty() && back.joints.is_none());
    }

    #[test]
    fn node_transform_is_baked_into_unskinned_geometry() {
        // Hand-written glTF: one triangle under a node translated by (10, 0, 0).
        let dir = scratch("baked");
        let path = dir.join("t.gltf");
        let positions: Vec<[f32; 3]> = vec![[0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0]];
        let normals: Vec<[f32; 3]> = vec![[0.0, 0.0, 1.0]; 3];
        let mut bin = f32s_bytes(&positions);
        bin.extend(f32s_bytes(&normals));
        for i in [0u32, 1, 2] { bin.extend_from_slice(&i.to_le_bytes()); }
        use base64::Engine;
        let json = serde_json::json!({
            "asset": {"version": "2.0"}, "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": [{"mesh": 0, "translation": [10.0, 0.0, 0.0]}],
            "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2}]}],
            "buffers": [{"byteLength": bin.len(), "uri": format!("data:application/octet-stream;base64,{}", base64::engine::general_purpose::STANDARD.encode(&bin))}],
            "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 36}, {"buffer": 0, "byteOffset": 36, "byteLength": 36}, {"buffer": 0, "byteOffset": 72, "byteLength": 12}],
            "accessors": [
                {"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3", "min": [0.0,0.0,0.0], "max": [1.0,1.0,0.0]},
                {"bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC3"},
                {"bufferView": 2, "componentType": 5125, "count": 3, "type": "SCALAR"}
            ]
        });
        std::fs::write(&path, serde_json::to_vec(&json).unwrap()).unwrap();
        let m = read_gltf(&path.to_string_lossy()).expect("read");
        assert!(close(m.positions[1][0], 11.0), "{:?}", m.positions);
        assert!(close(m.normals.as_ref().unwrap()[0][2], 1.0));
    }

    #[test]
    fn unsupported_extension_and_missing_file_error_clearly() {
        let err = write_mesh(&sample(false), "/tmp/rodeo-mesh.stl").expect_err("stl");
        assert!(err.contains(".glb") && err.contains(".gltf") && err.contains(".obj"), "{err}");
        let err = read_gltf("/definitely/not/here.glb").expect_err("missing");
        assert!(err.contains("not/here.glb"), "{err}");
    }

    #[test]
    fn matrix_inverse_and_cframe_conversions_agree() {
        let bone = sample(true).bones[1].clone();
        let m = mat_from_cframe(&bone.cframe);
        let back = cframe_from_mat(&m);
        for k in 0..12 { assert!(close(back[k], bone.cframe[k])); }
        let inv = mat_inverse(&m).unwrap();
        let id = mat_mul(&m, &inv);
        for c in 0..4 { for r in 0..4 { assert!(close(id[c][r], IDENTITY[c][r]), "{id:?}"); } }
    }

    #[test]
    fn obj_round_trip_keeps_geometry_uvs_normals_and_reports_drops() {
        let dir = scratch("obj-roundtrip");
        let path = dir.join("nested").join("quad.obj");
        let dropped = write_obj(&sample(true), path.to_str().unwrap()).unwrap();
        assert_eq!(dropped, vec!["vertex colors".to_string(), "skinning (bones and vertex weights)".to_string()]);
        let back = read_obj(path.to_str().unwrap()).unwrap();
        let src = sample(false);
        assert_eq!(back.positions, src.positions);
        assert_eq!(back.uvs, src.uvs, "V flips out and back in");
        assert_eq!(back.normals, src.normals);
        assert_eq!(back.indices, src.indices);
        assert!(back.colors.is_none() && back.bones.is_empty());
        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("vt 1 0\n"), "Roblox (1,1) is OBJ's (1,0): {text}");
        let mut plain = sample(false);
        plain.colors = None;
        assert!(write_obj(&plain, path.to_str().unwrap()).unwrap().is_empty());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn obj_face_forms_negative_indices_polygons_and_groups() {
        let text = "mtllib scene.mtl\no first\nusemtl red\n\
            v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\n\
            vt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\n\
            vn 0 0 1\n\
            f 1/1/1 2/2/1 3/3/1 4/4/1  # a quad: two triangles\n\
            g second\ns 1\n\
            f -4/-4/-1 -3/-3/-1 -2/-2/-1\n";
        let mesh = parse_obj(text).unwrap();
        assert_eq!(mesh.indices.len(), 9, "quad fan-triangulated plus one triangle");
        assert_eq!(mesh.positions.len(), 4, "corners with the same v/vt/vn share a vertex");
        assert_eq!(mesh.uvs.as_ref().unwrap()[2], [1.0, 0.0], "vt 1 1 becomes Roblox (1,0)");
        assert_eq!(mesh.normals.as_ref().unwrap().len(), 4);

        // Mixed forms: an attribute missing on any corner is dropped everywhere.
        let mixed = "v 0 0 0\nv 1 0 0\nv 0 1 0\nvt 0 0\nvn 0 0 1\nf 1/1/1 2/1/1 3/1/1\nf 1 2 3\nf 1//1 2//1 3//1\n";
        let mesh = parse_obj(mixed).unwrap();
        assert!(mesh.uvs.is_none() && mesh.normals.is_none());
        assert_eq!(mesh.indices.len(), 9);
        assert_eq!(mesh.positions.len(), 3);
    }

    #[test]
    fn obj_errors_name_the_line() {
        let cases = [
            ("v 0 0 0\nv 1 0 0\nf 1 2\n", "line 3", "corner(s)"),
            ("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 9\n", "line 4", "out of range"),
            ("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 x\n", "line 4", "not a vertex index"),
            ("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 0 1 2\n", "line 4", "start at 1"),
            ("v 0 0\n", "line 1", "component(s)"),
            ("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1/1 2/1 3/1\n", "line 4", "texture coordinate index 1 is out of range"),
            ("# nothing\n", "no faces", ""),
        ];
        for (text, a, b) in cases {
            let err = parse_obj(text).expect_err(text);
            assert!(err.contains(a) && err.contains(b), "{text:?} -> {err}");
        }
    }
}
