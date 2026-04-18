"use strict";
/**
 * Shared in-memory rate limiter.
 *
 * Each IP gets a rolling window of MAX_REQUESTS API calls.
 * The window resets after WINDOW_MS milliseconds.
 *
 * IMPORTANT: We intentionally use req.socket.remoteAddress (the real TCP
 * connection address) instead of X-Forwarded-For so that a caller cannot
 * spoof their IP by adding a fake header.  In production behind a trusted
 * reverse-proxy (Railway, Render, etc.) set the TRUST_PROXY env var to "1"
 * and we will use req.ip (which Express resolves from the proxy's forwarded
 * header chain, not from the raw user-supplied header).
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.rateLimitMiddleware = rateLimitMiddleware;
const WINDOW_MS = 60 * 60 * 1000; // 1 hour
const MAX_REQUESTS = 50; // per IP per window
const store = new Map();
// Periodically purge expired entries so memory doesn't grow unbounded.
setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of store) {
        if (now >= entry.resetAt)
            store.delete(key);
    }
}, 10 * 60 * 1000); // every 10 minutes
function getClientIp(req) {
    // If running behind a trusted proxy (configured via TRUST_PROXY=1 env var),
    // Express populates req.ip from the proxy chain.  Otherwise fall back to the
    // raw socket address which cannot be spoofed.
    return (req.ip ?? req.socket.remoteAddress ?? 'unknown').replace(/^::ffff:/, '');
}
function rateLimitMiddleware(req, res, next) {
    const ip = getClientIp(req);
    const now = Date.now();
    const entry = store.get(ip);
    if (!entry || now >= entry.resetAt) {
        store.set(ip, { count: 1, resetAt: now + WINDOW_MS });
        res.setHeader('X-RateLimit-Limit', MAX_REQUESTS);
        res.setHeader('X-RateLimit-Remaining', MAX_REQUESTS - 1);
        return next();
    }
    if (entry.count >= MAX_REQUESTS) {
        const retryAfterSecs = Math.ceil((entry.resetAt - now) / 1000);
        res.setHeader('Retry-After', retryAfterSecs);
        res.status(429).json({
            error: `Too many requests. You have used all ${MAX_REQUESTS} battles for this hour. Please try again in ${Math.ceil(retryAfterSecs / 60)} minutes.`,
        });
        return;
    }
    entry.count += 1;
    res.setHeader('X-RateLimit-Limit', MAX_REQUESTS);
    res.setHeader('X-RateLimit-Remaining', MAX_REQUESTS - entry.count);
    next();
}
