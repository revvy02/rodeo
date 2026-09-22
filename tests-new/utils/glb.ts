// Minimal glTF 2.0 binary writer for test fixtures: one node, one mesh, one
// indexed triangle-list primitive with positions only. Lets a test build
// inputs an EditableMesh could never produce, such as a primitive past the
// engine's per-mesh vertex cap.
import { writeFileSync } from "node:fs";

export function writeMinimalGlb(path: string, vertexCount: number, triangleCount: number): void {
  const positions = new Float32Array(vertexCount * 3);
  for (let i = 0; i < vertexCount; i++) {
    positions[i * 3] = i % 256;
    positions[i * 3 + 1] = 0;
    positions[i * 3 + 2] = Math.floor(i / 256);
  }
  const indices = new Uint32Array(triangleCount * 3);
  for (let t = 0; t < triangleCount; t++) {
    indices[t * 3] = (t * 3) % vertexCount;
    indices[t * 3 + 1] = (t * 3 + 1) % vertexCount;
    indices[t * 3 + 2] = (t * 3 + 2) % vertexCount;
  }
  const positionBytes = Buffer.from(positions.buffer);
  const indexBytes = Buffer.from(indices.buffer);
  const bin = Buffer.concat([positionBytes, indexBytes]);
  const json = JSON.stringify({
    asset: { version: "2.0", generator: "rodeo tests" },
    buffers: [{ byteLength: bin.length }],
    bufferViews: [
      { buffer: 0, byteOffset: 0, byteLength: positionBytes.length, target: 34962 },
      { buffer: 0, byteOffset: positionBytes.length, byteLength: indexBytes.length, target: 34963 },
    ],
    accessors: [
      { bufferView: 0, componentType: 5126, count: vertexCount, type: "VEC3", min: [0, 0, 0], max: [255, 0, Math.floor((vertexCount - 1) / 256)] },
      { bufferView: 1, componentType: 5125, count: triangleCount * 3, type: "SCALAR" },
    ],
    meshes: [{ primitives: [{ attributes: { POSITION: 0 }, indices: 1, mode: 4 }] }],
    nodes: [{ mesh: 0 }],
    scenes: [{ nodes: [0] }],
    scene: 0,
  });
  const pad4 = (n: number) => (4 - (n % 4)) % 4;
  const jsonChunk = Buffer.concat([Buffer.from(json, "utf8"), Buffer.alloc(pad4(Buffer.byteLength(json)), 0x20)]);
  const binChunk = Buffer.concat([bin, Buffer.alloc(pad4(bin.length), 0)]);
  const header = Buffer.alloc(12);
  header.write("glTF", 0, "latin1");
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + jsonChunk.length + 8 + binChunk.length, 8);
  const chunkHeader = (length: number, type: number) => {
    const h = Buffer.alloc(8);
    h.writeUInt32LE(length, 0);
    h.writeUInt32LE(type, 4);
    return h;
  };
  writeFileSync(path, Buffer.concat([header, chunkHeader(jsonChunk.length, 0x4e4f534a), jsonChunk, chunkHeader(binChunk.length, 0x004e4942), binChunk]));
}
