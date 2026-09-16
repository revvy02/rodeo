// Minimal PNG decoder for test assertions: 8-bit RGB or RGBA, non-interlaced,
// filters 0-4, which is all the engine's capture files and rodeo's encoder
// write. Lets a test look at pixels without an image dependency.
import { inflateSync } from "node:zlib";

export type DecodedPng = { width: number; height: number; channels: number; pixels: Uint8Array };

export function decodePng(data: Buffer): DecodedPng {
  if (data.subarray(0, 8).toString("hex") !== "89504e470d0a1a0a") throw new Error("not a PNG");
  let width = 0;
  let height = 0;
  let channels = 0;
  const idat: Buffer[] = [];
  for (let off = 8; off < data.length; ) {
    const len = data.readUInt32BE(off);
    const kind = data.toString("ascii", off + 4, off + 8);
    const body = data.subarray(off + 8, off + 8 + len);
    if (kind === "IHDR") {
      width = body.readUInt32BE(0);
      height = body.readUInt32BE(4);
      if (body[8] !== 8) throw new Error(`unsupported bit depth ${body[8]}`);
      if (body[9] !== 2 && body[9] !== 6) throw new Error(`unsupported color type ${body[9]}`);
      if (body[12] !== 0) throw new Error("interlaced PNG unsupported");
      channels = body[9] === 6 ? 4 : 3;
    } else if (kind === "IDAT") {
      idat.push(body);
    }
    off += len + 12;
  }
  const stride = width * channels;
  const raw = inflateSync(Buffer.concat(idat));
  if (raw.length !== (stride + 1) * height) throw new Error("unexpected PNG data length");
  const pixels = new Uint8Array(stride * height);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const rowIn = y * (stride + 1) + 1;
    for (let x = 0; x < stride; x++) {
      const i = y * stride + x;
      const a = x >= channels ? pixels[i - channels] : 0;
      const b = y > 0 ? pixels[i - stride] : 0;
      const c = y > 0 && x >= channels ? pixels[i - stride - channels] : 0;
      let pred = 0;
      if (filter === 1) pred = a;
      else if (filter === 2) pred = b;
      else if (filter === 3) pred = (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c;
        const pa = Math.abs(p - a);
        const pb = Math.abs(p - b);
        const pc = Math.abs(p - c);
        pred = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      } else if (filter !== 0) throw new Error(`bad PNG filter ${filter}`);
      pixels[i] = (raw[rowIn + x] + pred) & 255;
    }
  }
  return { width, height, channels, pixels };
}

// Number of pixels whose RGB satisfies `pred`.
export function countPixels(img: DecodedPng, pred: (r: number, g: number, b: number) => boolean): number {
  let n = 0;
  for (let i = 0; i < img.pixels.length; i += img.channels) {
    if (pred(img.pixels[i], img.pixels[i + 1], img.pixels[i + 2])) n++;
  }
  return n;
}
