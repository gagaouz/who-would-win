import sharp, { Metadata, OverlayOptions } from 'sharp';
import { createHash } from 'crypto';
import { MAX_PNG_BYTES } from './config';
import { FighterManifest, POSES, ProviderError } from './types';

const SIGNATURE = Buffer.from([137,80,78,71,13,10,26,10]);
export const sha256 = (bytes: Buffer): string => createHash('sha256').update(bytes).digest('hex');

/** Bounded decode followed by one family-wide scale. It never redraws or invents a pose. */
export async function validateAndPackSheet(original: Buffer, assetID: string, archetype = 'biped'):
Promise<{ original: Buffer; runtime: Buffer; manifest: FighterManifest; poses: Buffer[] }> {
  if (original.length > MAX_PNG_BYTES || !original.subarray(0, 8).equals(SIGNATURE)) reject();
  const image = sharp(original, { limitInputPixels: 4_194_304, failOn: 'warning' });
  let metadata: Metadata;
  try { metadata = await image.metadata(); } catch { return reject(); }
  if (metadata.format !== 'png' || !metadata.hasAlpha || metadata.width !== 1024 || metadata.height !== 1024
      || (metadata.pages ?? 1) !== 1) reject();
  const { data, info } = await image.ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  if (info.channels !== 4) reject();
  const bounds: Array<{ left: number; top: number; width: number; height: number }> = [];
  const normalizedDigests = new Set<string>();
  for (let pose = 0; pose < 4; pose++) {
    const originX = (pose % 2) * 512, originY = Math.floor(pose / 2) * 512;
    let minX = 512, minY = 512, maxX = -1, maxY = -1, visible = 0, transparent = 0;
    for (let y = 0; y < 512; y++) for (let x = 0; x < 512; x++) {
      const alpha = data[((originY + y) * 1024 + originX + x) * 4 + 3];
      if (alpha <= 8) transparent++;
      if (alpha > 16) { visible++; minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
    }
    // Reject blank, opaque, clipped or postage-stamp cells. Real transparent margin on every edge.
    if (visible < 1024 || transparent < 512 * 512 * 0.35 || minX < 12 || minY < 12 || maxX > 499 || maxY > 499) reject();
    const bound = { left: originX + minX, top: originY + minY, width: maxX - minX + 1, height: maxY - minY + 1 };
    bounds.push(bound);
    const silhouette = await sharp(original, { limitInputPixels: 4_194_304 }).extract(bound)
      .resize(96, 96, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 }, kernel: 'nearest' }).png().toBuffer();
    normalizedDigests.add(sha256(silhouette));
  }
  if (normalizedDigests.size !== 4) reject();
  const extent = Math.max(...bounds.map(bound => Math.max(bound.width, bound.height)));
  const scale = Math.min(1, 432 / extent);
  const layers: OverlayOptions[] = [], poses: Buffer[] = [];
  for (let index = 0; index < 4; index++) {
    const bound = bounds[index];
    const width = Math.max(1, Math.round(bound.width * scale)), height = Math.max(1, Math.round(bound.height * scale));
    const cropped = await sharp(original).extract(bound).resize(width, height, { kernel: 'nearest' }).png().toBuffer();
    const left = Math.floor((512 - width) / 2), top = 472 - height;
    const pose = await sharp({ create: { width: 512, height: 512, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
      .composite([{ input: cropped, left, top }]).png().toBuffer();
    poses.push(pose);
    layers.push({ input: pose, left: (index % 2) * 512, top: Math.floor(index / 2) * 512 });
  }
  const runtime = await sharp({ create: { width: 1024, height: 1024, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
    .composite(layers).png().toBuffer();
  if (runtime.length > MAX_PNG_BYTES) reject();
  await validateRuntimeSheet(runtime);
  return { original, runtime, poses, manifest: {
    schemaVersion: 1, assetID, version: 1, sha256: sha256(runtime), styleVersion: 'retro-v1', width: 1024, height: 1024, archetype,
    frames: Object.fromEntries(POSES.map((pose, index) => [pose, [(index % 2) * 512, Math.floor(index / 2) * 512, 512, 512]])) as FighterManifest['frames'],
  } };
}
/** Matches the native installer alpha/bounds/trimmed-pixel gates before consuming a customer allowance. */
export async function validateRuntimeSheet(runtime: Buffer): Promise<void> {
  const { data } = await sharp(runtime, { limitInputPixels: 4_194_304 }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const distinct = new Set<string>();
  for (let index = 0; index < 4; index++) {
    const ox = index % 2 * 512, oy = Math.floor(index / 2) * 512;
    let left = 512, top = 512, right = -1, bottom = -1, opaque = 0, transparent = 0;
    for (let y=0;y<512;y++) for (let x=0;x<512;x++) {
      const alpha = data[((oy+y)*1024+ox+x)*4+3];
      if (alpha > 8) { left=Math.min(left,x); right=Math.max(right,x); top=Math.min(top,y); bottom=Math.max(bottom,y); }
      if (alpha > 127) opaque++; if (alpha < 8) transparent++;
    }
    if (opaque <= Math.floor(512*512/33) || transparent <= Math.floor(512*512/50)
      || left < 2 || top < 2 || right >= 510 || bottom >= 510 || right < left || bottom < top) reject();
    const width = right-left+1, height = bottom-top+1;
    const rgba = Buffer.alloc(width*height*4);
    for (let y=0;y<height;y++) for (let x=0;x<width;x++) {
      const source=((oy+top+y)*1024+ox+left+x)*4, target=(y*width+x)*4, alpha=data[source+3];
      // UIImage/CGImage decodes into premultiplied RGBA; ignore hidden RGB in fully transparent pixels.
      for(let c=0;c<3;c++) rgba[target+c]=Math.round(data[source+c]*alpha/255);
      rgba[target+3]=alpha;
    }
    distinct.add(sha256(Buffer.concat([Buffer.from(`${width}x${height}:`),rgba])));
  }
  if (distinct.size !== 4) reject();
}
function reject(): never { throw new ProviderError('quality_rejected', 'The artwork did not pass the four-pose quality check.'); }
