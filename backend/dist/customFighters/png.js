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
    if (original.length > config_1.MAX_PNG_BYTES)
        reject('png_source_size');
    if (!original.subarray(0, 8).equals(SIGNATURE))
        reject('png_source_format');
    const image = (0, sharp_1.default)(original, { limitInputPixels: 4194304, failOn: 'warning' });
    let metadata;
    try {
        metadata = await image.metadata();
    }
    catch {
        return reject('png_source_decode');
    }
    if (metadata.format !== 'png' || !metadata.hasAlpha || metadata.width !== 1024 || metadata.height !== 1024
        || (metadata.pages ?? 1) !== 1)
        reject('png_source_metadata');
    const { data, info } = await image.ensureAlpha().raw().toBuffer({ resolveWithObject: true })
        .catch(() => reject('png_source_decode'));
    if (info.channels !== 4)
        reject('png_source_channels');
    const drawings = extractDrawings(data);
    const normalizedDigests = new Set();
    for (const drawing of drawings) {
        const silhouette = await (0, sharp_1.default)(drawing.pixels, { raw: { width: drawing.width, height: drawing.height, channels: 4 } })
            .resize(96, 96, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 }, kernel: 'nearest' }).png().toBuffer();
        normalizedDigests.add((0, exports.sha256)(silhouette));
    }
    if (normalizedDigests.size !== 4)
        reject('png_source_duplicate_poses');
    const extent = Math.max(...drawings.map(drawing => Math.max(drawing.width, drawing.height)));
    // One bounded nearest-neighbor scale also enlarges low-resolution pixel art. The source
    // coverage minimum bounds the enlargement; relative size across the four poses is preserved.
    const scale = 432 / extent;
    const layers = [], poses = [];
    for (let index = 0; index < 4; index++) {
        const drawing = drawings[index];
        const width = Math.max(1, Math.round(drawing.width * scale)), height = Math.max(1, Math.round(drawing.height * scale));
        const cropped = await (0, sharp_1.default)(drawing.pixels, { raw: { width: drawing.width, height: drawing.height, channels: 4 } })
            .resize(width, height, { kernel: 'nearest' }).png().toBuffer();
        const left = Math.floor((512 - width) / 2), top = 472 - height;
        const pose = await (0, sharp_1.default)({ create: { width: 512, height: 512, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
            .composite([{ input: cropped, left, top }]).png().toBuffer();
        poses.push(pose);
        layers.push({ input: pose, left: (index % 2) * 512, top: Math.floor(index / 2) * 512 });
    }
    const runtime = await (0, sharp_1.default)({ create: { width: 1024, height: 1024, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
        .composite(layers).png().toBuffer();
    if (runtime.length > config_1.MAX_PNG_BYTES)
        reject('png_runtime_size');
    await validateRuntimeSheet(runtime);
    return { original, runtime, poses, manifest: {
            schemaVersion: 1, assetID, version: 1, sha256: (0, exports.sha256)(runtime), styleVersion: 'retro-v1', width: 1024, height: 1024, archetype,
            frames: Object.fromEntries(types_1.POSES.map((pose, index) => [pose, [(index % 2) * 512, Math.floor(index / 2) * 512, 512, 512]])),
        } };
}
/** Extract whole drawings rather than slicing body parts at the requested internal grid lines.
 * Every visible component is retained or the sheet is rejected; only alpha <=16 matte/glow is removed.
 * This is geometry, not a substitute for the subsequent subject/pose/safety review.
 */
function extractDrawings(data) {
    const size = 1024, pixelCount = size * size;
    let transparent = 0;
    for (let pixel = 0; pixel < pixelCount; pixel++)
        if (data[pixel * 4 + 3] <= 8)
            transparent++;
    if (transparent <= Math.floor(pixelCount / 50))
        reject('png_source_transparency');
    const labels = new Uint16Array(pixelCount), queue = new Uint32Array(pixelCount);
    const components = [];
    for (let pixel = 0; pixel < pixelCount; pixel++) {
        if (labels[pixel] || data[pixel * 4 + 3] <= 16)
            continue;
        const id = components.length + 1;
        if (id > 256)
            reject('png_source_components');
        let head = 0, tail = 1, left = size, top = size, right = -1, bottom = -1, sumX = 0, sumY = 0;
        queue[0] = pixel;
        labels[pixel] = id;
        while (head < tail) {
            const current = queue[head++], x = current % size, y = Math.floor(current / size);
            left = Math.min(left, x);
            right = Math.max(right, x);
            top = Math.min(top, y);
            bottom = Math.max(bottom, y);
            sumX += x;
            sumY += y;
            // Eight-connected pixels keep diagonal pixel-art outlines together.
            for (let ny = Math.max(0, y - 1); ny <= Math.min(size - 1, y + 1); ny++) {
                for (let nx = Math.max(0, x - 1); nx <= Math.min(size - 1, x + 1); nx++) {
                    const neighbor = ny * size + nx;
                    if (!labels[neighbor] && data[neighbor * 4 + 3] > 16) {
                        labels[neighbor] = id;
                        queue[tail++] = neighbor;
                    }
                }
            }
        }
        // Internal 512px boundaries are only ordering hints. The actual outer canvas must be uncut.
        if (left < 2 || top < 2 || right >= size - 2 || bottom >= size - 2)
            reject('png_source_margin');
        components.push({ id, count: tail, left, top, right, bottom, centerX: sumX / tail, centerY: sumY / tail });
    }
    const ranked = [...components].sort((a, b) => b.count - a.count);
    if (ranked.length < 4 || ranked[3].count < 1024)
        reject('png_source_coverage');
    const ordered = new Array(4);
    const owners = new Uint8Array(components.length + 1);
    for (const component of ranked.slice(0, 4)) {
        const pose = Math.floor(component.centerX / 512) + Math.floor(component.centerY / 512) * 2;
        if (ordered[pose])
            reject('png_source_layout');
        ordered[pose] = component;
        owners[component.id] = pose + 1;
    }
    const primary = ordered;
    const detachedPixels = [0, 0, 0, 0];
    for (const component of ranked.slice(4)) {
        const candidates = primary.map((body, pose) => ({ body, pose, distance: Math.hypot(Math.max(0, body.left - component.right - 1, component.left - body.right - 1), Math.max(0, body.top - component.bottom - 1, component.top - body.bottom - 1)) })).sort((a, b) => a.distance - b.distance);
        const nearest = candidates[0];
        const extent = Math.max(nearest.body.right - nearest.body.left + 1, nearest.body.bottom - nearest.body.top + 1);
        // Small expression marks/details may be detached. Extra characters, distant objects,
        // or marks equally close to two drawings are not silently removed or guessed.
        if (component.count > Math.min(2048, nearest.body.count * 0.08)
            || nearest.distance > Math.min(64, Math.max(16, extent * 0.15)))
            reject('png_source_detached');
        if (candidates[1].distance - nearest.distance < 8)
            reject('png_source_ambiguous');
        detachedPixels[nearest.pose] += component.count;
        if (detachedPixels[nearest.pose] > Math.min(4096, nearest.body.count * 0.1))
            reject('png_source_detached');
        owners[component.id] = nearest.pose + 1;
    }
    return primary.map((body, pose) => {
        const assigned = components.filter(component => owners[component.id] === pose + 1);
        const left = Math.min(...assigned.map(component => component.left)), top = Math.min(...assigned.map(component => component.top));
        const right = Math.max(...assigned.map(component => component.right)), bottom = Math.max(...assigned.map(component => component.bottom));
        const width = right - left + 1, height = bottom - top + 1, pixels = Buffer.alloc(width * height * 4);
        for (let y = top; y <= bottom; y++)
            for (let x = left; x <= right; x++) {
                const pixel = y * size + x;
                if (owners[labels[pixel]] === pose + 1)
                    data.copy(pixels, ((y - top) * width + x - left) * 4, pixel * 4, pixel * 4 + 4);
            }
        return { width, height, pixels };
    });
}
/** Matches the native installer alpha/bounds/trimmed-pixel gates before consuming a customer allowance. */
async function validateRuntimeSheet(runtime) {
    const { data } = await (0, sharp_1.default)(runtime, { limitInputPixels: 4194304 }).ensureAlpha().raw().toBuffer({ resolveWithObject: true })
        .catch(() => reject('png_runtime_decode'));
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
        if (opaque <= Math.floor(512 * 512 / 33))
            reject('png_runtime_coverage');
        if (transparent <= Math.floor(512 * 512 / 50))
            reject('png_runtime_transparency');
        if (left < 2 || top < 2 || right >= 510 || bottom >= 510 || right < left || bottom < top)
            reject('png_runtime_margin');
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
        reject('png_runtime_duplicate_poses');
}
function reject(reason) {
    throw new types_1.ProviderError('quality_rejected', 'The artwork did not pass the four-pose quality check.', reason);
}
