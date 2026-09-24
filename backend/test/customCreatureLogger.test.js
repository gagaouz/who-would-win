// Temporary, private request reporting: no AI calls or external database.
delete process.env.DATABASE_URL;
delete process.env.DATABASE_PRIVATE_URL;

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  getCustomCreatureReport,
  logCustomCreature,
  logCustomCreatureAttempt,
  logCustomCreatureLookup,
  purgeAllCustomCreatures,
} = require('../dist/services/customCreatureLogger');

test.beforeEach(() => purgeAllCustomCreatures());

test('accepted lookups appear before a battle, separately from completed appearances and wins', () => {
  logCustomCreatureLookup('  Moon   Moth  ');
  logCustomCreatureLookup('moon moth');
  let report = getCustomCreatureReport();
  assert.equal(report.totalUniqueCreatures, 1);
  assert.equal(report.totalLookups, 2);
  assert.equal(report.totalBattles, 0);
  assert.equal(report.topCreatures[0].displayName, 'Moon Moth');

  logCustomCreature('MOON MOTH', 'Lion', undefined, true);
  logCustomCreature('Moon Moth', 'Tiger', undefined, false);
  report = getCustomCreatureReport();
  assert.equal(report.totalUniqueCreatures, 1);
  assert.equal(report.totalLookups, 2);
  assert.equal(report.totalBattles, 2);
  assert.equal(report.topCreatures[0].wins, 1);
  assert.deepEqual(report.topCreatures[0].opponentNames, ['Lion', 'Tiger']);
});

test('tracker rejects contact details at its own boundary and excludes built-in classification names', () => {
  for (const name of ['parent@example.com', '+1 212 555 0100', 'https://example.com', '', null]) {
    logCustomCreatureLookup(name);
    logCustomCreatureAttempt(name);
    logCustomCreature(name, 'Lion');
  }
  for (const name of ['Lion', 'LION', 'Tabby Cat', 'tabby_cat']) logCustomCreatureLookup(name);
  assert.equal(getCustomCreatureReport().totalUniqueCreatures, 0);

  logCustomCreature('Moon Moth', 'parent@example.com');
  assert.deepEqual(getCustomCreatureReport().topCreatures[0].opponentNames, []);
});

test('accepted battle attempts remain visible without a generated result and do not count as wins or completions', () => {
  logCustomCreatureAttempt('Cloud Otter');
  let report = getCustomCreatureReport();
  assert.equal(report.totalUniqueCreatures, 1);
  assert.equal(report.totalAttempts, 1);
  assert.equal(report.totalLookups, 0);
  assert.equal(report.totalBattles, 0);
  assert.equal(report.topCreatures[0].attemptCount, 1);
  assert.equal(report.topCreatures[0].wins, 0);

  logCustomCreatureAttempt('CLOUD OTTER');
  logCustomCreature('Cloud Otter', 'Tiger', undefined, true);
  report = getCustomCreatureReport();
  assert.equal(report.totalUniqueCreatures, 1);
  assert.equal(report.totalAttempts, 2);
  assert.equal(report.totalBattles, 1);
  assert.equal(report.topCreatures[0].wins, 1);
});

test('report includes every available name and does not expose mutable storage references', () => {
  for (let index = 0; index < 125; index++) logCustomCreatureLookup(`Moon Moth ${index}`);
  const report = getCustomCreatureReport();
  assert.equal(report.totalUniqueCreatures, 125);
  assert.equal(report.topCreatures.length, 125);
  assert.equal(report.storageMode, 'temporary-memory');
  report.topCreatures[0].displayName = 'Changed outside the tracker';
  report.topCreatures[0].opponentNames.push('Altered');
  const next = getCustomCreatureReport();
  assert.notEqual(next.topCreatures[0].displayName, 'Changed outside the tracker');
  assert.deepEqual(next.topCreatures[0].opponentNames, []);
});

test('expiry runs on reads without another request, and purge starts a new reporting window', t => {
  let now = Date.parse('2026-01-01T00:00:00Z');
  t.mock.method(Date, 'now', () => now);
  purgeAllCustomCreatures();
  logCustomCreatureLookup('Moon Moth');
  const initial = getCustomCreatureReport();
  now += 90 * 24 * 60 * 60 * 1000;
  const expired = getCustomCreatureReport();
  assert.equal(expired.totalUniqueCreatures, 0);
  assert.equal(expired.expiredCount, 1);
  assert.equal(expired.capturedSince, initial.capturedSince);
  logCustomCreatureLookup('Moon Moth');
  assert.equal(getCustomCreatureReport().topCreatures[0].lookupCount, 1);
  assert.equal(purgeAllCustomCreatures(), 1);
  const empty = getCustomCreatureReport();
  assert.equal(empty.capturedSince, new Date(now).toISOString());
  assert.equal(empty.expiredCount, 0);
});

test('capacity eviction is disclosed and retains a recently revisited name', () => {
  for (let index = 0; index < 5000; index++) logCustomCreatureLookup(`Moon Moth ${index}`);
  logCustomCreatureLookup('Moon Moth 0');
  logCustomCreatureLookup('Moon Moth 5000');
  const report = getCustomCreatureReport();
  assert.equal(report.capacity, 5000);
  assert.equal(report.totalUniqueCreatures, 5000);
  assert.equal(report.evictedCount, 1);
  assert.equal(report.truncated, true);
  assert.ok(report.topCreatures.some(entry => entry.name === 'moon moth 0'));
  assert.ok(!report.topCreatures.some(entry => entry.name === 'moon moth 1'));
});

test('animal route records an accepted lookup even when classification fails, without logging its error text', async t => {
  const express = require('express');
  const attest = require('../dist/services/appAttest');
  const anthropic = require('../dist/services/anthropicClient');
  t.mock.method(attest, 'requireAppAttest', (_req, _res, next) => next());
  t.mock.method(anthropic, 'createMessage', async () => {
    throw new Error('Do not log this private payload');
  });
  const logs = [];
  t.mock.method(console, 'error', (...args) => logs.push(args.join(' ')));
  const router = require('../dist/routes/animal').default;
  const app = express();
  app.use(express.json());
  app.use('/api', router);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => {
    server.closeAllConnections();
    server.close();
  });
  const url = `http://127.0.0.1:${server.address().port}/api/animal`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'Cloud Ferret' }),
  });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).emoji, '🐾');
  const report = getCustomCreatureReport();
  assert.equal(report.totalLookups, 1);
  assert.equal(report.totalBattles, 0);
  assert.equal(report.topCreatures[0].name, 'cloud ferret');
  assert.ok(logs.includes('[animal] lookup failed'));
  assert.ok(!logs.some(log => log.includes('private payload') || log.includes('Cloud Ferret')));
});
