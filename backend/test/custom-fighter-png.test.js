const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const sharp = require('sharp');
const { validateAndPackSheet, validateRuntimeSheet, sha256 } = require('../dist/customFighters/png');

// Synthetic mechanical fixtures only. Passing these gates does not establish a safe subject
// or four meaningful anatomical poses; the worker must still run moderation and semantic review.
async function sheet(draw, backgroundAlpha = 0) {
  const data = Buffer.alloc(1024 * 1024 * 4);
  if (backgroundAlpha) for (let offset = 3; offset < data.length; offset += 4) data[offset] = backgroundAlpha;
  for (let pose = 0; pose < 4; pose++) {
    const ox = pose % 2 * 512, oy = Math.floor(pose / 2) * 512;
    const rect = (x, y, width, height, color = [50, 130, 190, 255]) => {
      assert.ok(ox + x >= 0 && oy + y >= 0 && ox + x + width <= 1024 && oy + y + height <= 1024);
      for (let yy = y; yy < y + height; yy++) for (let xx = x; xx < x + width; xx++) {
        const offset = ((oy + yy) * 1024 + ox + xx) * 4;
        for (let channel = 0; channel < 4; channel++) data[offset + channel] = color[channel];
      }
    };
    draw(rect, pose);
  }
  return sharp(data, { raw: { width: 1024, height: 1024, channels: 4 } }).png().toBuffer();
}

function body(rect, pose, x = 140, y = 100) {
  rect(x, y, 120, 230);
  rect(x + 100, y + 30 + pose * 18, 90, 40, [240, 180, 70, 255]);
  rect(x + 5 + pose * 10, y + 230, 40, 80);
}

async function cellMeasurements(image) {
  const { data } = await sharp(image).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  return Array.from({ length: 4 }, (_, pose) => {
    const ox = pose % 2 * 512, oy = Math.floor(pose / 2) * 512;
    let left = 512, top = 512, right = -1, bottom = -1, opaque = 0;
    const colors = new Set();
    for (let y = 0; y < 512; y++) for (let x = 0; x < 512; x++) {
      const offset = ((oy + y) * 1024 + ox + x) * 4;
      if (data[offset + 3] > 8) {
        left = Math.min(left, x); right = Math.max(right, x);
        top = Math.min(top, y); bottom = Math.max(bottom, y);
        colors.add(data.subarray(offset, offset + 4).toString('hex'));
      }
      if (data[offset + 3] > 127) opaque++;
    }
    return { left, top, right, bottom, width: right - left + 1, height: bottom - top + 1, opaque, colors };
  });
}

const rejection = reason => error => {
  assert.equal(error.code, 'quality_rejected');
  assert.equal(error.reason, reason);
  assert.equal(error.message, 'The artwork did not pass the four-pose quality check.');
  return true;
};

test('dense subjects within the requested central 420px area normalize without discarding valid artwork', async () => {
  const original = await sheet((rect, pose) => {
    rect(46, 48, 420 - pose, 416);
    rect(65 + pose * 9, 65, 18, 18, [240, 180, 70, 255]);
  });
  assert.ok((await cellMeasurements(original)).every(cell => cell.opaque / (512 * 512) > 0.65));
  const id = randomUUID();
  const pack = await validateAndPackSheet(original, id);
  await validateRuntimeSheet(pack.runtime);
  assert.ok(pack.original.equals(original));
  assert.equal(pack.manifest.assetID, id);
  assert.equal(pack.manifest.sha256, sha256(pack.runtime));
  assert.deepEqual(pack.manifest.frames, {
    idle: [0, 0, 512, 512], anticipation: [512, 0, 512, 512],
    attack: [0, 512, 512, 512], reaction: [512, 512, 512, 512],
  });
});

test('complete drawings with small transparent margins on every edge receive safe display padding', async () => {
  for (const margin of [2, 4, 11]) for (const edge of ['left', 'right', 'top', 'bottom']) {
    const x = edge === 'left' ? margin : edge === 'right' ? 512 - margin - 190 : 140;
    const y = edge === 'top' ? margin : edge === 'bottom' ? 512 - margin - 310 : 100;
    const original = await sheet((rect, pose) => body(rect, pose, x, y));
    const pack = await validateAndPackSheet(original, randomUUID());
    await validateRuntimeSheet(pack.runtime);
    for (const cell of await cellMeasurements(pack.runtime)) {
      assert.ok(cell.left >= 40 && cell.right <= 471, `${edge} ${margin}`);
      assert.ok(cell.top >= 40, `${edge} ${margin}`);
      assert.equal(cell.bottom, 471);
    }
  }
});

