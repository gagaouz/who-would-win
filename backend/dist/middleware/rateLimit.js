"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.rateLimitMiddleware = exports.adminRateLimit = exports.diagnosticRateLimit = exports.appAttestRateLimit = exports.publicRateLimit = exports.animalRateLimit = exports.meleeRateLimit = exports.quickRateLimit = exports.battleRateLimit = void 0;
exports.initRateLimitStore = initRateLimitStore;
const crypto_1 = require("crypto");
const database_1 = require("../services/database");
const memory = new Map();
let activeAiRequests = 0;
let tableReady = false;
let tableInitialization = null;
const MAX_ACTIVE_AI = positiveInt(process.env.AI_MAX_CONCURRENT, 4);
function positiveInt(value, fallback) {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}
function clientFingerprint(req) {
    const installId = req.header('x-install-id');
    const validInstallId = installId && /^[0-9a-f-]{36}$/i.test(installId) ? installId : 'no-install';
    const ip = (req.ip ?? req.socket.remoteAddress ?? 'unknown').replace(/^::ffff:/, '');
    const salt = process.env.RATE_LIMIT_SALT ?? process.env.ADMIN_SECRET ?? 'local-development-only';
    return (0, crypto_1.createHmac)('sha256', salt).update(`${ip}:${validInstallId}`).digest('hex');
}
function fixedWindowStart(windowMs) {
    return Math.floor(Date.now() / windowMs) * windowMs;
}
async function initRateLimitStore() {
    if (tableReady)
        return;
    if (tableInitialization)
        return tableInitialization;
    tableInitialization = (async () => {
        const pool = (0, database_1.getDbPool)();
        if (pool) {
            await pool.query(`
        CREATE TABLE IF NOT EXISTS rate_limit_windows (
          profile TEXT NOT NULL,
          fingerprint TEXT NOT NULL,
          window_start TIMESTAMPTZ NOT NULL,
          count INTEGER NOT NULL,
          expires_at TIMESTAMPTZ NOT NULL,
          PRIMARY KEY (profile, fingerprint, window_start)
        )
      `);
        }
        tableReady = true;
    })().finally(() => { tableInitialization = null; });
    return tableInitialization;
}
async function increment(profile, fingerprint) {
    const start = fixedWindowStart(profile.windowMs);
    const memoryKey = `${profile.name}:${start}:${fingerprint}`;
    const pool = (0, database_1.getDbPool)();
    if (!pool) {
        const entry = memory.get(memoryKey);
        const next = (entry?.count ?? 0) + 1;
        memory.set(memoryKey, { count: next, resetAt: start + profile.windowMs });
        return next;
    }
    await initRateLimitStore();
    const result = await pool.query(`INSERT INTO rate_limit_windows (profile, fingerprint, window_start, count, expires_at)
     VALUES ($1, $2, to_timestamp($3 / 1000.0), 1, to_timestamp(($3 + $4) / 1000.0))
     ON CONFLICT (profile, fingerprint, window_start) DO UPDATE
       SET count = rate_limit_windows.count + 1
     RETURNING count`, [profile.name, fingerprint, start, profile.windowMs]);
    return result.rows[0]?.count ?? profile.max + 1;
}
async function allowedByGlobalLimit(profile) {
    if (!profile.globalMax)
        return true;
    const count = await increment({ ...profile, name: `global:${profile.name}`, max: profile.globalMax }, 'global');
    return count <= profile.globalMax;
}
function limiter(profile) {
    return async (req, res, next) => {
        let concurrencyClaimed = false;
        const release = () => {
            if (!concurrencyClaimed)
                return;
            concurrencyClaimed = false;
            activeAiRequests = Math.max(0, activeAiRequests - 1);
        };
        try {
            if (profile.concurrent) {
                if (activeAiRequests >= MAX_ACTIVE_AI) {
                    res.setHeader('Retry-After', '5');
                    res.status(503).json({ error: 'The arena is busy. A local battle will be used.' });
                    return;
                }
                activeAiRequests += 1;
                concurrencyClaimed = true;
                res.once('finish', release);
                res.once('close', release);
            }
            const count = await increment(profile, clientFingerprint(req));
            const globallyAllowed = await allowedByGlobalLimit(profile);
            const remaining = Math.max(0, profile.max - count);
            res.setHeader('X-RateLimit-Limit', profile.max);
            res.setHeader('X-RateLimit-Remaining', remaining);
            if (count > profile.max || !globallyAllowed) {
                release();
                res.setHeader('Retry-After', Math.ceil(profile.windowMs / 1000));
                res.status(429).json({ error: 'Battle limit reached. The app will use a local result.' });
                return;
            }
            next();
        }
        catch (error) {
            release();
            console.error('[rate-limit] shared limiter unavailable:', error.message);
            // Paid routes fail closed. Cheap routes remain available if Postgres has a
            // temporary issue so health/leaderboard traffic does not amplify it.
            if (profile.concurrent || profile.failClosed) {
                res.status(503).json({ error: 'The arena is temporarily using local results.' });
            }
            else {
                next();
            }
        }
    };
}
exports.battleRateLimit = limiter({
    name: 'battle', max: positiveInt(process.env.BATTLE_LIMIT_PER_HOUR, 30),
    windowMs: 60 * 60 * 1000, globalMax: positiveInt(process.env.BATTLE_GLOBAL_PER_HOUR, 2000), concurrent: true,
});
exports.quickRateLimit = limiter({
    name: 'quick', max: positiveInt(process.env.QUICK_LIMIT_PER_HOUR, 90),
    windowMs: 60 * 60 * 1000, globalMax: positiveInt(process.env.QUICK_GLOBAL_PER_HOUR, 5000), concurrent: true,
});
exports.meleeRateLimit = limiter({
    name: 'melee', max: positiveInt(process.env.MELEE_LIMIT_PER_HOUR, 20),
    windowMs: 60 * 60 * 1000, globalMax: positiveInt(process.env.MELEE_GLOBAL_PER_HOUR, 1000), concurrent: true,
});
exports.animalRateLimit = limiter({
    name: 'animal', max: positiveInt(process.env.ANIMAL_LIMIT_PER_HOUR, 20),
    windowMs: 60 * 60 * 1000, globalMax: positiveInt(process.env.ANIMAL_GLOBAL_PER_HOUR, 1000), concurrent: true,
});
exports.publicRateLimit = limiter({
    name: 'public', max: positiveInt(process.env.PUBLIC_LIMIT_PER_HOUR, 300),
    windowMs: 60 * 60 * 1000,
});
// Key enrollment is cheap but writes short-lived rows to Postgres. Give it a
// dedicated shared ceiling so a distributed client cannot turn the defensive
// endpoint itself into unbounded database growth.
exports.appAttestRateLimit = limiter({
    name: 'app-attest', max: positiveInt(process.env.APP_ATTEST_LIMIT_PER_HOUR, 120),
    windowMs: 60 * 60 * 1000,
    globalMax: positiveInt(process.env.APP_ATTEST_GLOBAL_PER_HOUR, 10000),
    failClosed: true,
});
exports.diagnosticRateLimit = limiter({
    name: 'diagnostic', max: 5, windowMs: 60 * 60 * 1000,
});
exports.adminRateLimit = limiter({
    name: 'admin', max: 10, windowMs: 15 * 60 * 1000,
});
// Backward-compatible name for any route not yet assigned a profile.
exports.rateLimitMiddleware = exports.publicRateLimit;
setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of memory)
        if (entry.resetAt <= now)
            memory.delete(key);
    const pool = (0, database_1.getDbPool)();
    if (pool)
        void pool.query('DELETE FROM rate_limit_windows WHERE expires_at < NOW()').catch(() => undefined);
}, 10 * 60 * 1000).unref();
