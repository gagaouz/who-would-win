"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.initResponseStore = initResponseStore;
exports.cachedOperation = cachedOperation;
exports.isValidRequestId = isValidRequestId;
exports.idempotentOperation = idempotentOperation;
const crypto_1 = require("crypto");
const database_1 = require("./database");
const memory = new Map();
const inFlight = new Map();
const MAX_MEMORY_ENTRIES = 1000;
let initialized = false;
let initialization = null;
function digest(namespace, key) {
    return (0, crypto_1.createHash)('sha256').update(`${namespace}:${JSON.stringify(key)}`).digest('hex');
}
async function initResponseStore() {
    if (initialized)
        return;
    if (initialization)
        return initialization;
    initialization = (async () => {
        const pool = (0, database_1.getDbPool)();
        if (pool) {
            await pool.query(`
        CREATE TABLE IF NOT EXISTS response_cache (
          cache_key TEXT PRIMARY KEY,
          value JSONB NOT NULL,
          expires_at TIMESTAMPTZ NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS response_cache_expires_idx ON response_cache(expires_at);
      `);
            void pool.query('DELETE FROM response_cache WHERE expires_at < NOW()').catch(() => undefined);
            setInterval(() => {
                void pool.query('DELETE FROM response_cache WHERE expires_at < NOW()').catch(() => undefined);
            }, 60 * 60 * 1000).unref();
        }
        initialized = true;
    })().finally(() => { initialization = null; });
    return initialization;
}
async function read(key) {
    const local = memory.get(key);
    if (local && local.expiresAt > Date.now())
        return local.value;
    if (local)
        memory.delete(key);
    const pool = (0, database_1.getDbPool)();
    if (!pool)
        return null;
    await initResponseStore();
    const result = await pool.query('SELECT value FROM response_cache WHERE cache_key = $1 AND expires_at > NOW()', [key]);
    return result.rows[0]?.value ?? null;
}
async function write(key, value, ttlMs) {
    if (memory.size >= MAX_MEMORY_ENTRIES) {
        const oldest = memory.keys().next().value;
        if (oldest)
            memory.delete(oldest);
    }
    memory.set(key, { value, expiresAt: Date.now() + ttlMs });
    const pool = (0, database_1.getDbPool)();
    if (!pool)
        return;
    await initResponseStore();
    await pool.query(`INSERT INTO response_cache (cache_key, value, expires_at)
     VALUES ($1, $2::jsonb, NOW() + ($3 * INTERVAL '1 millisecond'))
     ON CONFLICT (cache_key) DO UPDATE
       SET value = EXCLUDED.value, expires_at = EXCLUDED.expires_at, created_at = NOW()`, [key, JSON.stringify(value), ttlMs]);
}
async function cachedOperation(namespace, cacheInput, ttlMs, operation) {
    const key = digest(namespace, cacheInput);
    try {
        const cached = await read(key);
        if (cached !== null)
            return { value: cached, cacheHit: true };
    }
    catch (error) {
        console.error('[response-store] read failed:', error.message);
    }
    const existing = inFlight.get(key);
    if (existing) {
        const joined = await existing;
        return { value: joined.value, cacheHit: true };
    }
    const pending = (async () => {
        const pool = (0, database_1.getDbPool)();
        if (!pool) {
            const value = await operation();
            await write(key, value, ttlMs);
            return { value, cacheHit: false };
        }
        await initResponseStore();
        const db = await pool.connect();
        try {
            // One generator for this key across every Railway replica. Followers wait,
            // then read the result written by the leader instead of billing twice.
            await db.query('SELECT pg_advisory_lock(hashtextextended($1, 0))', [key]);
            const cached = await db.query('SELECT value FROM response_cache WHERE cache_key = $1 AND expires_at > NOW()', [key]);
            const afterLock = cached.rows[0]?.value;
            if (afterLock !== undefined)
                return { value: afterLock, cacheHit: true };
            const value = await operation();
            await db.query(`INSERT INTO response_cache (cache_key, value, expires_at)
         VALUES ($1, $2::jsonb, NOW() + ($3 * INTERVAL '1 millisecond'))
         ON CONFLICT (cache_key) DO UPDATE
           SET value = EXCLUDED.value, expires_at = EXCLUDED.expires_at, created_at = NOW()`, [key, JSON.stringify(value), ttlMs]);
            if (memory.size >= MAX_MEMORY_ENTRIES) {
                const oldest = memory.keys().next().value;
                if (oldest)
                    memory.delete(oldest);
            }
            memory.set(key, { value, expiresAt: Date.now() + ttlMs });
            return { value, cacheHit: false };
        }
        finally {
            try {
                await db.query('SELECT pg_advisory_unlock(hashtextextended($1, 0))', [key]);
            }
            catch { /* the connection releases advisory locks when it closes */ }
            db.release();
        }
    })();
    inFlight.set(key, pending);
    try {
        return await pending;
    }
    finally {
        inFlight.delete(key);
    }
}
function isValidRequestId(value) {
    return typeof value === 'string'
        && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
function idempotentOperation(route, requestId, operation) {
    const id = isValidRequestId(requestId) ? requestId : (0, crypto_1.randomUUID)();
    return cachedOperation(`request:${route}`, id, 24 * 60 * 60 * 1000, operation);
}
