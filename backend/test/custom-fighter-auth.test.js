const test = require('node:test');
const assert = require('node:assert/strict');
const { generateKeyPairSync, sign, createHash } = require('node:crypto');
const { verifyAppleIdentity, customFighterOwnerID, validateCustomFighterSubscription, initCustomFighterAuth } = require('../dist/services/customFighterAuth');
const { newDb } = require('pg-mem');
const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: 'jwk' }), kid: 'test-apple-key', alg: 'RS256', use: 'sig' };
const now = Date.UTC(2026, 8, 26, 22);
const nonce = createHash('sha256').update('server-challenge').digest('hex');
const claims = { iss: 'https://appleid.apple.com', aud: 'com.whowouldin.WhoWouldWin', sub: 'apple-user-123',
  exp: now / 1000 + 300, iat: now / 1000, nonce };
function jwt(overrides = {}, headerOverrides = {}) {
  const encode = object => Buffer.from(JSON.stringify(object)).toString('base64url');
  const body = encode({ alg: 'RS256', kid: jwk.kid, ...headerOverrides }) + '.' + encode({ ...claims, ...overrides });
  return body + '.' + sign('RSA-SHA256', Buffer.from(body), privateKey).toString('base64url');
}
test('Apple identity verifies signature, exact audience and one-time challenge hash', async () => {
  assert.equal((await verifyAppleIdentity(jwt(), nonce, now, [jwk])).sub, claims.sub);
  for (const fields of [{ aud: 'attacker-app' }, { iss: 'https://evil.example' }, { nonce: 'other-challenge' },
    { exp: now / 1000 }, { iat: now / 1000 + 61 }, { iat: now / 1000 - 601 }, { sub: '' }]) {
    await assert.rejects(verifyAppleIdentity(jwt(fields), nonce, now, [jwk]), e => e.status === 401);
  }
  await assert.rejects(verifyAppleIdentity(jwt({}, { alg: 'none' }), nonce, now, [jwk]));
  await assert.rejects(verifyAppleIdentity(jwt(), nonce, now, [{ ...jwk, kid: 'different-key' }]));
  const parts = jwt().split('.');
  parts[1] = Buffer.from(JSON.stringify({ ...claims, sub: 'other-person' })).toString('base64url');
  await assert.rejects(verifyAppleIdentity(parts.join('.'), nonce, now, [jwk]));
});
test('Malformed and oversized identity credentials fail closed', async () => {
  for (const token of [undefined, '', 'a.b.c', 'x'.repeat(12001), jwt().replace('.', '\n.')]) {
    await assert.rejects(verifyAppleIdentity(token, nonce, now, [jwk]));
  }
});
test('Private owner identity is stable without storing Apple subject or email', () => {
  const id = customFighterOwnerID(claims.sub);
  assert.match(id, /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-a[0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(id, customFighterOwnerID(claims.sub));
  assert.notEqual(id, customFighterOwnerID('another-apple-user'));
  assert.ok(!id.includes(claims.sub));
});
const owner = customFighterOwnerID(claims.sub);
const transaction = { bundleId: 'com.whowouldin.WhoWouldWin', productId: 'com.whowouldin.premium.monthly',
  originalTransactionId: '1001', transactionId: '1002', expiresDate: now + 3600000,
  signedDate: now, environment: 'Sandbox', appAccountToken: owner };
test('Only current Premium proof for the same library can create artwork', () => {
  const valid = validateCustomFighterSubscription(transaction, owner, now);
  assert.equal(valid.periodKey, 'Sandbox:2026-09');
  for (const bad of [{ productId: 'com.whowouldin.everythingbundle' }, { bundleId: 'other' },
    { revocationDate: now - 1 }, { expiresDate: now }, { signedDate: now + 61000 },
    { environment: 'Xcode' }, { inAppOwnershipType: 'FAMILY_SHARED' }, { originalTransactionId: '' }, { transactionId: '' }, { appAccountToken: customFighterOwnerID('another') }]) {
    assert.throws(() => validateCustomFighterSubscription({ ...transaction, ...bad }, owner, now));
  }
});
test('Renewals, annual upgrades and sandbox acceleration share one calendar-month allowance', () => {
  const first = validateCustomFighterSubscription(transaction, owner, now);
  const annual = validateCustomFighterSubscription({ ...transaction, productId: 'com.whowouldin.premium.annual',
    transactionId: '1003', expiresDate: now + 365 * 86400000 }, owner, now + 1000);
  assert.equal(first.periodKey, annual.periodKey);
  const production = validateCustomFighterSubscription({ ...transaction, environment: 'Production' }, owner, now);
  assert.notEqual(first.periodKey, production.periodKey);
});
test('Auth schema supports durable sessions and unique receipt ownership', async () => {
  const memory = newDb(); const { Pool } = memory.adapters.createPg(); const pool = new Pool();
  await initCustomFighterAuth(pool);
  await pool.query('INSERT INTO custom_fighter_accounts(id) VALUES($1)', [owner]);
  await pool.query('INSERT INTO custom_fighter_sessions(token_hash,owner_id,expires_at) VALUES($1,$2,$3)', ['hashed-only', owner, new Date(now)]);
  assert.equal((await pool.query('SELECT * FROM custom_fighter_sessions')).rows[0].token_hash, 'hashed-only');
  await pool.query('INSERT INTO custom_fighter_subscriptions(original_id,environment,owner_id,expires_at,signed_at) VALUES($1,$2,$3,$4,$5)',
    ['receipt', 'Sandbox', owner, new Date(now), now]);
  await assert.rejects(pool.query('INSERT INTO custom_fighter_subscriptions(original_id,environment,owner_id,expires_at,signed_at) VALUES($1,$2,$3,$4,$5)',
    ['receipt', 'Sandbox', owner, new Date(now), now]));
  await pool.end();
});
