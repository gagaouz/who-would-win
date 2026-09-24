// Synthetic fixtures only: no live credentials, database, or AI calls.
delete process.env.DATABASE_URL;
delete process.env.DATABASE_PRIVATE_URL;

const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const { renderDashboardHtml, serializeDashboardData } = require('../dist/views/adminDashboard');

const timestamp = '2026-01-01T12:00:00.000Z';

function fixture(count = 1) {
  const creatures = Array.from({ length: count }, (_, index) => ({
    name: `synthetic moon moth ${index}`,
    displayName: `Synthetic Moon Moth ${index}`,
    count: 2,
    lookupCount: 3,
    attemptCount: 2,
    wins: 1,
    firstSeen: timestamp,
    lastSeen: timestamp,
    opponentNames: ['Synthetic Cloud Ferret'],
  }));
  return {
    overview: {
      totalBattles: 12, battles24h: 3, battles7d: 7,
      customBattles: 4, customAppearances: 5, lastActivityAt: timestamp,
    },
    custom: {
      totalUniqueCreatures: count, totalBattles: count * 2, totalLookups: count * 3, totalAttempts: count * 2,
      topCreatures: creatures, generatedAt: timestamp, capturedSince: timestamp,
      retentionDays: 90, capacity: 5000, storageMode: 'temporary-memory',
      evictedCount: 0, expiredCount: 0, truncated: false,
    },
    animals: {
      topByWins: [], topByWinRate: [], topByPopularity: [],
      totalBattles: 12, generatedAt: timestamp,
    },
    recent: [{
      id: 1, fighter1: 'Lion', fighter2: 'Tiger', winner: 'Lion',
      environment: 'Grassland', mode: 'full', createdAt: timestamp,
    }],
  };
}

function extractScripts(html) {
  return Array.from(html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi));
}

function embeddedData(html) {
  const scripts = extractScripts(html);
  assert.equal(scripts.length, 1, 'the dashboard should have exactly one executable script');
  const assignment = scripts[0][2].match(/^const dashboardData = ([^\n]+);\n/);
  assert.ok(assignment, 'the complete snapshot must be embedded as JSON');
  return JSON.parse(assignment[1]);
}

test('dashboard JSON round-trips hostile labels without exposing HTML script delimiters', () => {
  const data = fixture();
  const hostile = '</ScRiPt><img src=x onerror="globalThis.pwned=true"><script>/* & \u2028 \u2029 */';
  data.custom.topCreatures[0].displayName = hostile;
  data.custom.topCreatures[0].name = hostile;
  data.custom.topCreatures[0].opponentNames = [hostile, '🦋 Moon & Moth "A" \'B\''];
  data.recent[0].fighter1 = hostile;
  data.recent[0].winner = hostile;
  data.recent[0].environment = hostile;
  const serialized = serializeDashboardData(data);
  assert.doesNotMatch(serialized, /[<>&\u2028\u2029]/);
  assert.deepEqual(JSON.parse(serialized), data);

  const context = {};
  const roundTrip = vm.runInNewContext(`JSON.stringify(${serialized})`, context, { timeout: 1000 });
  assert.deepEqual(JSON.parse(roundTrip), data);
  assert.equal(context.pwned, undefined);
});

