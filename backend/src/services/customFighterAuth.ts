import { Router, Request, Response, NextFunction } from 'express';
import { createHash, randomBytes, randomUUID, createPublicKey, verify } from 'crypto';
import { readFileSync } from 'fs';
import { join } from 'path';
import { Pool } from 'pg';
import { SignedDataVerifier, Environment, JWSTransactionDecodedPayload, AppStoreServerAPIClient } from '@apple/app-store-server-library';
import { getDbPool } from './database';

const BUNDLE = 'com.whowouldin.WhoWouldWin';
const APP_ID = 6761319389;
const PREMIUM = new Set(['com.whowouldin.premium.monthly', 'com.whowouldin.premium.annual']);
const sha = (value: string) => createHash('sha256').update(value).digest('hex');
export class CustomFighterAuthError extends Error {
  constructor(public status: number, public code: string, message: string) { super(message); }
}
const unavailable = () => new CustomFighterAuthError(503, 'account_unavailable', 'Your fighter library is temporarily unavailable.');
const invalid = () => new CustomFighterAuthError(401, 'sign_in_required', 'Please sign in again to open your fighter library.');
const subscriptionRequired = () => new CustomFighterAuthError(403, 'subscription_required', 'An active Premium subscription is needed to create new artwork.');

declare global { namespace Express { interface Request { customFighterOwner?: { id: string; libraryEpoch: number; sessionHash: string }; } } }
type AppleClaims = { iss: string; aud: string; sub: string; exp: number; iat: number; nonce: string };
type JWK = { kty: string; kid: string; alg?: string; use?: string; n?: string; e?: string };
let keyCache: { keys: JWK[]; expires: number } | undefined;

/** No claims are trusted before signature verification. Remote keys have one fixed origin. */
export async function verifyAppleIdentity(token: string, nonceHash: string, now = Date.now(), suppliedKeys?: JWK[]): Promise<AppleClaims> {
  if (typeof token !== 'string' || token.length > 12000) throw invalid();
  const pieces = token.split('.');
  if (pieces.length !== 3 || pieces.some(p => !/^[A-Za-z0-9_-]+$/.test(p))) throw invalid();
  let header: { alg?: string; kid?: string }; let claims: AppleClaims;
  try {
    header = JSON.parse(Buffer.from(pieces[0], 'base64url').toString());
    claims = JSON.parse(Buffer.from(pieces[1], 'base64url').toString());
  } catch { throw invalid(); }
  if (header.alg !== 'RS256' || !header.kid) throw invalid();
  let keys = suppliedKeys;
  if (!keys) {
    if (!keyCache || keyCache.expires <= now || !keyCache.keys.some(k => k.kid === header.kid)) {
      const response = await fetch('https://appleid.apple.com/auth/keys', { signal: AbortSignal.timeout(10000), redirect: 'error' });
      if (!response.ok) throw unavailable();
      const text = await response.text();
      if (text.length > 32768) throw unavailable();
      const body = JSON.parse(text) as { keys?: JWK[] };
      if (!Array.isArray(body.keys) || body.keys.length > 20) throw unavailable();
      keyCache = { keys: body.keys, expires: now + 3600000 };
    }
    keys = keyCache.keys;
  }
  const jwk = keys.find(k => k.kid === header.kid && k.kty === 'RSA' && (!k.alg || k.alg === 'RS256') && (!k.use || k.use === 'sig'));
  if (!jwk) throw invalid();
  try {
    const key = createPublicKey({ key: jwk, format: 'jwk' });
    if (!verify('RSA-SHA256', Buffer.from(pieces[0] + '.' + pieces[1]), key, Buffer.from(pieces[2], 'base64url'))) throw invalid();
  } catch { throw invalid(); }
  if (claims.iss !== 'https://appleid.apple.com' || claims.aud !== BUNDLE
      || typeof claims.sub !== 'string' || claims.sub.length < 4 || claims.sub.length > 256
      || !Number.isFinite(claims.exp) || claims.exp * 1000 <= now
      || !Number.isFinite(claims.iat) || claims.iat * 1000 > now + 60000 || claims.iat * 1000 < now - 600000
      || claims.nonce !== nonceHash) throw invalid();
  return claims;
}

