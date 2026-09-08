"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAppAttest = void 0;
exports.initAppAttest = initAppAttest;
const crypto_1 = require("crypto");
const express_1 = require("express");
const rateLimit_1 = require("../middleware/rateLimit");
const database_1 = require("./database");
const importEsm = new Function('specifier', 'return import(specifier)');
const router = (0, express_1.Router)();
const CHALLENGE_TTL_MS = 5 * 60 * 1000;
let initialized = false;
let initialization = null;
function challengeHash(challenge) {
    return (0, crypto_1.createHash)('sha256').update(challenge).digest('hex');
}
function appInfo() {
    const teamIdentifier = process.env.APP_ATTEST_TEAM_ID
        ?? process.env.APPLE_TEAM_ID ?? '8U69B876XS';
    const bundleIdentifier = process.env.APP_ATTEST_BUNDLE_ID
        ?? process.env.APPLE_BUNDLE_ID ?? 'com.whowouldin.WhoWouldWin';
    return {
        teamIdentifier,
        bundleIdentifier,
        appId: `${teamIdentifier}.${bundleIdentifier}`,
        allowDevelopmentEnvironment: process.env.NODE_ENV !== 'production'
            || process.env.APP_ATTEST_ALLOW_DEVELOPMENT === 'true',
    };
}
async function initAppAttest() {
    if (initialized)
        return;
    if (initialization)
        return initialization;
    initialization = (async () => {
        const pool = (0, database_1.getDbPool)();
        if (pool) {
            await pool.query(`
        CREATE TABLE IF NOT EXISTS app_attest_challenges (
          challenge_hash TEXT PRIMARY KEY,
          expires_at TIMESTAMPTZ NOT NULL
        );
        CREATE TABLE IF NOT EXISTS app_attest_keys (
          key_id TEXT PRIMARY KEY,
          public_key TEXT NOT NULL,
          sign_count BIGINT NOT NULL DEFAULT 0,
          environment TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
      `);
            const pruneChallenges = () => pool.query('DELETE FROM app_attest_challenges WHERE expires_at < NOW()').catch(() => undefined);
            const pruneKeys = () => pool.query("DELETE FROM app_attest_keys WHERE last_seen_at < NOW() - INTERVAL '180 days'").catch(() => undefined);
            void pruneChallenges();
            void pruneKeys();
            setInterval(() => { void pruneChallenges(); }, 10 * 60 * 1000).unref();
            setInterval(() => { void pruneKeys(); }, 24 * 60 * 60 * 1000).unref();
        }
        initialized = true;
    })().finally(() => { initialization = null; });
    return initialization;
}
async function consumeChallenge(challenge) {
    const pool = (0, database_1.getDbPool)();
    if (!pool)
        return false;
    await initAppAttest();
    const result = await pool.query(`DELETE FROM app_attest_challenges
      WHERE challenge_hash = $1 AND expires_at > NOW()
      RETURNING challenge_hash`, [challengeHash(challenge)]);
    return (result.rowCount ?? 0) === 1;
}
router.post('/attest/challenge', rateLimit_1.appAttestRateLimit, async (_req, res) => {
    const pool = (0, database_1.getDbPool)();
    if (!pool) {
        res.status(503).json({ error: 'Attestation is temporarily unavailable.' });
        return;
    }
    try {
        await initAppAttest();
        const challenge = (0, crypto_1.randomBytes)(32).toString('base64url');
        await pool.query(`INSERT INTO app_attest_challenges (challenge_hash, expires_at)
       VALUES ($1, NOW() + ($2 * INTERVAL '1 millisecond'))`, [challengeHash(challenge), CHALLENGE_TTL_MS]);
        res.json({ challenge });
    }
    catch (error) {
        console.error('[app-attest] challenge failed:', error.message);
        res.status(503).json({ error: 'Attestation is temporarily unavailable.' });
    }
});
router.post('/attest/register', rateLimit_1.appAttestRateLimit, async (req, res) => {
    const body = req.body;
    const keyId = body?.['keyId'];
    const challenge = body?.['challenge'];
    const attestation = body?.['attestation'];
    if (typeof keyId !== 'string' || keyId.length > 200
        || typeof challenge !== 'string' || challenge.length > 200
        || typeof attestation !== 'string' || attestation.length > 20000) {
        res.status(400).json({ error: 'Invalid attestation payload.' });
        return;
    }
    try {
        if (!await consumeChallenge(challenge)) {
            res.status(401).json({ error: 'Invalid or expired challenge.' });
            return;
        }
        const { verifyAttestation } = await importEsm('node-app-attest');
        const info = appInfo();
        const verified = verifyAttestation({
            attestation: Buffer.from(attestation, 'base64'),
            challenge,
            keyId,
            bundleIdentifier: info.bundleIdentifier,
            teamIdentifier: info.teamIdentifier,
            allowDevelopmentEnvironment: info.allowDevelopmentEnvironment,
        });
        const pool = (0, database_1.getDbPool)();
        if (!pool)
            throw new Error('database unavailable');
        await pool.query(`INSERT INTO app_attest_keys (key_id, public_key, sign_count, environment)
       VALUES ($1, $2, 0, $3)
       ON CONFLICT (key_id) DO UPDATE
         SET public_key = EXCLUDED.public_key,
             sign_count = 0,
             environment = EXCLUDED.environment,
             last_seen_at = NOW()`, [keyId, String(verified.publicKey), verified.environment]);
        res.status(204).send();
    }
    catch (error) {
        console.error('[app-attest] registration rejected:', error.message);
        res.status(401).json({ error: 'Attestation verification failed.' });
    }
});
const requireAppAttest = async (req, res, next) => {
    const encoded = req.header('x-app-attest');
    const enforce = process.env.APP_ATTEST_ENFORCE === 'true';
    if (!encoded) {
        if (enforce) {
            res.status(401).json({ error: 'A valid app attestation is required.' });
            return;
        }
        res.setHeader('X-App-Attest-Status', 'legacy');
        next();
        return;
    }
    try {
        const auth = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
        const keyId = auth['keyId'];
        const assertion = auth['assertion'];
        const challenge = req.body?.['attestChallenge'];
        if (typeof keyId !== 'string' || keyId.length > 200
            || typeof assertion !== 'string' || assertion.length > 10000
            || typeof challenge !== 'string' || challenge.length > 200
            || !await consumeChallenge(challenge)) {
            throw new Error('invalid assertion envelope');
        }
        const pool = (0, database_1.getDbPool)();
        if (!pool)
            throw new Error('database unavailable');
        const record = await pool.query('SELECT public_key, sign_count FROM app_attest_keys WHERE key_id = $1', [keyId]);
        const key = record.rows[0];
        if (!key)
            throw new Error('unknown attestation key');
        const rawBody = req.rawBody;
        if (!rawBody)
            throw new Error('raw request body unavailable');
        const clientDataHash = (0, crypto_1.createHash)('sha256').update(rawBody).digest();
        const { verifyAssertion } = await importEsm('node-app-attest');
        const verified = verifyAssertion({
            assertion: Buffer.from(assertion, 'base64'),
            payload: rawBody,
            publicKey: key.public_key,
            bundleIdentifier: appInfo().bundleIdentifier,
            teamIdentifier: appInfo().teamIdentifier,
            signCount: Number(key.sign_count),
            clientDataHash,
        });
        if (verified.signCount <= Number(key.sign_count))
            throw new Error('replayed assertion');
        const updated = await pool.query(`UPDATE app_attest_keys SET sign_count = $2, last_seen_at = NOW()
        WHERE key_id = $1 AND sign_count < $2 RETURNING key_id`, [keyId, verified.signCount]);
        if ((updated.rowCount ?? 0) !== 1)
            throw new Error('assertion counter race');
        res.setHeader('X-App-Attest-Status', 'verified');
        next();
    }
    catch (error) {
        console.warn('[app-attest] assertion rejected:', error.message);
        res.status(401).json({ error: 'App assertion verification failed.' });
    }
};
exports.requireAppAttest = requireAppAttest;
exports.default = router;
