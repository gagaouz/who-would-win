import { Pool } from 'pg';

let pool: Pool | null = null;

function sslOptions(connectionString: string): false | { rejectUnauthorized: boolean } | undefined {
  const mode = (process.env.PGSSLMODE ?? '').toLowerCase();
  if (mode === 'disable') return false;

  // Railway's private network is isolated and its internal Postgres endpoint
  // does not require TLS. Public endpoints must present a valid certificate
  // unless an operator explicitly opts out.
  if (connectionString.includes('.railway.internal')) return false;

  if (mode === 'require' || mode === 'verify-ca' || mode === 'verify-full'
      || connectionString.startsWith('postgres://') || connectionString.startsWith('postgresql://')) {
    return { rejectUnauthorized: process.env.PGSSL_REJECT_UNAUTHORIZED !== 'false' };
  }
  return undefined;
}

export function getDbPool(): Pool | null {
  if (pool) return pool;
  const connectionString = process.env.DATABASE_PRIVATE_URL ?? process.env.DATABASE_URL;
  if (!connectionString) return null;

  pool = new Pool({
    connectionString,
    ssl: sslOptions(connectionString),
    max: 16,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });
  pool.on('error', err => console.error('[database] pool error:', err.message));
  return pool;
}