export function customFighterOwnerID(subject: string): string {
  const digest = sha(BUNDLE + ':private-fighter-library:apple:' + subject);
  return `${digest.slice(0, 8)}-${digest.slice(8, 12)}-5${digest.slice(13, 16)}-a${digest.slice(17, 20)}-${digest.slice(20, 32)}`;
}

const schema = `
CREATE TABLE IF NOT EXISTS custom_fighter_accounts (
 id UUID PRIMARY KEY, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), deleted_at TIMESTAMPTZ, library_epoch BIGINT NOT NULL DEFAULT 1
);
ALTER TABLE custom_fighter_accounts ADD COLUMN IF NOT EXISTS library_epoch BIGINT NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS custom_fighter_auth_challenges (
 id UUID PRIMARY KEY, nonce_hash TEXT NOT NULL, expires_at TIMESTAMPTZ NOT NULL, used BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE IF NOT EXISTS custom_fighter_sessions (
 token_hash TEXT PRIMARY KEY, owner_id UUID NOT NULL REFERENCES custom_fighter_accounts(id), expires_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS custom_fighter_subscriptions (
 original_id TEXT NOT NULL, environment TEXT NOT NULL, owner_id UUID,
 expires_at TIMESTAMPTZ NOT NULL, signed_at BIGINT NOT NULL, revoked BOOLEAN NOT NULL DEFAULT FALSE,
 PRIMARY KEY(original_id, environment)
);
CREATE TABLE IF NOT EXISTS custom_fighter_auth_rates (
 key TEXT PRIMARY KEY, window_start BIGINT NOT NULL, count INTEGER NOT NULL
);`;
let initPromise: Promise<void> | undefined;
export async function initCustomFighterAuth(pool = getDbPool()): Promise<void> {
  if (!pool) throw unavailable();
  await pool.query(schema);
}
async function database(): Promise<Pool> {
  const pool = getDbPool(); if (!pool) throw unavailable();
  if (!initPromise) initPromise = initCustomFighterAuth(pool).catch(e => { initPromise = undefined; throw e; });
  await initPromise; return pool;
}

export async function requireCustomFighterOwner(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const token = req.headers.authorization?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
    if (!token) throw invalid();
    const db = await database();
    const sessionHash = sha(token);
    const result = await db.query(`SELECT s.owner_id, a.library_epoch FROM custom_fighter_sessions s JOIN custom_fighter_accounts a ON a.id=s.owner_id
      WHERE s.token_hash=$1 AND s.expires_at>NOW() AND a.deleted_at IS NULL`, [sha(token)]);
    if (!result.rows.length) throw invalid();
    const libraryEpoch = Number(result.rows[0].library_epoch);
    if (!Number.isSafeInteger(libraryEpoch) || libraryEpoch < 1) throw unavailable();
    req.customFighterOwner = { id: result.rows[0].owner_id, libraryEpoch, sessionHash }; next();
  } catch (e) { authError(res, e); }
}
function authError(res: Response, error: unknown): void {
  const e = error instanceof CustomFighterAuthError ? error : unavailable();
  res.status(e.status).json({ code: e.code, error: e.message });
}

let verifiers: Map<Environment, SignedDataVerifier> | undefined;
function appleVerifier(environment: Environment): SignedDataVerifier {
  if (!verifiers) verifiers = new Map();
  let verifier = verifiers.get(environment);
  if (!verifier) {
    const roots = ['AppleRootCA-G2.cer', 'AppleRootCA-G3.cer'].map(n => readFileSync(join(__dirname, '../../resources/apple', n)));
    verifier = new SignedDataVerifier(roots, true, environment, BUNDLE, APP_ID);
    verifiers.set(environment, verifier);
  }
  return verifier;
}
async function decodeTransaction(signed: string): Promise<JWSTransactionDecodedPayload> {
  if (typeof signed !== 'string' || signed.length < 100 || signed.length > 24000) throw subscriptionRequired();
  const environments = process.env.SPRITE_ALLOW_SANDBOX === 'true'
    ? [Environment.PRODUCTION, Environment.SANDBOX] : [Environment.PRODUCTION];
  for (const environment of environments) {
    try { return await appleVerifier(environment).verifyAndDecodeTransaction(signed); } catch { /* Try only explicitly allowed Apple environments. */ }
  }
  throw new CustomFighterAuthError(403, 'subscription_unverified', 'Your subscription could not be verified. Please restore purchases and try again.');
}

