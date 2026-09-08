"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDbPool = getDbPool;
const pg_1 = require("pg");
let pool = null;
function sslOptions(connectionString) {
    const mode = (process.env.PGSSLMODE ?? '').toLowerCase();
    if (mode === 'disable')
        return false;
    // Railway's private network is isolated and its internal Postgres endpoint
    // does not require TLS. Public endpoints must present a valid certificate
    // unless an operator explicitly opts out.
    if (connectionString.includes('.railway.internal'))
        return false;
    if (mode === 'require' || mode === 'verify-ca' || mode === 'verify-full'
        || connectionString.startsWith('postgres://') || connectionString.startsWith('postgresql://')) {
        return { rejectUnauthorized: process.env.PGSSL_REJECT_UNAUTHORIZED !== 'false' };
    }
    return undefined;
}
function getDbPool() {
    if (pool)
        return pool;
    const connectionString = process.env.DATABASE_PRIVATE_URL ?? process.env.DATABASE_URL;
    if (!connectionString)
        return null;
    pool = new pg_1.Pool({
        connectionString,
        ssl: sslOptions(connectionString),
        max: 16,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 5000,
    });
    pool.on('error', err => console.error('[database] pool error:', err.message));
    return pool;
}
