import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import battleRouter from './routes/battle';
import animalRouter from './routes/animal';

dotenv.config();

const app  = express();
const PORT = process.env.PORT || 3000;

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
    if (ALLOWED_ORIGINS.length === 0 || ALLOWED_ORIGINS.includes(origin)) {
      return callback(null, true);
    }
    callback(new Error(`Origin ${origin} not allowed`));
  },
  methods: ['GET', 'POST'],
}));

// ── Body parsing — hard cap at 10 KB ──────────────────────────────────────────
// Prevents a malicious client from sending a huge JSON body to tie up the server.
app.use(express.json({ limit: '10kb' }));

// ── Routes ─────────────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use('/api', battleRouter);
app.use('/api', animalRouter);

// ── 404 catch-all ──────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: 'Not found' }));

// ── Global error handler ───────────────────────────────────────────────────────
app.use((err: Error & { status?: number; statusCode?: number; type?: string },
         _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  // Propagate HTTP status codes (e.g. 413 PayloadTooLarge from express.json limit)
  const status = err.status ?? err.statusCode ?? 500;
  if (err.type === 'entity.too.large') {
    res.status(413).json({ error: 'Request body too large (max 10 KB).' });
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
});