test('rendered dashboard cannot turn labels into script tags or inline event attributes', () => {
  const data = fixture();
  const hostile = '</script><svg onload="globalThis.pwned=true"></svg><script>';
  data.custom.topCreatures[0].displayName = hostile;
  data.custom.topCreatures[0].opponentNames = ['"><img src=x onerror=alert(1)>'];
  data.recent[0].fighter2 = hostile;
  data.animals.topByPopularity = [{ id: hostile, name: hostile, wins: 1, battles: 2, winRate: 0.5 }];
  const html = renderDashboardHtml(data, 'synthetic-nonce');
  assert.deepEqual(embeddedData(html), data);
  assert.equal((html.match(/<script\b/gi) || []).length, 1);
  assert.equal((html.match(/<\/script\s*>/gi) || []).length, 1);
  assert.doesNotMatch(html, /<[^>]+\s+on[a-z]+\s*=/i);
  assert.doesNotMatch(html, /(?:innerHTML|outerHTML|insertAdjacentHTML)\s*[=(]/);
  assert.doesNotThrow(() => new vm.Script(extractScripts(html)[0][2]));
});

test('nonce attribute remains a single attribute even for an unexpected quoted value', () => {
  const nonce = 'synthetic"><svg onload="alert(1)">&';
  const html = renderDashboardHtml(fixture(), nonce);
  const [script] = extractScripts(html);
  assert.equal(script[1], ' nonce="synthetic&quot;&gt;&lt;svg onload=&quot;alert(1)&quot;&gt;&amp;"');
  assert.equal((html.match(/<script\b/gi) || []).length, 1);
  assert.ok(!html.includes('<svg onload='));
});

test('every available custom name survives rendering beyond old top-50 and top-100 cutoffs', () => {
  const data = fixture(137);
  const html = renderDashboardHtml(data, 'synthetic-nonce');
  const actual = embeddedData(html);
  assert.equal(actual.custom.topCreatures.length, 137);
  assert.deepEqual(actual.custom.topCreatures, data.custom.topCreatures);
  assert.equal(actual.custom.totalUniqueCreatures, actual.custom.topCreatures.length);
  assert.deepEqual(data.custom.topCreatures.map(entry => entry.name), fixture(137).custom.topCreatures.map(entry => entry.name));
  assert.match(html, /Temporary history/);
  assert.match(html, /Names clear when this server restarts/);
});

test('empty temporary snapshot remains valid, rather than substituting retained or demo names', () => {
  const data = fixture(0);
  const actual = embeddedData(renderDashboardHtml(data, 'synthetic-nonce'));
  assert.deepEqual(actual.custom.topCreatures, []);
  assert.equal(actual.custom.totalUniqueCreatures, 0);
  assert.equal(actual.custom.storageMode, 'temporary-memory');
});

test('private dashboard rejects URL secrets and returns the whole available list only after authentication', async t => {
  const express = require('express');
  const limits = require('../dist/middleware/rateLimit');
  const battleLogger = require('../dist/services/battleLogger');
  const customLogger = require('../dist/services/customCreatureLogger');
  const data = fixture(137);
  t.mock.method(limits, 'adminRateLimit', (_req, _res, next) => next());
  t.mock.method(battleLogger, 'getAdminOverview', async () => data.overview);
  t.mock.method(battleLogger, 'getAnimalLeaderboard', async () => data.animals);
  t.mock.method(battleLogger, 'getRecentActivity', async () => data.recent);
  t.mock.method(customLogger, 'getCustomCreatureReport', () => data.custom);
  const originalSecret = process.env.ADMIN_SECRET;
  const testSecret = 'synthetic-test-secret-no-real-access';
  process.env.ADMIN_SECRET = testSecret;
  t.after(() => {
    if (originalSecret === undefined) delete process.env.ADMIN_SECRET;
    else process.env.ADMIN_SECRET = originalSecret;
  });

  const app = express();
  app.use('/api', require('../dist/routes/battle').default);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => { server.closeAllConnections(); server.close(); });
  const url = `http://127.0.0.1:${server.address().port}/api/admin/dashboard`;

  for (const path of [url, `${url}?token=${testSecret}`]) {
    const response = await fetch(path, { redirect: 'manual' });
    assert.equal(response.status, 303);
    assert.equal(response.headers.get('location'), '/api/admin/login');
    assert.ok(!(await response.text()).includes('Synthetic Moon Moth'));
  }

  const response = await fetch(url, { headers: { 'x-admin-secret': testSecret }, redirect: 'manual' });
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.deepEqual(embeddedData(html), data);
  assert.ok(!html.includes(testSecret));
  const nonce = extractScripts(html)[0][1].match(/^ nonce="([A-Za-z0-9+/=]+)"$/)?.[1];
  assert.ok(nonce, 'executable script must carry a nonce');
  const policy = response.headers.get('content-security-policy');
  assert.ok(policy.includes(`script-src 'nonce-${nonce}'`));
  assert.match(policy, /frame-ancestors 'none'/);
  assert.match(policy, /base-uri 'none'/);
  assert.doesNotMatch(policy.match(/script-src[^;]*/)[0], /unsafe-inline|unsafe-eval/);
});
