import { Router, Request, Response, urlencoded } from 'express';
import { createHmac, randomBytes, timingSafeEqual } from 'crypto';
import { getBattleResult, getQuickBattleResult, BattleResult } from '../services/claudeService';
import { getMeleeResult, MeleeResult } from '../services/meleeService';
import {
  adminRateLimit, battleRateLimit, meleeRateLimit, publicRateLimit, quickRateLimit,
} from '../middleware/rateLimit';
import {
  sanitizeEnvironment, sanitizeFighterId, sanitizeName, sanitizeTournamentContext,
} from '../middleware/sanitize';
import { getCustomCreatureReport, purgeAllCustomCreatures } from '../services/customCreatureLogger';
import { cachedOperation, idempotentOperation, nextStoryVariant } from '../services/responseStore';
import { isAiUnavailable } from '../services/costControl';
import { requireAppAttest } from '../services/appAttest';
import { isBuiltIn } from '../data/creatures';
import {
  logBattle,
  getAnimalLeaderboard,
  getCustomCreatureLeaderboard,
  getRecentActivity,
  purgeCustomCreatureNames,
} from '../services/battleLogger';

const router = Router();

const RESULT_CACHE_TTL_MS = 6 * 60 * 60 * 1000;
const ADMIN_SESSION_COOKIE = 'ava_admin_session';
const ADMIN_SESSION_TTL_SECONDS = 8 * 60 * 60;

function abortSignalFor(res: Response): AbortSignal {
  const controller = new AbortController();
  res.once('close', () => { if (!res.writableEnded) controller.abort(); });
  return controller.signal;
}

function aiFailure(res: Response, error: unknown, label: string): void {
  if (res.headersSent || res.destroyed) return;
  const guarded = isAiUnavailable(error);
  console.error(`[${label}] ${guarded ? 'safe fallback' : 'generation failed'}:`, (error as Error).message);
  res.status(guarded ? 503 : 500).json({
    error: guarded ? 'Cloud narration is unavailable. Use the local result.' : 'Failed to generate the result.',
  });
}

function secretMatches(provided: string | undefined): boolean {
  const expected = process.env.ADMIN_SECRET;
  if (!expected || !provided) return false;
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

function parseCookie(req: Request, name: string): string | undefined {
  const cookies = req.header('cookie');
  if (!cookies) return undefined;
  for (const part of cookies.split(';')) {
    const separator = part.indexOf('=');
    if (separator < 0 || part.slice(0, separator).trim() !== name) continue;
    try {
      return decodeURIComponent(part.slice(separator + 1).trim());
    } catch {
      return undefined;
    }
  }
  return undefined;
}

function adminSessionSignature(payload: string): string | undefined {
  const secret = process.env.ADMIN_SECRET;
  if (!secret) return undefined;
  return createHmac('sha256', secret).update(payload).digest('hex');
}

function createAdminSession(): string | undefined {
  const payload = `${Math.floor(Date.now() / 1000)}.${randomBytes(16).toString('hex')}`;
  const signature = adminSessionSignature(payload);
  return signature ? `${payload}.${signature}` : undefined;
}

function hasValidAdminSession(req: Request): boolean {
  const session = parseCookie(req, ADMIN_SESSION_COOKIE);
  if (!session) return false;
  const lastSeparator = session.lastIndexOf('.');
  if (lastSeparator < 0) return false;
  const payload = session.slice(0, lastSeparator);
  const providedSignature = session.slice(lastSeparator + 1);
  const expectedSignature = adminSessionSignature(payload);
  if (!expectedSignature) return false;

  const provided = Buffer.from(providedSignature);
  const expected = Buffer.from(expectedSignature);
  if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) return false;

  const issuedAt = Number(payload.slice(0, payload.indexOf('.')));
  const ageSeconds = Math.floor(Date.now() / 1000) - issuedAt;
  return Number.isSafeInteger(issuedAt) && ageSeconds >= 0 && ageSeconds <= ADMIN_SESSION_TTL_SECONDS;
}

