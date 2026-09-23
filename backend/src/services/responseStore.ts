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

// ── Story rotation ──────────────────────────────────────────────────────────
// Results are cached per matchup to keep AI spend low, but a single cached
// story meant Rematch showed the exact same text. Each matchup now keeps a
// small pool of stories and hands them out in turn: request 1 → story A,
// request 2 → story B, … so a rematch reads fresh. The winner never changes
// (the resolver decides it); only the telling does. At most STORY_VARIANTS
// generations per matchup per cache window.
const STORY_VARIANTS = (() => {
  const n = Number(process.env.STORY_VARIANTS);
  return Number.isInteger(n) && n >= 1 && n <= 10 ? n : 3;
})();
const rotationMemory = new Map<string, { counter: number; expiresAt: number }>();
let rotationReady = false;

async function initRotationTable(): Promise<void> {
  if (rotationReady) return;
  const pool = getDbPool();
  if (!pool) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS story_rotation (
      rotation_key TEXT PRIMARY KEY,
      counter BIGINT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL
    );
  `);
  rotationReady = true;
  setInterval(() => {
    void pool.query('DELETE FROM story_rotation WHERE expires_at < NOW()').catch(() => undefined);
  }, 60 * 60 * 1000).unref();
}

/** Which story slot (0 … variants-1) this request should get for a matchup. */
export async function nextStoryVariant(
  namespace: string, cacheInput: unknown, ttlMs: number, variants = STORY_VARIANTS,
): Promise<number> {
  if (variants <= 1) return 0;
  const key = digest(`rotation:${namespace}`, cacheInput);
  const pool = getDbPool();
  if (!pool) {
    const now = Date.now();
    const entry = rotationMemory.get(key);
    const counter = entry && entry.expiresAt > now ? entry.counter + 1 : 0;
    if (rotationMemory.size >= MAX_MEMORY_ENTRIES && !entry) {
      const oldest = rotationMemory.keys().next().value as string | undefined;
      if (oldest) rotationMemory.delete(oldest);
    }
    rotationMemory.set(key, { counter, expiresAt: now + ttlMs });
    return counter % variants;
  }
  try {
    await initRotationTable();
    const result = await pool.query<{ counter: string }>(
      `INSERT INTO story_rotation (rotation_key, counter, expires_at)
       VALUES ($1, 0, NOW() + ($2 * INTERVAL '1 millisecond'))
       ON CONFLICT (rotation_key) DO UPDATE
         SET counter = CASE WHEN story_rotation.expires_at < NOW() THEN 0
                            ELSE story_rotation.counter + 1 END,
             expires_at = EXCLUDED.expires_at
       RETURNING counter`,
      [key, ttlMs],
    );
    return Number(result.rows[0]?.counter ?? 0) % variants;
  } catch (error) {
    console.error('[response-store] rotation failed:', (error as Error).message);
    return Math.floor(Math.random() * variants);
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