test('small pixel art is enlarged with one family scale, retaining relative dimensions, colors, and baseline', async () => {
  const heights = [100, 90, 80, 70];
  const original = await sheet((rect, pose) => {
    rect(180, 210, 48, heights[pose]);
    rect(220, 220 + pose * 11, 40, 12, [240, 180, 70, 255]);
  });
  const input = await cellMeasurements(original);
  assert.ok(input.every(cell => cell.opaque > 1024 && cell.opaque < 7944));
  const pack = await validateAndPackSheet(original, randomUUID());
  await validateRuntimeSheet(pack.runtime);
  const output = await cellMeasurements(pack.runtime);
  for (let pose = 0; pose < 4; pose++) {
    assert.equal(output[pose].width, Math.round(input[pose].width * 4.32));
    assert.equal(output[pose].height, Math.round(input[pose].height * 4.32));
    assert.equal(output[pose].bottom, 471);
    assert.deepEqual(output[pose].colors, input[pose].colors);
  }
  assert.ok(output[3].height < output[0].height, 'shorter pose must not be independently stretched');
});

test('true cell-edge contact and one-pixel margins remain rejected on all four edges', async () => {
  for (const margin of [0, 1]) for (const edge of ['left', 'right', 'top', 'bottom']) {
    const x = edge === 'left' ? margin : edge === 'right' ? 512 - margin - 190 : 140;
    const y = edge === 'top' ? margin : edge === 'bottom' ? 512 - margin - 310 : 100;
    const original = await sheet((rect, pose) => body(rect, pose, x, y));
    await assert.rejects(() => validateAndPackSheet(original, randomUUID()), rejection('png_source_margin'));
  }
});

test('blank, missing, postage-stamp, and opaque cells are not repaired into accepted artwork', async () => {
  for (const draw of [() => {}, (rect, pose) => { if (pose !== 2) body(rect, pose); }, rect => rect(200, 200, 16, 16)]) {
    await assert.rejects(() => sheet(draw).then(image => validateAndPackSheet(image, randomUUID())), rejection('png_source_coverage'));
  }
  const opaque = await sheet((rect, pose) => body(rect, pose), 255);
  await assert.rejects(() => validateAndPackSheet(opaque, randomUUID()), rejection('png_source_transparency'));
});

test('identical and translated copies still fail the scale-normalized duplicate gate', async () => {
  for (const translated of [false, true]) {
    const original = await sheet((rect, pose) => body(rect, 0, 100 + (translated ? pose * 12 : 0), 100));
    await assert.rejects(() => validateAndPackSheet(original, randomUUID()), rejection('png_source_duplicate_poses'));
  }
});

test('runtime density, transparency, margins, and distinct-pixel checks are still enforced', async () => {
  const small = await sheet((rect, pose) => { rect(150, 150, 48, 100); rect(190, 160 + pose * 10, 40, 12); });
  await assert.rejects(() => validateRuntimeSheet(small), rejection('png_runtime_coverage'));
  const opaque = await sheet((rect, pose) => body(rect, pose), 255);
  await assert.rejects(() => validateRuntimeSheet(opaque), rejection('png_runtime_transparency'));
  const clipped = await sheet((rect, pose) => body(rect, pose, 0));
  await assert.rejects(() => validateRuntimeSheet(clipped), rejection('png_runtime_margin'));
  const duplicate = await sheet((rect, pose) => body(rect, 0, 100 + pose * 12));
  await assert.rejects(() => validateRuntimeSheet(duplicate), rejection('png_runtime_duplicate_poses'));
});

test('PNG format, size, dimensions, and alpha requirements retain bounded diagnostic reasons', async () => {
  await assert.rejects(() => validateAndPackSheet(Buffer.alloc(8 * 1024 * 1024 + 1), randomUUID()), rejection('png_source_size'));
  await assert.rejects(() => validateAndPackSheet(Buffer.from('not PNG or any private user input'), randomUUID()), rejection('png_source_format'));
  await assert.rejects(() => validateAndPackSheet(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), randomUUID()), rejection('png_source_decode'));
  const original = await sheet((rect, pose) => body(rect, pose));
  const small = await sharp(original).resize(512, 512).png().toBuffer();
  const rgb = await sharp(original).removeAlpha().png().toBuffer();
  for (const invalid of [small, rgb]) {
    await assert.rejects(() => validateAndPackSheet(invalid, randomUUID()), rejection('png_source_metadata'));
  }
});

