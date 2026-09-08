import { createHash, randomUUID } from 'crypto';
import { getDbPool } from './database';

const memory = new Map<string, { value: unknown; expiresAt: number }>();
const inFlight = new Map<string, Promise<{ value: unknown; cacheHit: boolean }>>();
const MAX_MEMORY_ENTRIES = 1_000;
let initialized = false;
let initialization: Promise<void> | null = null;

function digest(namespace: string, key: unknown): string {
  return createHash('sha256').update(`${namespace}:${JSON.stringify(key)}`).digest('hex');
}

export async function initResponseStore(): Promise<void> {
  if (initialized) return;
  if (initialization) return initialization;
  initialization = (async () => {
    const pool = getDbPool();
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

async function read<T>(key: string): Promise<T | null> {
  const local = memory.get(key);
  if (local && local.expiresAt > Date.now()) return local.value as T;
  if (local) memory.delete(key);
  const pool = getDbPool();
  if (!pool) return null;
  await initResponseStore();
  const result = await pool.query<{ value: T }>(
    'SELECT value FROM response_cache WHERE cache_key = $1 AND expires_at > NOW()', [key]);
  return result.rows[0]?.value ?? null;
}

async function write<T>(key: string, value: T, ttlMs: number): Promise<void> {
  if (memory.size >= MAX_MEMORY_ENTRIES) {
    const oldest = memory.keys().next().value as string | undefined;
    if (oldest) memory.delete(oldest);
  }
  memory.set(key, { value, expiresAt: Date.now() + ttlMs });
  const pool = getDbPool();
  if (!pool) return;
  await initResponseStore();
  await pool.query(
    `INSERT INTO response_cache (cache_key, value, expires_at)
     VALUES ($1, $2::jsonb, NOW() + ($3 * INTERVAL '1 millisecond'))
     ON CONFLICT (cache_key) DO UPDATE
       SET value = EXCLUDED.value, expires_at = EXCLUDED.expires_at, created_at = NOW()`,
    [key, JSON.stringify(value), ttlMs],
  );
}

export async function cachedOperation<T>(
  namespace: string, cacheInput: unknown, ttlMs: number, operation: () => Promise<T>,
): Promise<{ value: T; cacheHit: boolean }> {
  const key = digest(namespace, cacheInput);
  try {
    const cached = await read<T>(key);
    if (cached !== null) return { value: cached, cacheHit: true };
  } catch (error) {
    console.error('[response-store] read failed:', (error as Error).message);
  }

  const existing = inFlight.get(key) as Promise<{ value: T; cacheHit: boolean }> | undefined;
  if (existing) {
    const joined = await existing;
    return { value: joined.value, cacheHit: true };
  }

  const pending = (async (): Promise<{ value: T; cacheHit: boolean }> => {
    const pool = getDbPool();
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
      const cached = await db.query<{ value: T }>(
        'SELECT value FROM response_cache WHERE cache_key = $1 AND expires_at > NOW()', [key]);
      const afterLock = cached.rows[0]?.value;
      if (afterLock !== undefined) return { value: afterLock, cacheHit: true };
      const value = await operation();
      await db.query(
        `INSERT INTO response_cache (cache_key, value, expires_at)
         VALUES ($1, $2::jsonb, NOW() + ($3 * INTERVAL '1 millisecond'))
         ON CONFLICT (cache_key) DO UPDATE
           SET value = EXCLUDED.value, expires_at = EXCLUDED.expires_at, created_at = NOW()`,
        [key, JSON.stringify(value), ttlMs],
      );
      if (memory.size >= MAX_MEMORY_ENTRIES) {
        const oldest = memory.keys().next().value as string | undefined;
        if (oldest) memory.delete(oldest);
      }
      memory.set(key, { value, expiresAt: Date.now() + ttlMs });
      return { value, cacheHit: false };
    } finally {
      try { await db.query('SELECT pg_advisory_unlock(hashtextextended($1, 0))', [key]); }
      catch { /* the connection releases advisory locks when it closes */ }
      db.release();
    }
  })();
  inFlight.set(key, pending as Promise<{ value: unknown; cacheHit: boolean }>);
  try {
    return await pending;
  } finally {
    inFlight.delete(key);
  }
}

export function isValidRequestId(value: unknown): value is string {
  return typeof value === 'string'
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export function idempotentOperation<T>(
  route: string, requestId: string | undefined, operation: () => Promise<T>,
): Promise<{ value: T; cacheHit: boolean }> {
  const id = isValidRequestId(requestId) ? requestId : randomUUID();
  return cachedOperation(`request:${route}`, id, 24 * 60 * 60 * 1000, operation);
}