function adminSecret(req: Request): string | undefined {
  const header = req.header('x-admin-secret');
  if (header) return header;
  const authorization = req.header('authorization');
  if (!authorization?.startsWith('Basic ')) return undefined;
  try {
    const decoded = Buffer.from(authorization.slice(6), 'base64').toString('utf8');
    return decoded.slice(decoded.indexOf(':') + 1);
  } catch {
    return undefined;
  }
}

function isAdminAuthorized(req: Request): boolean {
  return secretMatches(adminSecret(req)) || hasValidAdminSession(req);
}

function requireAdmin(req: Request, res: Response): boolean {
  if (isAdminAuthorized(req)) return true;
  res.setHeader('WWW-Authenticate', 'Basic realm="Animal vs Animal admin", charset="UTF-8"');
  res.status(401).json({ error: 'Unauthorized' });
  return false;
}

function adminSessionCookie(value: string, maxAge = ADMIN_SESSION_TTL_SECONDS): string {
  return `${ADMIN_SESSION_COOKIE}=${encodeURIComponent(value)}; Path=/api/admin; Max-Age=${maxAge}; HttpOnly; Secure; SameSite=Strict`;
}

function renderAdminLoginHtml(invalid = false): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Animal vs Animal admin</title>
<style>
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body { min-height: 100vh; margin: 0; display: grid; place-items: center; padding: 24px; font: 16px/1.45 -apple-system, system-ui, sans-serif; background: #111827; color: #f9fafb; }
  main { width: min(100%, 420px); padding: 32px; border: 1px solid #ffffff22; border-radius: 16px; background: #1f2937; box-shadow: 0 20px 50px #0008; }
  h1 { margin: 0 0 8px; font-size: 24px; }
  p { margin: 0 0 24px; color: #cbd5e1; }
  label { display: block; margin-bottom: 8px; font-weight: 650; }
  input { width: 100%; padding: 12px 14px; border: 1px solid #64748b; border-radius: 9px; background: #0f172a; color: #fff; font: inherit; }
  button { width: 100%; margin-top: 16px; padding: 12px 16px; border: 0; border-radius: 9px; background: #f59e0b; color: #111827; font: inherit; font-weight: 750; cursor: pointer; }
  .error { margin: 0 0 16px; padding: 10px 12px; border-radius: 8px; background: #7f1d1d; color: #fecaca; }
  .note { margin: 18px 0 0; font-size: 13px; color: #94a3b8; }
</style>
</head>
<body>
<main>
  <h1>🐾 Admin dashboard</h1>
  <p>Sign in with the admin password. Your session lasts eight hours.</p>
  ${invalid ? '<div class="error" role="alert">That password is not valid.</div>' : ''}
  <form method="post" action="/api/admin/login">
    <label for="password">Admin password</label>
    <input id="password" name="password" type="password" required autofocus autocomplete="current-password">
    <button type="submit">Open dashboard</button>
  </form>
  <div class="note">The password stays out of the URL, browser history, and server access logs.</div>
</main>
</body>
</html>`;
}

// POST /api/battle
router.post('/battle', requireAppAttest, battleRateLimit, async (req: Request, res: Response): Promise<void> => {
  const body = req.body as Record<string, unknown>;

  // ── Type-check raw fields ──────────────────────────────────────────────────
  const rawF1    = body['fighter1'];
  const rawF2    = body['fighter2'];
  const rawF1Name = body['fighter1Name'];
  const rawF2Name = body['fighter2Name'];
  const rawEnvName = body['environmentName'];
  const rawTournamentContext = body['tournamentContext'];

  const parsedF1 = sanitizeFighterId(rawF1);
  const parsedF2 = sanitizeFighterId(rawF2);
  if (!parsedF1.ok || !parsedF2.ok) {
    res.status(400).json({ error: 'fighter1 and fighter2 must be valid fighter IDs.' });
    return;
  }
  const fighter1 = parsedF1.value;
  const fighter2 = parsedF2.value;

  // Prevent battling the same fighter against itself
  if (fighter1 === fighter2) {
    res.status(400).json({ error: 'A fighter cannot battle itself.' });
    return;
  }

  // ── Validate / sanitize display names (used in Claude prompt) ─────────────
  // For whitelist animals the name is determined server-side.
  // For custom animals the client may supply a display name — sanitize it.
  let fighter1Name: string | undefined;
  let fighter2Name: string | undefined;

  const isCustom1 = !isBuiltIn(fighter1);
  const isCustom2 = !isBuiltIn(fighter2);

  if (isCustom1) {
    if (!rawF1Name) {
      res.status(400).json({ error: `fighter1 "${fighter1}" is not a recognised animal and no fighter1Name was provided.` });
      return;
    }
    const r = sanitizeName(rawF1Name);
    if (!r.ok) {
      res.status(400).json({ error: `fighter1Name is invalid: ${r.error}` });
      return;
    }
    fighter1Name = r.value;
  }

  if (isCustom2) {
    if (!rawF2Name) {
      res.status(400).json({ error: `fighter2 "${fighter2}" is not a recognised animal and no fighter2Name was provided.` });
      return;
    }
    const r = sanitizeName(rawF2Name);
    if (!r.ok) {
      res.status(400).json({ error: `fighter2Name is invalid: ${r.error}` });
      return;
    }
    fighter2Name = r.value;
  }

  const environmentName = sanitizeEnvironment(rawEnvName);
  const tournamentContext = sanitizeTournamentContext(rawTournamentContext);
  const signal = abortSignalFor(res);

  try {
    const generated = await idempotentOperation('battle', req.header('x-request-id'), async () => {
      const matchup = { fighter1, fighter2, fighter1Name, fighter2Name, environmentName, tournamentContext };
      const variant = await nextStoryVariant('battle-result', matchup, RESULT_CACHE_TTL_MS);
      const cached = await cachedOperation(
        'battle-result',
        { ...matchup, variant },
        RESULT_CACHE_TTL_MS,
        () => getBattleResult(fighter1, fighter2, fighter1Name, fighter2Name,
          environmentName, tournamentContext, signal),
      );
      return cached;
    });
    const result = generated.value.value;
    res.setHeader('X-Result-Cache', generated.cacheHit || generated.value.cacheHit ? 'HIT' : 'MISS');
    res.json(result);
    // Log AFTER the response is sent — never blocks the user.
    res.on('finish', () => {
      void logBattle({
        fighter1Id: fighter1,
        fighter2Id: fighter2,
        fighter1Name,
        fighter2Name,
        winnerId: result.winner,
        environment: environmentName,
        isCustom1,
        isCustom2,
        mode: 'full',
      });
    });
  } catch (err) {
    aiFailure(res, err, 'battle');
  }
});

// POST /api/battle/quick
// Lightweight AI battle — returns winner with minimal narration.
// Same validation/sanitization as /api/battle but uses a shorter Claude prompt
// (~4× fewer tokens). Used by tournament Quick Mode on the iOS client.
router.post('/battle/quick', requireAppAttest, quickRateLimit, async (req: Request, res: Response): Promise<void> => {
  const body = req.body as Record<string, unknown>;

  const rawF1     = body['fighter1'];
  const rawF2     = body['fighter2'];
  const rawF1Name = body['fighter1Name'];
  const rawF2Name = body['fighter2Name'];
  const rawEnvName = body['environmentName'];

  const parsedF1 = sanitizeFighterId(rawF1);
  const parsedF2 = sanitizeFighterId(rawF2);
  if (!parsedF1.ok || !parsedF2.ok) {
    res.status(400).json({ error: 'fighter1 and fighter2 must be valid fighter IDs.' });
    return;
  }
  const fighter1 = parsedF1.value;
  const fighter2 = parsedF2.value;
  if (fighter1 === fighter2) {
    res.status(400).json({ error: 'A fighter cannot battle itself.' });
    return;
  }

  const isCustom1 = !isBuiltIn(fighter1);
  const isCustom2 = !isBuiltIn(fighter2);

  let fighter1Name: string | undefined;
  let fighter2Name: string | undefined;

  if (isCustom1) {
    if (!rawF1Name) {
      res.status(400).json({ error: `fighter1 "${fighter1}" is not a recognised animal and no fighter1Name was provided.` });
      return;
    }
    const r = sanitizeName(rawF1Name);
    if (!r.ok) { res.status(400).json({ error: `fighter1Name is invalid: ${r.error}` }); return; }
    fighter1Name = r.value;
  }

  if (isCustom2) {
    if (!rawF2Name) {
      res.status(400).json({ error: `fighter2 "${fighter2}" is not a recognised animal and no fighter2Name was provided.` });
      return;
    }
    const r = sanitizeName(rawF2Name);
    if (!r.ok) { res.status(400).json({ error: `fighter2Name is invalid: ${r.error}` }); return; }
    fighter2Name = r.value;
  }

  const environmentName = sanitizeEnvironment(rawEnvName);
  const signal = abortSignalFor(res);

  try {
    const generated = await idempotentOperation('quick', req.header('x-request-id'), async () => {
      const matchup = { fighter1, fighter2, fighter1Name, fighter2Name, environmentName };
      const variant = await nextStoryVariant('quick-result', matchup, RESULT_CACHE_TTL_MS);
      const cached = await cachedOperation(
        'quick-result',
        { ...matchup, variant },
        RESULT_CACHE_TTL_MS,
        () => getQuickBattleResult(fighter1, fighter2, fighter1Name, fighter2Name, environmentName, signal),
      );
      return cached;
    });
    const result = generated.value.value;
    res.setHeader('X-Result-Cache', generated.cacheHit || generated.value.cacheHit ? 'HIT' : 'MISS');
    res.json(result);
    res.on('finish', () => {
      void logBattle({
        fighter1Id: fighter1,
        fighter2Id: fighter2,
        fighter1Name,
        fighter2Name,
        winnerId: result.winner,
        environment: environmentName,
        isCustom1,
        isCustom2,
        mode: 'quick',
      });
    });
  } catch (err) {
    aiFailure(res, err, 'quick');
  }
});

// POST /api/battle/melee
// N-vs-M team battle. Body: { teamA: [{id,name?}], teamB: [{id,name?}], environment?, environmentName? }
// Returns { winningTeam, narration, funFact, mvp, teamAHealth, teamBHealth }
router.post('/battle/melee', requireAppAttest, meleeRateLimit, async (req: Request, res: Response): Promise<void> => {
  const { teamA, teamB } = req.body ?? {};
  // Same normalization as the 1v1 routes — this user-supplied value goes
  // straight into the prompt, so type-check, trim, and cap it (melee was the
  // one endpoint accepting it raw).
  const rawEnvName = (req.body ?? {})['environmentName'];
  const environmentName = sanitizeEnvironment(rawEnvName);

  if (!Array.isArray(teamA) || !Array.isArray(teamB) ||
      teamA.length === 0 || teamB.length === 0) {
    res.status(400).json({ error: 'teamA and teamB must be non-empty arrays' });
    return;
  }
  if (teamA.length > 6 || teamB.length > 6) {
    res.status(400).json({ error: 'each team is capped at 6 fighters' });
    return;
  }

  // Normalize each fighter entry. Each must have a string id; names go
  // through the sanitizer just like /api/battle does.
  const norm = (arr: unknown[]): { id: string; name?: string }[] | null => {
    const out: { id: string; name?: string }[] = [];
    for (const f of arr) {
      if (!f || typeof f !== 'object') return null;
      const parsedId = sanitizeFighterId((f as { id?: unknown }).id);
      if (!parsedId.ok) return null;
      const id = parsedId.value;
      const rawName = (f as { name?: unknown }).name;
      let name: string | undefined;
      if (!isBuiltIn(id)) {
        const s = sanitizeName(rawName);
        if (!s.ok) return null;
        name = s.value;
      }
      out.push({ id, name });
    }
    return out;
  };
  const normTeamA = norm(teamA);
  const normTeamB = norm(teamB);
  if (!normTeamA || !normTeamB) {
    res.status(400).json({ error: 'each fighter entry must have a string id' });
    return;
  }

  const signal = abortSignalFor(res);
  try {
    const generated = await idempotentOperation('melee', req.header('x-request-id'), async () => {
      const matchup = { teamA: normTeamA, teamB: normTeamB, environmentName };
      const variant = await nextStoryVariant('melee-result', matchup, RESULT_CACHE_TTL_MS);
      const cached = await cachedOperation(
        'melee-result', { ...matchup, variant },
        RESULT_CACHE_TTL_MS,
        () => getMeleeResult(normTeamA, normTeamB, environmentName, signal),
      );
      return cached;
    });
    const result: MeleeResult = generated.value.value;
    res.setHeader('X-Result-Cache', generated.cacheHit || generated.value.cacheHit ? 'HIT' : 'MISS');
    res.json(result);
    // Log a summary row: MVP vs the first fighter on the losing team.
    // Melee data is admin-dashboard-only; the public leaderboard filters mode='full'.
    res.on('finish', () => {
      const winners = result.winningTeam === 'A' ? normTeamA : normTeamB;
      const losers  = result.winningTeam === 'A' ? normTeamB : normTeamA;
      const mvp     = winners.find(f => f.id === result.mvp) ?? winners[0];
      const opp     = losers[0];
      if (!mvp || !opp) return;
      const mvpIsCustom = !isBuiltIn(mvp.id);
      const oppIsCustom = !isBuiltIn(opp.id);
      void logBattle({
        fighter1Id: mvp.id,
        fighter2Id: opp.id,
        fighter1Name: mvpIsCustom ? mvp.name : undefined,
        fighter2Name: oppIsCustom ? opp.name : undefined,
        winnerId: mvp.id,
        environment: environmentName,
        isCustom1: mvpIsCustom,
        isCustom2: oppIsCustom,
        mode: 'melee',
      });
    });
  } catch (err) {
    aiFailure(res, err, 'melee');
  }
});

// GET /api/admin/custom-creatures
// Returns a live report of all custom creature requests since last deploy.
// Protected by a simple secret header to prevent public access.
router.get('/admin/custom-creatures', adminRateLimit, (req: Request, res: Response): void => {
  if (!requireAdmin(req, res)) return;

  res.json(getCustomCreatureReport());
});

// POST /api/admin/custom-creatures/purge
// Wipes the anonymous, aggregate custom-creature tally (no user/device linkage;
// 90-day auto-pruned). Operational moderation tool — same secret-header gate as
// the report route above. Returns how many entries were removed.
router.post('/admin/custom-creatures/purge', adminRateLimit, async (req: Request, res: Response): Promise<void> => {
  if (!requireAdmin(req, res)) return;

  // Clear BOTH stores: the in-memory tally AND the raw names persisted in the
  // battles table — otherwise the child-typed names would survive in Postgres.
  const removed = purgeAllCustomCreatures();
  let namesCleared = 0;
  try {
    namesCleared = await purgeCustomCreatureNames();
  } catch (err) {
    console.error('Custom name DB purge failed:', err);
    res.status(500).json({ error: 'Purge partially failed (in-memory cleared, DB not).' });
    return;
  }
  console.log(JSON.stringify({ event: 'custom_creatures_purged', removed, namesCleared, at: new Date().toISOString() }));
  res.json({ ok: true, removed, namesCleared });
});

// GET /api/leaderboard — PUBLIC
// Returns built-in animal stats for the in-app Hall of Fame.
// Filters: mode='full', is_custom1=false AND is_custom2=false.
router.get('/leaderboard', publicRateLimit, async (_req: Request, res: Response): Promise<void> => {
  try {
    const board = await getAnimalLeaderboard(25);
    res.json(board);
  } catch (err) {
    console.error('Leaderboard error:', err);
    res.status(500).json({ error: 'Failed to load leaderboard.' });
  }
});

// GET + POST /admin/login — browser-friendly admin authentication.
// The password is submitted in the request body and exchanged for a short-lived,
// signed HttpOnly cookie. It is never placed in a URL or persisted server-side.
router.get('/admin/login', adminRateLimit, (req: Request, res: Response): void => {
  if (isAdminAuthorized(req)) {
    res.redirect(303, '/api/admin/dashboard');
    return;
  }
  res.type('text/html').send(renderAdminLoginHtml());
});

router.post(
  '/admin/login',
  adminRateLimit,
  urlencoded({ extended: false, limit: '2kb' }),
  (req: Request, res: Response): void => {
    const password = typeof req.body?.password === 'string' ? req.body.password : undefined;
    if (!secretMatches(password)) {
      res.status(401).type('text/html').send(renderAdminLoginHtml(true));
      return;
    }
    const session = createAdminSession();
    if (!session) {
      res.status(503).type('text/html').send('<h1>Admin login is not configured.</h1>');
      return;
    }
    res.setHeader('Set-Cookie', adminSessionCookie(session));
    res.redirect(303, '/api/admin/dashboard');
  },
);

router.post('/admin/logout', adminRateLimit, (_req: Request, res: Response): void => {
  res.setHeader('Set-Cookie', adminSessionCookie('', 0));
  res.redirect(303, '/api/admin/login');
});

// GET /admin/dashboard — PRIVATE HTML PAGE
// Renders a self-contained admin dashboard with three tables:
//   1. Top custom creatures (case-insensitive name aggregation)
//   2. Top built-in animals
//   3. Recent activity (last 200 battles)
// Uses the signed login cookie in browsers, while retaining HTTP Basic auth or
// x-admin-secret for API clients. Secrets are never accepted in URLs, where
// they leak into history and access logs.
router.get('/admin/dashboard', adminRateLimit, async (req: Request, res: Response): Promise<void> => {
  if (!isAdminAuthorized(req)) {
    res.redirect(303, '/api/admin/login');
    return;
  }

  try {
    const [custom, animals, recent] = await Promise.all([
      getCustomCreatureLeaderboard(50),
      getAnimalLeaderboard(50),
      getRecentActivity(200),
    ]);
    res.type('text/html').send(renderDashboardHtml({ custom, animals, recent }));
  } catch (err) {
    console.error('Dashboard error:', err);
    res.status(500).type('text/html').send('<h1>500 Internal Server Error</h1>');
  }
});

function renderDashboardHtml(data: {
  custom: Awaited<ReturnType<typeof getCustomCreatureLeaderboard>>;
  animals: Awaited<ReturnType<typeof getAnimalLeaderboard>>;
  recent: Awaited<ReturnType<typeof getRecentActivity>>;
}): string {
  const esc = (s: unknown) =>
    String(s ?? '').replace(/[&<>"']/g, c =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c] as string));

  const customRows = data.custom.map(c => `
    <tr>
      <td>${esc(c.name)}</td>
      <td class="num">${c.battles}</td>
      <td class="num">${c.wins}</td>
      <td class="num">${c.battles ? ((c.wins / c.battles) * 100).toFixed(1) + '%' : '—'}</td>
      <td>${esc(c.sampleOpponent)}</td>
      <td class="num">${esc(c.lastSeen.slice(0, 16).replace('T', ' '))}</td>
    </tr>`).join('');

  const renderAnimalTable = (rows: typeof data.animals.topByWins, valueLabel: string,
                             valueFn: (r: typeof rows[0]) => string) => rows.map((r, i) => `
    <tr>
      <td class="num">${i + 1}</td>
      <td>${esc(r.name)}</td>
      <td class="num">${valueFn(r)}</td>
      <td class="num">${r.battles}</td>
    </tr>`).join('');

  const recentRows = data.recent.map(r => `
    <tr>
      <td class="num">${esc(r.createdAt.slice(0, 16).replace('T', ' '))}</td>
      <td>${esc(r.fighter1)}</td>
      <td>${esc(r.fighter2)}</td>
      <td><b>${esc(r.winner)}</b></td>
      <td>${esc(r.environment ?? '—')}</td>
      <td><span class="badge ${esc(r.mode)}">${esc(r.mode)}</span></td>
    </tr>`).join('');

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>AvA admin dashboard</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 14px/1.4 -apple-system, system-ui, sans-serif; max-width: 1200px; margin: 24px auto; padding: 0 16px; }
  h1 { margin: 0 0 4px; }
  .muted { color: #888; font-size: 12px; }
  h2 { margin-top: 32px; padding-bottom: 4px; border-bottom: 1px solid #ccc4; }
  .grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th, td { padding: 6px 8px; text-align: left; border-bottom: 1px solid #ccc4; }
  th { background: #f4f4f44d; position: sticky; top: 0; }
  td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
  .badge { display: inline-block; padding: 1px 6px; border-radius: 4px; font-size: 11px; font-weight: 600; }
  .badge.full  { background: #6ECC6E33; color: #2a7d2a; }
  .badge.quick { background: #FFD43B33; color: #8a6500; }
  .badge.melee { background: #C77DFF33; color: #5a2d8a; }
  .scroll { max-height: 600px; overflow: auto; border: 1px solid #ccc4; border-radius: 6px; }
  .header { display: flex; align-items: start; justify-content: space-between; gap: 16px; }
  .logout { border: 1px solid #ccc6; border-radius: 6px; padding: 6px 10px; background: transparent; color: inherit; cursor: pointer; }
</style>
</head>
<body>
<div class="header">
  <div>
    <h1>🐾 Animal vs Animal — Admin Dashboard</h1>
    <div class="muted">Total full-mode battles: ${data.animals.totalBattles.toLocaleString()} · Generated ${esc(data.animals.generatedAt)}</div>
  </div>
  <form method="post" action="/api/admin/logout"><button class="logout" type="submit">Sign out</button></form>
</div>

<h2>Top 50 custom creatures (all modes)</h2>
<div class="scroll">
<table>
  <thead>
    <tr><th>Name</th><th class="num">Battles</th><th class="num">Wins</th><th class="num">Win rate</th><th>Sample opponent</th><th class="num">Last seen (UTC)</th></tr>
  </thead>
  <tbody>${customRows || '<tr><td colspan="6" class="muted">No custom creatures logged yet.</td></tr>'}</tbody>
</table>
</div>

<h2>Top built-in animals (full mode)</h2>
<div class="grid">
  <div>
    <h3>By wins</h3>
    <table>
      <thead><tr><th class="num">#</th><th>Animal</th><th class="num">Wins</th><th class="num">Battles</th></tr></thead>
      <tbody>${renderAnimalTable(data.animals.topByWins, 'wins', r => r.wins.toString())}</tbody>
    </table>
  </div>
  <div>
    <h3>By win rate (min 10 battles)</h3>
    <table>
      <thead><tr><th class="num">#</th><th>Animal</th><th class="num">Rate</th><th class="num">Battles</th></tr></thead>
      <tbody>${renderAnimalTable(data.animals.topByWinRate, 'winRate', r => (r.winRate * 100).toFixed(1) + '%')}</tbody>
    </table>
  </div>
  <div>
    <h3>By popularity</h3>
    <table>
      <thead><tr><th class="num">#</th><th>Animal</th><th class="num">Battles</th><th class="num">Wins</th></tr></thead>
      <tbody>${renderAnimalTable(data.animals.topByPopularity, 'battles', r => r.battles.toString())}</tbody>
    </table>
  </div>
</div>

<h2>Recent activity (last 200)</h2>
<div class="scroll">
<table>
  <thead>
    <tr><th class="num">Time (UTC)</th><th>Fighter 1</th><th>Fighter 2</th><th>Winner</th><th>Arena</th><th>Mode</th></tr>
  </thead>
  <tbody>${recentRows || '<tr><td colspan="6" class="muted">No battles yet.</td></tr>'}</tbody>
</table>
</div>

</body>
</html>`;
}

export default router;
