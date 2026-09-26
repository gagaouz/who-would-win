"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sha256 = void 0;
exports.validateAndPackSheet = validateAndPackSheet;
exports.validateRuntimeSheet = validateRuntimeSheet;
const sharp_1 = __importDefault(require("sharp"));
const crypto_1 = require("crypto");
const config_1 = require("./config");
const types_1 = require("./types");
const SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const sha256 = (bytes) => (0, crypto_1.createHash)('sha256').update(bytes).digest('hex');
exports.sha256 = sha256;
/** Bounded decode followed by one family-wide scale. It never redraws or invents a pose. */
async function validateAndPackSheet(original, assetID, archetype = 'biped') {
    if (original.length > config_1.MAX_PNG_BYTES || !original.subarray(0, 8).equals(SIGNATURE))
        reject();
    const image = (0, sharp_1.default)(original, { limitInputPixels: 4194304, failOn: 'warning' });
    let metadata;
    try {
        metadata = await image.metadata();
    }
    catch {
        return reject();
    }
    if (metadata.format !== 'png' || !metadata.hasAlpha || metadata.width !== 1024 || metadata.height !== 1024
        || (metadata.pages ?? 1) !== 1)
        reject();
    const { data, info } = await image.ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    if (info.channels !== 4)
        reject();
    const bounds = [];
    const normalizedDigests = new Set();
    for (let pose = 0; pose < 4; pose++) {
        const originX = (pose % 2) * 512, originY = Math.floor(pose / 2) * 512;
        let minX = 512, minY = 512, maxX = -1, maxY = -1, visible = 0, transparent = 0;
        for (let y = 0; y < 512; y++)
            for (let x = 0; x < 512; x++) {
                const alpha = data[((originY + y) * 1024 + originX + x) * 4 + 3];
                if (alpha <= 8)
                    transparent++;
                if (alpha > 16) {
                    visible++;
                    minX = Math.min(minX, x);
                    maxX = Math.max(maxX, x);
                    minY = Math.min(minY, y);
                    maxY = Math.max(maxY, y);
                }
            }
        // Reject blank, opaque, clipped or postage-stamp cells. Real transparent margin on every edge.
        if (visible < 1024 || transparent < 512 * 512 * 0.35 || minX < 12 || minY < 12 || maxX > 499 || maxY > 499)
            reject();
        const bound = { left: originX + minX, top: originY + minY, width: maxX - minX + 1, height: maxY - minY + 1 };
        bounds.push(bound);
        const silhouette = await (0, sharp_1.default)(original, { limitInputPixels: 4194304 }).extract(bound)
            .resize(96, 96, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 }, kernel: 'nearest' }).png().toBuffer();
        normalizedDigests.add((0, exports.sha256)(silhouette));
    }
    if (normalizedDigests.size !== 4)
        reject();
    const extent = Math.max(...bounds.map(bound => Math.max(bound.width, bound.height)));
    const scale = Math.min(1, 432 / extent);
    const layers = [], poses = [];
    for (let index = 0; index < 4; index++) {
        const bound = bounds[index];
        const width = Math.max(1, Math.round(bound.width * scale)), height = Math.max(1, Math.round(bound.height * scale));
        const cropped = await (0, sharp_1.default)(original).extract(bound).resize(width, height, { kernel: 'nearest' }).png().toBuffer();
        const left = Math.floor((512 - width) / 2), top = 472 - height;
        const pose = await (0, sharp_1.default)({ create: { width: 512, height: 512, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
            .composite([{ input: cropped, left, top }]).png().toBuffer();
        poses.push(pose);
        layers.push({ input: pose, left: (index % 2) * 512, top: Math.floor(index / 2) * 512 });
    }
    const runtime = await (0, sharp_1.default)({ create: { width: 1024, height: 1024, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
        .composite(layers).png().toBuffer();
    if (runtime.length > config_1.MAX_PNG_BYTES)
        reject();
    await validateRuntimeSheet(runtime);
    return { original, runtime, poses, manifest: {
            schemaVersion: 1, assetID, version: 1, sha256: (0, exports.sha256)(runtime), styleVersion: 'retro-v1', width: 1024, height: 1024, archetype,
            frames: Object.fromEntries(types_1.POSES.map((pose, index) => [pose, [(index % 2) * 512, Math.floor(index / 2) * 512, 512, 512]])),
        } };
}
/** Matches the native installer alpha/bounds/trimmed-pixel gates before consuming a customer allowance. */
async function validateRuntimeSheet(runtime) {
    const { data } = await (0, sharp_1.default)(runtime, { limitInputPixels: 4194304 }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const distinct = new Set();
    for (let index = 0; index < 4; index++) {
        const ox = index % 2 * 512, oy = Math.floor(index / 2) * 512;
        let left = 512, top = 512, right = -1, bottom = -1, opaque = 0, transparent = 0;
        for (let y = 0; y < 512; y++)
            for (let x = 0; x < 512; x++) {
                const alpha = data[((oy + y) * 1024 + ox + x) * 4 + 3];
                if (alpha > 8) {
                    left = Math.min(left, x);
                    right = Math.max(right, x);
                    top = Math.min(top, y);
                    bottom = Math.max(bottom, y);
                }
                if (alpha > 127)
                    opaque++;
                if (alpha < 8)
                    transparent++;
            }
        if (opaque <= Math.floor(512 * 512 / 33) || transparent <= Math.floor(512 * 512 / 50)
            || left < 2 || top < 2 || right >= 510 || bottom >= 510 || right < left || bottom < top)
            reject();
        const width = right - left + 1, height = bottom - top + 1;
        const rgba = Buffer.alloc(width * height * 4);
        for (let y = 0; y < height; y++)
            for (let x = 0; x < width; x++) {
                const source = ((oy + top + y) * 1024 + ox + left + x) * 4, target = (y * width + x) * 4, alpha = data[source + 3];
                // UIImage/CGImage decodes into premultiplied RGBA; ignore hidden RGB in fully transparent pixels.
                for (let c = 0; c < 3; c++)
                    rgba[target + c] = Math.round(data[source + c] * alpha / 255);
                rgba[target + 3] = alpha;
            }
        distinct.add((0, exports.sha256)(Buffer.concat([Buffer.from(`${width}x${height}:`), rgba])));
    }
    if (distinct.size !== 4)
        reject();
}
function reject() { throw new types_1.ProviderError('quality_rejected', 'The artwork did not pass the four-pose quality check.'); }
