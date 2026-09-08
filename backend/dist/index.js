"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const battle_1 = __importDefault(require("./routes/battle"));
const animal_1 = __importDefault(require("./routes/animal"));
const battleLogger_1 = require("./services/battleLogger");
const rateLimit_1 = require("./middleware/rateLimit");
const costControl_1 = require("./services/costControl");
const responseStore_1 = require("./services/responseStore");
const appAttest_1 = __importStar(require("./services/appAttest"));
const app = (0, express_1.default)();
const PORT = process.env.PORT || 3000;
app.disable('x-powered-by');
// ── Trust proxy ────────────────────────────────────────────────────────────────
// Set TRUST_PROXY=1 in production when behind Railway / Render / Heroku so that
// req.ip is resolved from the proxy's X-Forwarded-For chain.
// Without this env var we keep trust proxy off (safer for direct connections).
if (process.env.TRUST_PROXY === '1') {
    app.set('trust proxy', 1);
}
// ── Security headers ───────────────────────────────────────────────────────────
app.use((_req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
    res.setHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; style-src 'unsafe-inline'");
    if (process.env.NODE_ENV === 'production') {
        res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    }
    next();
});
// ── CORS ───────────────────────────────────────────────────────────────────────
// iOS apps make direct HTTP requests (not browser requests), so CORS headers
// are not strictly required for the mobile client.  We restrict to a whitelist
// anyway so that random websites cannot embed calls to this API.
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);
app.use((0, cors_1.default)({
    origin: (origin, callback) => {
        // Allow requests with no Origin (native mobile, curl, Postman)
        if (!origin)
            return callback(null, true);
        return callback(null, ALLOWED_ORIGINS.includes(origin));
    },
    methods: ['GET', 'POST'],
}));
// ── Crash/hang diagnostics (MetricKit) — its own larger body cap, BEFORE the
// global 10 KB limit, because a symbolicated crash payload exceeds 10 KB.
// Just logs to the process output (visible in Railway logs); stores nothing,
// no PII. ──────────────────────────────────────────────────────────────────────
if (process.env.DIAGNOSTICS_ENABLED === 'true') {
    app.post('/api/diag', rateLimit_1.diagnosticRateLimit, express_1.default.json({ limit: '64kb' }), (req, res) => {
        const encoded = JSON.stringify(req.body ?? {});
        console.log(JSON.stringify({
            event: 'client_diagnostic_received',
            bytes: Buffer.byteLength(encoded),
            at: new Date().toISOString(),
        }));
        res.json({ ok: true });
    });
}
// ── Body parsing — hard cap at 32 KB ──────────────────────────────────────────
// Prevents a malicious client from sending a huge JSON body to tie up the server.
app.use(express_1.default.json({
    limit: '32kb',
    verify: (req, _res, buffer) => {
        req.rawBody = Buffer.from(buffer);
    },
}));
// ── Routes ─────────────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use('/api', appAttest_1.default);
app.use('/api', battle_1.default);
app.use('/api', animal_1.default);
// ── 404 catch-all ──────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: 'Not found' }));
// ── Global error handler ───────────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
    // Propagate HTTP status codes (e.g. 413 PayloadTooLarge from express.json limit)
    const status = err.status ?? err.statusCode ?? 500;
    if (err.type === 'entity.too.large') {
        res.status(413).json({ error: 'Request body too large (max 32 KB).' });
        return;
    }
    if (status !== 500) {
        res.status(status).json({ error: err.message });
        return;
    }
    console.error('Unhandled error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
});
app.listen(PORT, () => {
    console.log(`Who Would Win backend running on port ${PORT}`);
    // Bootstrap Postgres-backed privacy, cache, and spend-control tables.
    void Promise.allSettled([
        (0, battleLogger_1.initDb)(), (0, costControl_1.initCostControl)(), (0, responseStore_1.initResponseStore)(), (0, rateLimit_1.initRateLimitStore)(), (0, appAttest_1.initAppAttest)(),
    ]);
    // Diagnostic: list every registered route so we can confirm new endpoints
    // are actually mounted in the deployed image. Logged once per boot.
    const seen = [];
    app._router?.stack?.forEach((m) => {
        if (m.route)
            seen.push(`${Object.keys(m.route.methods).join(',').toUpperCase()} ${m.route.path}`);
        else if (m.name === 'router' && m.handle?.stack) {
            m.handle.stack.forEach((r) => {
                if (r.route)
                    seen.push(`${Object.keys(r.route.methods).join(',').toUpperCase()} ${r.route.path}`);
            });
        }
    });
    console.log(`[boot:v2] Registered routes: ${seen.join(' | ')}`);
});
