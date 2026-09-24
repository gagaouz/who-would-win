// Exercise real in-memory idempotency with synthetic data and stubbed generators.
// These tests do not authenticate real devices, call AI, or connect to a database.
delete process.env.DATABASE_URL;
delete process.env.DATABASE_PRIVATE_URL;

const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { setImmediate: nextTurn } = require('node:timers/promises');
const express = require('express');
const attest = require('../dist/services/appAttest');
const limits = require('../dist/middleware/rateLimit');
const claude = require('../dist/services/claudeService');
const melee = require('../dist/services/meleeService');
const responseStore = require('../dist/services/responseStore');
const battleLogger = require('../dist/services/battleLogger');
const customLogger = require('../dist/services/customCreatureLogger');

const routes = [
  { mode: 'full', path: '/battle', service: claude, method: 'getBattleResult' },
  { mode: 'quick', path: '/battle/quick', service: claude, method: 'getQuickBattleResult' },
  { mode: 'melee', path: '/battle/melee', service: melee, method: 'getMeleeResult' },
];

function matchup(route) {
  const moon = { id: `synthetic-moon-${randomUUID()}`, name: 'Synthetic Moon Moth' };
  const cloud = { id: `synthetic-cloud-${randomUUID()}`, name: 'Synthetic Cloud Ferret' };
  const body = route.mode === 'melee'
    ? { teamA: [moon, { id: 'lion' }], teamB: [cloud, { id: 'tiger' }] }
    : { fighter1: moon.id, fighter1Name: moon.name, fighter2: cloud.id, fighter2Name: cloud.name };
  const result = route.mode === 'melee'
    ? { winningTeam: 'A', mvp: moon.id, narration: 'Synthetic story.', funFact: 'Synthetic fact.', teamAHealth: 80, teamBHealth: 20 }
    : { winner: moon.id, narration: 'Synthetic story.', funFact: 'Synthetic fact.', winnerHealthPercent: 80, loserHealthPercent: 20 };
  return { body, result };
}

async function isolatedServer(t) {
  customLogger.purgeAllCustomCreatures();
  t.after(() => customLogger.purgeAllCustomCreatures());
  const pass = (_req, _res, next) => next();
  t.mock.method(attest, 'requireAppAttest', pass);
  for (const name of ['battleRateLimit', 'quickRateLimit', 'meleeRateLimit']) t.mock.method(limits, name, pass);
  // Repeated distinct battles intentionally reuse the same story cache slot.
  t.mock.method(responseStore, 'nextStoryVariant', async () => 0);
  const writes = [];
  t.mock.method(battleLogger, 'logBattle', async entry => { writes.push(entry); });
  const routerPath = require.resolve('../dist/routes/battle');
  delete require.cache[routerPath];
  const app = express();
  app.use(express.json());
  app.use('/api', require(routerPath).default);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => { server.closeAllConnections(); server.close(); delete require.cache[routerPath]; });
  return {
    writes,
    post: (path, body, requestId = randomUUID()) => fetch(`http://127.0.0.1:${server.address().port}/api${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-request-id': requestId },
      body: JSON.stringify(body),
    }),
  };
}

function assertAppearances(expected) {
  const report = customLogger.getCustomCreatureReport();
  assert.equal(report.totalUniqueCreatures, 2);
  assert.equal(report.totalLookups, 0);
  assert.equal(report.totalAttempts, expected * 2);
  assert.equal(report.totalBattles, expected * 2);
  for (const entry of report.topCreatures) {
    assert.equal(entry.attemptCount, expected);
    assert.equal(entry.count, expected);
    assert.equal(entry.wins, entry.name === 'synthetic moon moth' ? expected : 0);
  }
}

for (const route of routes) {
  test(`${route.mode} retries record each custom appearance once, while a new cached battle still counts`, async t => {
    const { body, result } = matchup(route);
    let generations = 0;
    t.mock.method(route.service, route.method, async () => {
      generations += 1;
      await nextTurn();
      return result;
    });
    const server = await isolatedServer(t);
    const requestId = randomUUID();
    const replies = await Promise.all(Array.from({ length: 3 }, () => server.post(route.path, body, requestId)));
    assert.deepEqual(replies.map(response => response.status), [200, 200, 200]);
    assert.equal(replies.filter(response => response.headers.get('x-result-cache') === 'MISS').length, 1);
    for (const response of replies) assert.deepEqual(await response.json(), result);
    assert.equal(generations, 1);
    assertAppearances(1);
    assert.equal(server.writes.length, 1);
    assert.equal(server.writes[0].mode, route.mode);

    const replay = await server.post(route.path, body, requestId);
    assert.equal(replay.status, 200);
    assert.equal(replay.headers.get('x-result-cache'), 'HIT');
    await replay.json();
    assertAppearances(1);
    assert.equal(server.writes.length, 1);

    const rematch = await server.post(route.path, body, randomUUID());
    assert.equal(rematch.status, 200);
    assert.equal(rematch.headers.get('x-result-cache'), 'HIT');
    await rematch.json();
    assert.equal(generations, 1, 'a result-cache hit must not regenerate the story');
    assertAppearances(2);
    assert.equal(server.writes.length, 2, 'a new accepted battle is not an idempotent replay');
  });

  test(`${route.mode} validates the complete matchup before retaining any typed name`, async t => {
    const { body } = matchup(route);
    if (route.mode === 'melee') body.teamB[0].name = 'synthetic@example.com';
    else body.fighter2Name = 'synthetic@example.com';
    const generator = t.mock.method(route.service, route.method, async () => { throw new Error('Generation must not run'); });
    const server = await isolatedServer(t);
    const response = await server.post(route.path, body);
    assert.equal(response.status, 400);
    await response.json();
    assert.equal(generator.mock.callCount(), 0);
    assert.equal(server.writes.length, 0);
    const report = customLogger.getCustomCreatureReport();
    assert.equal(report.totalUniqueCreatures, 0);
    assert.equal(report.totalAttempts, 0);
    assert.equal(report.totalBattles, 0);
  });

  test(`${route.mode} generation failure retains accepted names as attempts without inventing completed results`, async t => {
    const { body } = matchup(route);
    t.mock.method(route.service, route.method, async () => { throw new Error('Synthetic generation unavailable'); });
    t.mock.method(console, 'error', () => {});
    const server = await isolatedServer(t);
    const response = await server.post(route.path, body);
    assert.equal(response.status, 500);
    await response.json();
    assert.equal(server.writes.length, 0);
    const report = customLogger.getCustomCreatureReport();
    assert.equal(report.totalUniqueCreatures, 2);
    assert.equal(report.totalAttempts, 2);
    assert.equal(report.totalBattles, 0);
    for (const entry of report.topCreatures) {
      assert.equal(entry.attemptCount, 1);
      assert.equal(entry.count, 0);
      assert.equal(entry.wins, 0);
      assert.deepEqual(entry.opponentNames, []);
    }
  });
}
