// Local synthetic sessions only, with real in-memory limiter profiles.
delete process.env.DATABASE_URL;
delete process.env.DATABASE_PRIVATE_URL;

const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const express = require('express');
const battleLogger = require('../dist/services/battleLogger');

test('authenticated dashboard/report reads have their own bounded budget; failed auth and mutations stay strict', async t => {
  const originalSecret = process.env.ADMIN_SECRET;
  const originalSalt = process.env.RATE_LIMIT_SALT;
  const secret = `synthetic-${randomUUID()}`;
  process.env.ADMIN_SECRET = secret;
  process.env.RATE_LIMIT_SALT = randomUUID();
  t.after(() => {
    if (originalSecret === undefined) delete process.env.ADMIN_SECRET;
    else process.env.ADMIN_SECRET = originalSecret;
    if (originalSalt === undefined) delete process.env.RATE_LIMIT_SALT;
    else process.env.RATE_LIMIT_SALT = originalSalt;
  });
  t.mock.method(Date, 'now', () => Date.parse('2026-01-01T12:00:01.000Z'));
  t.mock.method(battleLogger, 'getAdminOverview', async () => ({
    totalBattles: 0, battles24h: 0, battles7d: 0,
    customBattles: 0, customAppearances: 0, lastActivityAt: null,
  }));
  t.mock.method(battleLogger, 'getAnimalLeaderboard', async () => ({
    topByWins: [], topByWinRate: [], topByPopularity: [],
    totalBattles: 0, generatedAt: new Date(Date.now()).toISOString(),
  }));
  t.mock.method(battleLogger, 'getRecentActivity', async () => []);
  const app = express();
  app.use('/api', require('../dist/routes/battle').default);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => { server.closeAllConnections(); server.close(); });
  const base = `http://127.0.0.1:${server.address().port}/api/admin`;
  const request = (path, options = {}) => fetch(base + path, { ...options, redirect: 'manual' });
  const auth = { 'x-admin-secret': secret };

  for (let index = 1; index <= 12; index++) {
    const response = await request(index % 2 ? '/dashboard' : '/custom-creatures', { headers: auth });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('x-ratelimit-limit'), '60');
    assert.equal(response.headers.get('x-ratelimit-remaining'), String(60 - index));
    await response.text();
  }

  const login = await request('/login', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ password: secret }).toString(),
  });
  assert.equal(login.status, 303);
  assert.equal(login.headers.get('x-ratelimit-limit'), '10');
  assert.equal(login.headers.get('x-ratelimit-remaining'), '9', 'reading must not consume login attempts');
  const cookie = login.headers.get('set-cookie').split(';')[0];
  await login.text();

  const invalidHeader = await request('/custom-creatures', { headers: { 'x-admin-secret': 'synthetic-wrong' } });
  assert.equal(invalidHeader.status, 401);
  assert.equal(invalidHeader.headers.get('x-ratelimit-limit'), '10');
  await invalidHeader.text();
  const invalidCookie = await request('/dashboard', { headers: { Cookie: 'ava_admin_session=synthetic-invalid' } });
  assert.equal(invalidCookie.status, 303);
  assert.equal(invalidCookie.headers.get('location'), '/api/admin/login');
  assert.equal(invalidCookie.headers.get('x-ratelimit-limit'), '10');
  await invalidCookie.text();

  for (let count = 4; count <= 10; count++) {
    const response = await request('/custom-creatures');
    assert.equal(response.status, 401);
    assert.equal(response.headers.get('x-ratelimit-remaining'), String(10 - count));
    await response.text();
  }
  for (const [path, method] of [
    ['/dashboard', 'GET'], ['/login', 'GET'], ['/logout', 'POST'], ['/custom-creatures/purge', 'POST'],
  ]) {
    const response = await request(path, { method, headers: method === 'POST' ? auth : undefined });
    assert.equal(response.status, 429, `${method} ${path} must remain on the strict budget`);
    assert.equal(response.headers.get('x-ratelimit-limit'), '10');
    await response.text();
  }

  const font = await request('/assets/Fredoka.ttf');
  assert.equal(font.status, 200, 'public allowlisted fonts do not consume either admin limit');
  assert.equal(font.headers.get('x-ratelimit-limit'), null);
  assert.ok((await font.arrayBuffer()).byteLength > 0);

  for (let count = 13; count <= 60; count++) {
    const response = await request('/custom-creatures', { headers: { Cookie: cookie } });
    assert.equal(response.status, 200, 'an authenticated session is separate from exhausted failed-auth attempts');
    assert.equal(response.headers.get('x-ratelimit-limit'), '60');
    assert.equal(response.headers.get('x-ratelimit-remaining'), String(60 - count));
    await response.text();
  }
  const readLimit = await request('/dashboard', { headers: { Cookie: cookie } });
  assert.equal(readLimit.status, 429, 'authenticated reads still have a bounded budget');
  assert.equal(readLimit.headers.get('x-ratelimit-limit'), '60');
  await readLimit.text();
});