export function validateCustomFighterSubscription(tx: JWSTransactionDecodedPayload, ownerID: string, now = Date.now()) {
  if (tx.bundleId !== BUNDLE || !PREMIUM.has(tx.productId ?? '') || !tx.originalTransactionId
      || !tx.transactionId || !tx.expiresDate || tx.expiresDate <= now || tx.revocationDate
      || !tx.signedDate || tx.signedDate > now + 60000
      || (tx.environment !== Environment.PRODUCTION && tx.environment !== Environment.SANDBOX)) throw subscriptionRequired();
  if (tx.inAppOwnershipType === 'FAMILY_SHARED')
    throw new CustomFighterAuthError(403, 'family_sharing_unavailable', 'This artwork beta currently requires the subscription purchaser. Your other Premium features are unchanged.');
  if (tx.appAccountToken && tx.appAccountToken.toLowerCase() !== ownerID.toLowerCase())
    throw new CustomFighterAuthError(409, 'subscription_owner_mismatch', 'This subscription is connected to a different fighter library.');
  // Fixed UTC monthly allowance does not multiply on accelerated sandbox renewals or on product switches.
  const date = new Date(now);
  return { periodKey: `${tx.environment}:${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`,
    environment: tx.environment as 'Sandbox' | 'Production', expiresAt: new Date(tx.expiresDate).toISOString() };
}

