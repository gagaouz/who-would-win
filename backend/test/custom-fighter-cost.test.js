const { test } = require('node:test');
const assert = require('node:assert/strict');
const { failedWorkflowCostBound } = require('../dist/customFighters/cost');
const image = { operation: 'image', inputTokens: 2000, outputTokens: 439, estimatedMicrodollars: 29170 };
const review = { operation: 'review', inputTokens: 2100, outputTokens: 60, estimatedMicrodollars: 936 };

test('terminal pre-review failure settles only complete image usage', () => {
  for (const stage of ['image_generation', 'image_validation', 'artwork_moderation']) {
    assert.equal(failedWorkflowCostBound([image], stage), 100000);
    for (const incomplete of [[], [review], [image, image], [image, review], [{ ...image, outputTokens: undefined }]]) {
      assert.equal(failedWorkflowCostBound(incomplete, stage), null);
    }
  }
});

test('a dispatched review requires both complete paid records even if image cost is known', () => {
  for (const stage of ['artwork_review', 'publication']) {
    assert.equal(failedWorkflowCostBound([image, review], stage), 100000);
    assert.equal(failedWorkflowCostBound([image], stage), null);
    assert.equal(failedWorkflowCostBound([image, { ...review, outputTokens: undefined }], stage), null);
  }
  for (const stage of [undefined, 'name_moderation', 'dispatch', 'invalid']) {
    assert.equal(failedWorkflowCostBound([image], stage), null);
  }
});

test('failure exposure does not cap unexpectedly high known charges at the original reservation', () => {
  assert.equal(failedWorkflowCostBound([{ ...image, estimatedMicrodollars: 1700000 }], 'image_validation'), 3400000);
  for (const value of [-1, 0.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    assert.equal(failedWorkflowCostBound([{ ...image, estimatedMicrodollars: value }], 'image_validation'), null);
  }
});