test('whole connected poses can cross either internal grid line without cropping limbs or contaminating a neighbor', async () => {
  const hand = 'fd00a1ff', foot = '18e46aff';
  const original = await sheet((rect, pose) => {
    body(rect, pose);
    if (pose === 0) rect(155, 390, 20, 150, [24, 228, 106, 255]); // reaches y539
    if (pose === 2) rect(300, 180, 260, 20, [253, 0, 161, 255]); // reaches x559
  });
  const pack = await validateAndPackSheet(original, randomUUID());
  await validateRuntimeSheet(pack.runtime);
  assert.ok(pack.original.equals(original));
  const cells = await cellMeasurements(pack.runtime);
  assert.equal(cells[0].height, 432); // complete 440px source drawing
  assert.equal(cells[2].width, Math.round(420 * 432 / 440));
  assert.ok(cells[0].colors.has(foot));
  assert.ok(cells[2].colors.has(hand));
  assert.ok(!cells[2].colors.has(foot));
  assert.ok(!cells[3].colors.has(hand));
  assert.ok(cells.every(cell => cell.bottom === 471));
});

test('pixel masks isolate drawings even when their bounding rectangles overlap', async () => {
  const neighborColor = [253, 0, 161, 255];
  const original = await sheet((rect, pose) => {
    if (pose === 3) {
      rect(140, 100, 120, 230, neighborColor);
      rect(240, 184, 90, 40, neighborColor);
      rect(175, 330, 40, 80, neighborColor);
    } else body(rect, pose);
    if (pose === 2) {
      rect(240, 10, 20, 120);
      rect(240, 10, 420, 20); // bounds overlap the reaction body at x652...659
    }
  });
  const pack = await validateAndPackSheet(original, randomUUID());
  const cells = await cellMeasurements(pack.runtime);
  assert.ok(!cells[2].colors.has('fd00a1ff'), 'neighbor pixels must not leak into an overlapping crop');
  assert.ok(cells[3].colors.has('fd00a1ff'));
  await validateRuntimeSheet(pack.runtime);
});

test('small nearby disconnected expression marks are retained with their unambiguous drawing', async () => {
  const original = await sheet((rect, pose) => {
    body(rect, pose);
    if (pose === 3) {
      rect(335, 110, 8, 18, [253, 0, 161, 255]);
      rect(341, 140, 6, 12, [253, 0, 161, 255]);
    }
  });
  const pack = await validateAndPackSheet(original, randomUUID());
  const cells = await cellMeasurements(pack.runtime);
  assert.ok(cells[3].colors.has('fd00a1ff'));
  assert.ok(cells.slice(0, 3).every(cell => !cell.colors.has('fd00a1ff')));
  assert.equal(cells[3].width, Math.round(207 * 432 / 310));
});

test('merged drawings, duplicated centroid quadrants, and a fifth substantial drawing are rejected', async () => {
  const merged = await sheet((rect, pose) => {
    body(rect, pose);
    if (pose === 0) rect(200, 200, 481, 8); // joins the two top-row bodies
  });
  await assert.rejects(() => validateAndPackSheet(merged, randomUUID()), rejection('png_source_coverage'));
  const badLayout = await sheet((rect, pose) => {
    if (pose === 1) rect(-200, 10, 60, 80); else body(rect, pose);
  });
  await assert.rejects(() => validateAndPackSheet(badLayout, randomUUID()), rejection('png_source_layout'));
  const extra = await sheet((rect, pose) => {
    body(rect, pose); if (pose === 0) rect(420, 30, 60, 60);
  });
  await assert.rejects(() => validateAndPackSheet(extra, randomUUID()), rejection('png_source_detached'));
});

test('ambiguous or distant detached details are rejected rather than discarded or assigned speculatively', async () => {
  const ambiguous = await sheet((rect, pose) => {
    body(rect, pose, pose === 0 ? 300 : pose === 1 ? 32 : 140);
    if (pose === 0) rect(512, 110, 8, 8);
  });
  await assert.rejects(() => validateAndPackSheet(ambiguous, randomUUID()), rejection('png_source_ambiguous'));
  const distant = await sheet((rect, pose) => {
    body(rect, pose); if (pose === 0) rect(450, 450, 4, 4);
  });
  await assert.rejects(() => validateAndPackSheet(distant, randomUUID()), rejection('png_source_detached'));
});

test('fragmented noise has a bounded component budget', async () => {
  const original = await sheet((rect, pose) => {
    body(rect, pose);
    if (pose === 0) for (let i = 0; i < 257; i++) rect(5 + i % 32 * 3, 5 + Math.floor(i / 32) * 3, 1, 1);
  });
  await assert.rejects(() => validateAndPackSheet(original, randomUUID()), rejection('png_source_components'));
});