export async function requireCustomFighterSubscription(ownerID: string, signedTransaction: string) {
  let tx = await decodeTransaction(signedTransaction);
  const privateKey = process.env.SPRITE_APPLE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  const keyID = process.env.SPRITE_APPLE_KEY_ID;
  const issuerID = process.env.SPRITE_APPLE_ISSUER_ID;
  // Production cannot spend on stale client receipts. Beta sandbox uses verified short-lived transactions + notifications.
  if (tx.environment === Environment.PRODUCTION && !(privateKey && keyID && issuerID))
    throw new CustomFighterAuthError(503, 'subscription_service_unavailable', 'Artwork creation is not available for this subscription yet.');
  if (privateKey && keyID && issuerID && tx.transactionId) {
    try {
      const client = new AppStoreServerAPIClient(privateKey, keyID, issuerID, BUNDLE, tx.environment as Environment);
      const latest = await client.getTransactionInfo(tx.transactionId);
      if (!latest.signedTransactionInfo) throw unavailable();
      tx = await decodeTransaction(latest.signedTransactionInfo);
    } catch { throw new CustomFighterAuthError(503, 'subscription_service_unavailable', 'Apple subscription verification is temporarily unavailable.'); }
  }
  const info = validateCustomFighterSubscription(tx, ownerID);
  const db = await database(); const client = await db.connect();
  try {
    await client.query('BEGIN');
    await client.query(`INSERT INTO custom_fighter_subscriptions(original_id,environment,owner_id,expires_at,signed_at,revoked)
      VALUES($1,$2,$3,$4,$5,false) ON CONFLICT(original_id,environment) DO NOTHING`,
      [tx.originalTransactionId, tx.environment, ownerID, info.expiresAt, tx.signedDate]);
    const existing = (await client.query(`SELECT * FROM custom_fighter_subscriptions WHERE original_id=$1 AND environment=$2 FOR UPDATE`,
      [tx.originalTransactionId, tx.environment])).rows[0];
    if (existing.owner_id && existing.owner_id !== ownerID)
      throw new CustomFighterAuthError(409, 'subscription_owner_mismatch', 'This subscription is connected to another fighter library.');
    if (existing.revoked) throw subscriptionRequired();
    if (Number(existing.signed_at) > tx.signedDate! && new Date(existing.expires_at).getTime() <= Date.now()) throw subscriptionRequired();
    // Notifications may have created a newer receipt before this owner's first claim.
    // Bind it without overwriting the fresher expiry/revocation observation.
    await client.query(`UPDATE custom_fighter_subscriptions SET owner_id=$3 WHERE original_id=$1 AND environment=$2 AND owner_id IS NULL`,
      [tx.originalTransactionId, tx.environment, ownerID]);
    await client.query(`UPDATE custom_fighter_subscriptions SET owner_id=$3, expires_at=$4, signed_at=$5
      WHERE original_id=$1 AND environment=$2 AND signed_at <= $5`,
      [tx.originalTransactionId, tx.environment, ownerID, info.expiresAt, tx.signedDate]);
    await client.query('COMMIT'); return info;
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}

export function createCustomFighterAuthRouter(options: { deleteOwnerData: (id: string) => Promise<unknown> }) {
  const router = Router();
  const limited = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const db = await database(); const window = Math.floor(Date.now() / 60000);
      const key = sha('custom-auth:' + (req.ip ?? 'unknown'));
      const result = await db.query(`INSERT INTO custom_fighter_auth_rates(key,window_start,count) VALUES($1,$2,1)
        ON CONFLICT(key) DO UPDATE SET count=CASE WHEN custom_fighter_auth_rates.window_start=$2 THEN custom_fighter_auth_rates.count+1 ELSE 1 END,
        window_start=$2 RETURNING count`, [key, window]);
      if (result.rows[0].count > 15) throw new CustomFighterAuthError(429, 'try_later', 'Please wait a minute and try again.');
      next();
    } catch (e) { authError(res, e); }
  };
  router.post('/challenge', limited, async (_req, res) => {
    try {
      const db = await database(); const nonce = randomBytes(32).toString('base64url'); const id = randomUUID();
      const expiresAt = new Date(Date.now() + 300000).toISOString();
      await db.query('DELETE FROM custom_fighter_auth_challenges WHERE expires_at<NOW()');
      await db.query('DELETE FROM custom_fighter_sessions WHERE expires_at<NOW()');
      await db.query('DELETE FROM custom_fighter_auth_rates WHERE window_start<$1', [Math.floor(Date.now() / 60000) - 60]);
      await db.query('INSERT INTO custom_fighter_auth_challenges(id,nonce_hash,expires_at) VALUES($1,$2,$3)', [id, sha(nonce), expiresAt]);
      res.json({ challengeID: id, nonce, expiresAt });
    } catch (e) { authError(res, e); }
  });
  router.post('/apple', limited, async (req, res) => {
    try {
      const { challengeID, identityToken } = req.body ?? {};
      if (typeof challengeID !== 'string' || !/^[a-f0-9-]{36}$/i.test(challengeID)) throw invalid();
      const db = await database();
      const challenge = (await db.query('SELECT nonce_hash FROM custom_fighter_auth_challenges WHERE id=$1 AND used=false AND expires_at>NOW()', [challengeID])).rows[0];
      if (!challenge) throw invalid();
      const claims = await verifyAppleIdentity(identityToken, challenge.nonce_hash);
      const id = customFighterOwnerID(claims.sub); const token = randomBytes(32).toString('base64url');
      const expiresAt = new Date(Date.now() + 7 * 86400000).toISOString();
      const client = await db.connect();
      try {
        // A session-level owner lock spans the purge's own transaction, without
        // holding account row locks needed by the generation/deletion store.
        await client.query('SELECT pg_advisory_lock(hashtextextended($1,0))', ['fighter-auth:' + id]);
        const oldAccount = (await client.query('SELECT deleted_at FROM custom_fighter_accounts WHERE id=$1', [id])).rows[0];
        if (oldAccount?.deleted_at) await options.deleteOwnerData(id);
        await client.query('BEGIN');
        const consumed = await client.query('UPDATE custom_fighter_auth_challenges SET used=true WHERE id=$1 AND used=false AND expires_at>NOW() RETURNING id', [challengeID]);
        if (!consumed.rowCount) throw invalid();
        await client.query('INSERT INTO custom_fighter_accounts(id) VALUES($1) ON CONFLICT(id) DO UPDATE SET deleted_at=NULL', [id]);
        await client.query('INSERT INTO custom_fighter_sessions(token_hash,owner_id,expires_at) VALUES($1,$2,$3)', [sha(token), id, expiresAt]);
        await client.query('COMMIT');
      } catch (e) { await client.query('ROLLBACK'); throw e; } finally {
        try { await client.query('SELECT pg_advisory_unlock(hashtextextended($1,0))', ['fighter-auth:' + id]); }
        finally { client.release(); }
      }
      res.json({ accountID: id, sessionToken: token, expiresAt });
    } catch (e) { authError(res, e); }
  });
  router.post('/signout', requireCustomFighterOwner, async (req, res) => {
    try { const db = await database(); await db.query('DELETE FROM custom_fighter_sessions WHERE token_hash=$1', [sha(req.headers.authorization!.slice(7))]); res.sendStatus(204); }
    catch (e) { authError(res, e); }
  });
  router.delete('/account', requireCustomFighterOwner, async (req, res) => {
    try {
      const db = await database(); const id = req.customFighterOwner!.id;
      const client = await db.connect();
      try {
        await client.query('SELECT pg_advisory_lock(hashtextextended($1,0))', ['fighter-auth:' + id]);
        // Authentication can precede a slow owner lock. A pre-deletion request
        // must never erase a newly reactivated library or its new sessions.
        const current = await client.query(`SELECT 1 FROM custom_fighter_sessions s
          JOIN custom_fighter_accounts a ON a.id=s.owner_id WHERE s.token_hash=$1
          AND s.owner_id=$2 AND s.expires_at>NOW() AND a.deleted_at IS NULL AND a.library_epoch=$3`,
          [req.customFighterOwner!.sessionHash, id, req.customFighterOwner!.libraryEpoch]);
        if (!current.rowCount) throw invalid();
        // Interrupted deletion remains tombstoned; fresh Apple auth resumes the purge.
        await client.query('UPDATE custom_fighter_accounts SET deleted_at=NOW(), library_epoch=library_epoch+1 WHERE id=$1', [id]);
        await client.query('DELETE FROM custom_fighter_sessions WHERE owner_id=$1', [id]);
        await options.deleteOwnerData(id); res.sendStatus(204);
      } finally {
        try { await client.query('SELECT pg_advisory_unlock(hashtextextended($1,0))', ['fighter-auth:' + id]); }
        finally { client.release(); }
      }
    } catch (e) { authError(res, e); }
  });
  router.post('/subscription-notifications', async (req, res) => {
    try {
      const signed = req.body?.signedPayload;
      if (typeof signed !== 'string' || signed.length > 28000) throw invalid();
      let decoded;
      for (const env of [Environment.PRODUCTION, ...(process.env.SPRITE_ALLOW_SANDBOX === 'true' ? [Environment.SANDBOX] : [])]) {
        try { decoded = await appleVerifier(env).verifyAndDecodeNotification(signed); break; } catch { /* No unsigned fallback. */ }
      }
      if (!decoded) throw invalid();
      if (decoded.data?.signedTransactionInfo) {
        const tx = await decodeTransaction(decoded.data.signedTransactionInfo);
        if (tx.originalTransactionId && tx.environment && tx.signedDate && PREMIUM.has(tx.productId ?? '')) {
          const db = await database();
          await db.query(`INSERT INTO custom_fighter_subscriptions(original_id,environment,expires_at,signed_at,revoked)
            VALUES($1,$2,$3,$4,$5) ON CONFLICT(original_id,environment) DO UPDATE SET expires_at=$3,signed_at=$4,revoked=$5
            WHERE custom_fighter_subscriptions.signed_at <= $4`,
            [tx.originalTransactionId, tx.environment, new Date(tx.expiresDate ?? 0).toISOString(), tx.signedDate,
              !!tx.revocationDate || ['REFUND', 'REVOKE'].includes(decoded.notificationType ?? '')]);
        }
      }
      res.sendStatus(200);
    } catch (e) { authError(res, e); }
  });
  return router;
}
