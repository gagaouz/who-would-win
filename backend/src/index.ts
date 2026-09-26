import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { createCustomFighterAuthRouter, initCustomFighterAuth } from './services/customFighterAuth';
import { createCustomFighterRouter } from './customFighters/routes';
import { deleteCustomFighterOwnerData } from './customFighters/store';
import { startCustomFighterWorker } from './customFighters/worker';
import { enabled as spritesEnabled, configured as spritesConfigured } from './customFighters/config';

const app  = express();
const PORT = process.env.PORT || 3000;
const spriteOnly = process.env.SPRITE_ONLY_SERVICE === 'true';
const legacyInitializers: Array<() => Promise<void>> = [];
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
  res.setHeader('X-Content-Type-Options',  'nosniff');
  res.setHeader('X-Frame-Options',          'DENY');
  res.setHeader('X-XSS-Protection',         '1; mode=block');
  res.setHeader('Referrer-Policy',          'no-referrer');
  res.setHeader('Cache-Control',            'no-store');
  res.setHeader('Permissions-Policy',       'camera=(), microphone=(), geolocation=()');
  res.setHeader('Content-Security-Policy',  "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; style-src 'unsafe-inline'");
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

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no Origin (native mobile, curl, Postman)
    if (!origin) return callback(null, true);
    return callback(null, ALLOWED_ORIGINS.includes(origin));
  },
  methods: ['GET', 'POST'],
}));

// ── Crash/hang diagnostics (MetricKit) — its own larger body cap, BEFORE the
// global 10 KB limit, because a symbolicated crash payload exceeds 10 KB.
// Just logs to the process output (visible in Railway logs); stores nothing,
// no PII. ──────────────────────────────────────────────────────────────────────
if (!spriteOnly && process.env.DIAGNOSTICS_ENABLED === 'true') {
  const { diagnosticRateLimit } = require('./middleware/rateLimit');
  app.post('/api/diag', diagnosticRateLimit, express.json({ limit: '64kb' }), (req, res) => {
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
app.use(express.json({
  limit: '32kb',
  verify: (req, _res, buffer) => {
    (req as express.Request & { rawBody?: Buffer }).rawBody = Buffer.from(buffer);
  },
}));

// ── Routes ─────────────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json(spriteOnly
  ? { status: 'ok', service: 'custom-fighters', customFighters: { enabled: spritesEnabled(), configured: spritesConfigured() } }
  : { status: 'ok' }));
if (!spriteOnly) {
  // Lazy imports also keep legacy module-level cleanup timers out of the isolated artwork service.
  app.use('/api', require('./services/appAttest').default);
  app.use('/api', require('./routes/battle').default);
  app.use('/api', require('./routes/animal').default);
  legacyInitializers.push(require('./services/battleLogger').initDb, require('./services/costControl').initCostControl,
    require('./services/responseStore').initResponseStore, require('./middleware/rateLimit').initRateLimitStore,
    require('./services/appAttest').initAppAttest);
}
app.use('/api/custom-fighters/auth', createCustomFighterAuthRouter({ deleteOwnerData: deleteCustomFighterOwnerData }));
app.use('/api/custom-fighters', createCustomFighterRouter());

// ── 404 catch-all ──────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: 'Not found' }));

// ── Global error handler ───────────────────────────────────────────────────────
app.use((err: Error & { status?: number; statusCode?: number; type?: string },
         _req: express.Request, res: express.Response, _next: express.NextFunction) => {
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
    ...legacyInitializers.map(initialize => initialize()), initCustomFighterAuth(),
  ]);
  startCustomFighterWorker();
  // Diagnostic: list every registered route so we can confirm new endpoints
  // are actually mounted in the deployed image. Logged once per boot.
  const seen: string[] = [];
  app._router?.stack?.forEach((m: any) => {
    if (m.route) seen.push(`${Object.keys(m.route.methods).join(',').toUpperCase()} ${m.route.path}`);
    else if (m.name === 'router' && m.handle?.stack) {
      m.handle.stack.forEach((r: any) => {
        if (r.route) seen.push(`${Object.keys(r.route.methods).join(',').toUpperCase()} ${r.route.path}`);
      });
    }
  });
  console.log(`[boot:v2] Registered routes: ${seen.join(' | ')}`);
});
