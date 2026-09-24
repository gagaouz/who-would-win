"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const crypto_1 = require("crypto");
const claudeService_1 = require("../services/claudeService");
const meleeService_1 = require("../services/meleeService");
const rateLimit_1 = require("../middleware/rateLimit");
const sanitize_1 = require("../middleware/sanitize");
const customCreatureLogger_1 = require("../services/customCreatureLogger");
const responseStore_1 = require("../services/responseStore");
const costControl_1 = require("../services/costControl");
const appAttest_1 = require("../services/appAttest");
const creatures_1 = require("../data/creatures");
const battleLogger_1 = require("../services/battleLogger");
const router = (0, express_1.Router)();
const RESULT_CACHE_TTL_MS = 6 * 60 * 60 * 1000;
const ADMIN_SESSION_COOKIE = 'ava_admin_session';
const ADMIN_SESSION_TTL_SECONDS = 8 * 60 * 60;
function abortSignalFor(res) {
    const controller = new AbortController();
    res.once('close', () => { if (!res.writableEnded)
        controller.abort(); });
    return controller.signal;
}
function aiFailure(res, error, label) {
    if (res.headersSent || res.destroyed)
        return;
    const guarded = (0, costControl_1.isAiUnavailable)(error);
    console.error(`[${label}] ${guarded ? 'safe fallback' : 'generation failed'}:`, error.message);
    res.status(guarded ? 503 : 500).json({
        error: guarded ? 'Cloud narration is unavailable. Use the local result.' : 'Failed to generate the result.',
    });
}
function recordCustomMatchup(fighter1, fighter2, fighter1Name, fighter2Name, winnerId, environment) {
    const label1 = fighter1Name ?? (0, creatures_1.displayName)(fighter1);
    const label2 = fighter2Name ?? (0, creatures_1.displayName)(fighter2);
    if (!(0, creatures_1.isBuiltIn)(fighter1) && fighter1Name) {
        (0, customCreatureLogger_1.logCustomCreature)(fighter1Name, label2, environment, winnerId === fighter1);
    }
    if (!(0, creatures_1.isBuiltIn)(fighter2) && fighter2Name) {
        (0, customCreatureLogger_1.logCustomCreature)(fighter2Name, label1, environment, winnerId === fighter2);
    }
}
function secretMatches(provided) {
    const expected = process.env.ADMIN_SECRET;
    if (!expected || !provided)
        return false;
    const a = Buffer.from(provided);
    const b = Buffer.from(expected);
    return a.length === b.length && (0, crypto_1.timingSafeEqual)(a, b);
}
function parseCookie(req, name) {
    const cookies = req.header('cookie');
    if (!cookies)
        return undefined;
    for (const part of cookies.split(';')) {
        const separator = part.indexOf('=');
        if (separator < 0 || part.slice(0, separator).trim() !== name)
            continue;
        try {
            return decodeURIComponent(part.slice(separator + 1).trim());
        }
        catch {
            return undefined;
        }
    }
    return undefined;
}
function adminSessionSignature(payload) {
    const secret = process.env.ADMIN_SECRET;
    if (!secret)
        return undefined;
    return (0, crypto_1.createHmac)('sha256', secret).update(payload).digest('hex');
}
function createAdminSession() {
    const payload = `${Math.floor(Date.now() / 1000)}.${(0, crypto_1.randomBytes)(16).toString('hex')}`;
    const signature = adminSessionSignature(payload);
    return signature ? `${payload}.${signature}` : undefined;
}
function hasValidAdminSession(req) {
    const session = parseCookie(req, ADMIN_SESSION_COOKIE);
    if (!session)
        return false;
    const lastSeparator = session.lastIndexOf('.');
    if (lastSeparator < 0)
        return false;
    const payload = session.slice(0, lastSeparator);
    const providedSignature = session.slice(lastSeparator + 1);
    const expectedSignature = adminSessionSignature(payload);
    if (!expectedSignature)
        return false;
    const provided = Buffer.from(providedSignature);
    const expected = Buffer.from(expectedSignature);
    if (provided.length !== expected.length || !(0, crypto_1.timingSafeEqual)(provided, expected))
        return false;
    const issuedAt = Number(payload.slice(0, payload.indexOf('.')));
    const ageSeconds = Math.floor(Date.now() / 1000) - issuedAt;
    return Number.isSafeInteger(issuedAt) && ageSeconds >= 0 && ageSeconds <= ADMIN_SESSION_TTL_SECONDS;
}
function adminSecret(req) {
    const header = req.header('x-admin-secret');
    if (header)
        return header;
    const authorization = req.header('authorization');
    if (!authorization?.startsWith('Basic '))
        return undefined;
    try {
        const decoded = Buffer.from(authorization.slice(6), 'base64').toString('utf8');
        return decoded.slice(decoded.indexOf(':') + 1);
    }
    catch {
        return undefined;
    }
}
function isAdminAuthorized(req) {
    return secretMatches(adminSecret(req)) || hasValidAdminSession(req);
}
function requireAdmin(req, res) {
    if (isAdminAuthorized(req))
        return true;
    res.setHeader('WWW-Authenticate', 'Basic realm="Animal vs Animal admin", charset="UTF-8"');
    res.status(401).json({ error: 'Unauthorized' });
    return false;
}
function adminSessionCookie(value, maxAge = ADMIN_SESSION_TTL_SECONDS) {
    return `${ADMIN_SESSION_COOKIE}=${encodeURIComponent(value)}; Path=/api/admin; Max-Age=${maxAge}; HttpOnly; Secure; SameSite=Strict`;
}
function renderAdminLoginHtml(invalid = false) {
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
router.post('/battle', appAttest_1.requireAppAttest, rateLimit_1.battleRateLimit, async (req, res) => {
    const body = req.body;
    // ── Type-check raw fields ──────────────────────────────────────────────────
    const rawF1 = body['fighter1'];
    const rawF2 = body['fighter2'];
    const rawF1Name = body['fighter1Name'];
    const rawF2Name = body['fighter2Name'];
    const rawEnvName = body['environmentName'];
    const rawTournamentContext = body['tournamentContext'];
    const parsedF1 = (0, sanitize_1.sanitizeFighterId)(rawF1);
    const parsedF2 = (0, sanitize_1.sanitizeFighterId)(rawF2);
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
    let fighter1Name;
    let fighter2Name;
    const isCustom1 = !(0, creatures_1.isBuiltIn)(fighter1);
    const isCustom2 = !(0, creatures_1.isBuiltIn)(fighter2);
    if (isCustom1) {
        if (!rawF1Name) {
            res.status(400).json({ error: `fighter1 "${fighter1}" is not a recognised animal and no fighter1Name was provided.` });
            return;
        }
        const r = (0, sanitize_1.sanitizeName)(rawF1Name);
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
        const r = (0, sanitize_1.sanitizeName)(rawF2Name);
        if (!r.ok) {
            res.status(400).json({ error: `fighter2Name is invalid: ${r.error}` });
            return;
        }
        fighter2Name = r.value;
    }
    const environmentName = (0, sanitize_1.sanitizeEnvironment)(rawEnvName);
    const tournamentContext = (0, sanitize_1.sanitizeTournamentContext)(rawTournamentContext);
    const signal = abortSignalFor(res);
    try {
        const generated = await (0, responseStore_1.idempotentOperation)('battle', req.header('x-request-id'), async () => {
            const matchup = { fighter1, fighter2, fighter1Name, fighter2Name, environmentName, tournamentContext };
            const variant = await (0, responseStore_1.nextStoryVariant)('battle-result', matchup, RESULT_CACHE_TTL_MS);
            const cached = await (0, responseStore_1.cachedOperation)('battle-result', { ...matchup, variant }, RESULT_CACHE_TTL_MS, () => (0, claudeService_1.getBattleResult)(fighter1, fighter2, fighter1Name, fighter2Name, environmentName, tournamentContext, signal));
            return cached;
        });
        const result = generated.value.value;
        res.setHeader('X-Result-Cache', generated.cacheHit || generated.value.cacheHit ? 'HIT' : 'MISS');
        res.json(result);
        // Log AFTER the response is sent — never blocks the user.
        res.on('finish', () => {
            recordCustomMatchup(fighter1, fighter2, fighter1Name, fighter2Name, result.winner, environmentName);
            void (0, battleLogger_1.logBattle)({
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
    }
    catch (err) {
        aiFailure(res, err, 'battle');
    }
});
// POST /api/battle/quick
// Lightweight AI battle — returns winner with minimal narration.
// Same validation/sanitization as /api/battle but uses a shorter Claude prompt
// (~4× fewer tokens). Used by tournament Quick Mode on the iOS client.
router.post('/battle/quick', appAttest_1.requireAppAttest, rateLimit_1.quickRateLimit, async (req, res) => {
    const body = req.body;
    const rawF1 = body['fighter1'];
    const rawF2 = body['fighter2'];
    const rawF1Name = body['fighter1Name'];
    const rawF2Name = body['fighter2Name'];
    const rawEnvName = body['environmentName'];
    const parsedF1 = (0, sanitize_1.sanitizeFighterId)(rawF1);
    const parsedF2 = (0, sanitize_1.sanitizeFighterId)(rawF2);
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
    const isCustom1 = !(0, creatures_1.isBuiltIn)(fighter1);
    const isCustom2 = !(0, creatures_1.isBuiltIn)(fighter2);
    let fighter1Name;
    let fighter2Name;
    if (isCustom1) {
        if (!rawF1Name) {
            res.status(400).json({ error: `fighter1 "${fighter1}" is not a recognised animal and no fighter1Name was provided.` });
            return;
        }
        const r = (0, sanitize_1.sanitizeName)(rawF1Name);
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
        const r = (0, sanitize_1.sanitizeName)(rawF2Name);
        if (!r.ok) {
            res.status(400).json({ error: `fighter2Name is invalid: ${r.error}` });
            return;
        }
        fighter2Name = r.value;
    }
    const environmentName = (0, sanitize_1.sanitizeEnvironment)(rawEnvName);
    const signal = abortSignalFor(res);
    try {
        const generated = await (0, responseStore_1.idempotentOperation)('quick', req.header('x-request-id'), async () => {
            const matchup = { fighter1, fighter2, fighter1Name, fighter2Name, environmentName };
            const variant = await (0, responseStore_1.nextStoryVariant)('quick-result', matchup, RESULT_CACHE_TTL_MS);
            const cached = await (0, responseStore_1.cachedOperation)('quick-result', { ...matchup, variant }, RESULT_CACHE_TTL_MS, () => (0, claudeService_1.getQuickBattleResult)(fighter1, fighter2, fighter1Name, fighter2Name, environmentName, signal));
            return cached;
        });
        const result = generated.value.value;
        res.setHeader('X-Result-Cache', generated.cacheHit || generated.value.cacheHit ? 'HIT' : 'MISS');
        res.json(result);
        res.on('finish', () => {
            recordCustomMatchup(fighter1, fighter2, fighter1Name, fighter2Name, result.winner, environmentName);
            void (0, battleLogger_1.logBattle)({
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
    }
    catch (err) {
        aiFailure(res, err, 'quick');
    }
});
// POST /api/battle/melee
// N-vs-M team battle. Body: { teamA: [{id,name?}], teamB: [{id,name?}], environment?, environmentName? }
// Returns { winningTeam, narration, funFact, mvp, teamAHealth, teamBHealth }
router.post('/battle/melee', appAttest_1.requireAppAttest, rateLimit_1.meleeRateLimit, async (req, res) => {
    const { teamA, teamB } = req.body ?? {};
    // Same normalization as the 1v1 routes — this user-supplied value goes
    // straight into the prompt, so type-check, trim, and cap it (melee was the
    // one endpoint accepting it raw).
    const rawEnvName = (req.body ?? {})['environmentName'];
    const environmentName = (0, sanitize_1.sanitizeEnvironment)(rawEnvName);
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
    const norm = (arr) => {
        const out = [];
        for (const f of arr) {
            if (!f || typeof f !== 'object')
                return null;
            const parsedId = (0, sanitize_1.sanitizeFighterId)(f.id);
            if (!parsedId.ok)
                return null;
            const id = parsedId.value;
            const rawName = f.name;
            let name;
            if (!(0, creatures_1.isBuiltIn)(id)) {
                const s = (0, sanitize_1.sanitizeName)(rawName);
                if (!s.ok)
                    return null;
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
        const generated = await (0, responseStore_1.idempotentOperation)('melee', req.header('x-request-id'), async () => {
            const matchup = { teamA: normTeamA, teamB: normTeamB, environmentName };
            const variant = await (0, responseStore_1.nextStoryVariant)('melee-result', matchup, RESULT_CACHE_TTL_MS);
            const cached = await (0, responseStore_1.cachedOperation)('melee-result', { ...matchup, variant }, RESULT_CACHE_TTL_MS, () => (0, meleeService_1.getMeleeResult)(normTeamA, normTeamB, environmentName, signal));
            return cached;
        });
        const result = generated.value.value;
        res.setHeader('X-Result-Cache', generated.cacheHit || generated.value.cacheHit ? 'HIT' : 'MISS');
        res.json(result);
        // Log a summary row: MVP vs the first fighter on the losing team.
        // Melee data is admin-dashboard-only; the public leaderboard filters mode='full'.
        res.on('finish', () => {
            const winners = result.winningTeam === 'A' ? normTeamA : normTeamB;
            const losers = result.winningTeam === 'A' ? normTeamB : normTeamA;
            const label = (fighter) => fighter.name ?? (0, creatures_1.displayName)(fighter.id);
            for (const fighter of normTeamA) {
                if (!(0, creatures_1.isBuiltIn)(fighter.id) && fighter.name) {
                    (0, customCreatureLogger_1.logCustomCreature)(fighter.name, normTeamB.slice(0, 3).map(label).join(', '), environmentName, result.winningTeam === 'A');
                }
            }
            for (const fighter of normTeamB) {
                if (!(0, creatures_1.isBuiltIn)(fighter.id) && fighter.name) {
                    (0, customCreatureLogger_1.logCustomCreature)(fighter.name, normTeamA.slice(0, 3).map(label).join(', '), environmentName, result.winningTeam === 'B');
                }
            }
            const mvp = winners.find(f => f.id === result.mvp) ?? winners[0];
            const opp = losers[0];
            if (!mvp || !opp)
                return;
            const mvpIsCustom = !(0, creatures_1.isBuiltIn)(mvp.id);
            const oppIsCustom = !(0, creatures_1.isBuiltIn)(opp.id);
            void (0, battleLogger_1.logBattle)({
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
    }
    catch (err) {
        aiFailure(res, err, 'melee');
    }
});
// GET /api/admin/custom-creatures
// Returns a live report of all custom creature requests since last deploy.
// Protected by a simple secret header to prevent public access.
router.get('/admin/custom-creatures', rateLimit_1.adminRateLimit, (req, res) => {
    if (!requireAdmin(req, res))
        return;
    res.json((0, customCreatureLogger_1.getCustomCreatureReport)());
});
// POST /api/admin/custom-creatures/purge
// Wipes the anonymous, aggregate custom-creature tally (no user/device linkage;
// 90-day auto-pruned). Operational moderation tool — same secret-header gate as
// the report route above. Returns how many entries were removed.
router.post('/admin/custom-creatures/purge', rateLimit_1.adminRateLimit, async (req, res) => {
    if (!requireAdmin(req, res))
        return;
    // Clear BOTH stores: the in-memory tally AND the raw names persisted in the
    // battles table — otherwise the child-typed names would survive in Postgres.
    const removed = (0, customCreatureLogger_1.purgeAllCustomCreatures)();
    let namesCleared = 0;
    try {
        namesCleared = await (0, battleLogger_1.purgeCustomCreatureNames)();
    }
    catch (err) {
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
router.get('/leaderboard', rateLimit_1.publicRateLimit, async (_req, res) => {
    try {
        const board = await (0, battleLogger_1.getAnimalLeaderboard)(25);
        res.json(board);
    }
    catch (err) {
        console.error('Leaderboard error:', err);
        res.status(500).json({ error: 'Failed to load leaderboard.' });
    }
});
// GET + POST /admin/login — browser-friendly admin authentication.
// The password is submitted in the request body and exchanged for a short-lived,
// signed HttpOnly cookie. It is never placed in a URL or persisted server-side.
router.get('/admin/login', rateLimit_1.adminRateLimit, (req, res) => {
    if (isAdminAuthorized(req)) {
        res.redirect(303, '/api/admin/dashboard');
        return;
    }
    res.type('text/html').send(renderAdminLoginHtml());
});
router.post('/admin/login', rateLimit_1.adminRateLimit, (0, express_1.urlencoded)({ extended: false, limit: '2kb' }), (req, res) => {
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
});
router.post('/admin/logout', rateLimit_1.adminRateLimit, (_req, res) => {
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
router.get('/admin/dashboard', rateLimit_1.adminRateLimit, async (req, res) => {
    if (!isAdminAuthorized(req)) {
        res.redirect(303, '/api/admin/login');
        return;
    }
    try {
        const [overview, animals, recent] = await Promise.all([
            (0, battleLogger_1.getAdminOverview)(),
            (0, battleLogger_1.getAnimalLeaderboard)(50),
            (0, battleLogger_1.getRecentActivity)(200),
        ]);
        const custom = (0, customCreatureLogger_1.getCustomCreatureReport)();
        const nonce = (0, crypto_1.randomBytes)(18).toString('base64');
        res.setHeader('Content-Security-Policy', `default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}'`);
        res.type('text/html').send(renderDashboardHtml({ overview, custom, animals, recent }, nonce));
    }
    catch (err) {
        console.error('Dashboard error:', err);
        res.status(500).type('text/html').send('<h1>500 Internal Server Error</h1>');
    }
});
function renderDashboardHtml(data, nonce) {
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const n = (value) => value.toLocaleString('en-US');
    const customCards = data.custom.topCreatures.map(c => {
        const rate = c.count ? Math.round((c.wins / c.count) * 100) : 0;
        const opponents = c.opponentNames.slice(-3).reverse().join(', ');
        const search = `${c.displayName} ${opponents}`.toLowerCase();
        return `<article class="request-card custom-filterable" data-search="${esc(search)}">
      <div class="card-topline"><span class="request-name">${esc(c.displayName)}</span><span class="request-count">${n(c.count)} request${c.count === 1 ? '' : 's'}</span></div>
      <div class="request-stats">
        <div><b>${n(c.wins)}</b><span>wins</span></div>
        <div><b>${rate}%</b><span>win rate</span></div>
        <div><b><time data-time="${esc(c.lastSeen)}">${esc(c.lastSeen.slice(0, 16).replace('T', ' '))}</time></b><span>last seen</span></div>
      </div>
      <div class="opponents"><span>Recent opponents</span>${esc(opponents || 'None yet')}</div>
    </article>`;
    }).join('');
    const recentCards = data.recent.map(r => {
        const search = `${r.fighter1} ${r.fighter2} ${r.winner} ${r.environment ?? ''} ${r.mode}`.toLowerCase();
        return `<article class="battle-card activity-filterable" data-mode="${esc(r.mode)}" data-search="${esc(search)}">
      <div class="battle-meta"><time data-time="${esc(r.createdAt)}">${esc(r.createdAt.slice(0, 16).replace('T', ' '))}</time><span class="mode ${esc(r.mode)}">${esc(r.mode)}</span></div>
      <div class="matchup"><span>${esc(r.fighter1)}</span><i>VS</i><span>${esc(r.fighter2)}</span></div>
      <div class="result"><span>Winner</span><b>${esc(r.winner)}</b></div>
      <div class="arena">${r.environment ? `Arena · ${esc(r.environment)}` : 'Default arena'}</div>
    </article>`;
    }).join('');
    const ranking = (title, note, rows, metric) => `<section class="ranking-panel">
    <div class="ranking-head"><div><h3>${esc(title)}</h3><p>${esc(note)}</p></div></div>
    <ol>${rows.slice(0, 15).map((row, index) => `<li>
      <span class="rank">${index + 1}</span>
      <span class="animal-name">${esc(row.name)}</span>
      <strong>${esc(metric(row))}</strong>
      <small>${n(row.battles)} battles</small>
    </li>`).join('')}</ol>
  </section>`;
    const lastActivity = data.overview.lastActivityAt
        ? `<time data-time="${esc(data.overview.lastActivityAt)}">${esc(data.overview.lastActivityAt.slice(0, 16).replace('T', ' '))}</time>`
        : 'No activity';
    return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#07111c">
<title>Battle Pulse · Animal vs Animal</title>
<style>
  :root { color-scheme: dark; --bg:#07111c; --panel:#0d1b29; --panel2:#122336; --line:#23384b; --text:#eef6fb; --muted:#91a4b7; --amber:#ffb84d; --amber2:#ff8a3d; --green:#58d68d; --blue:#55b7ff; --purple:#b88cff; }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body { margin:0; min-height:100vh; background:radial-gradient(circle at 80% -10%, #17344f 0, transparent 34rem), var(--bg); color:var(--text); font:15px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
  button,input { font:inherit; }
  button,a { -webkit-tap-highlight-color:transparent; }
  .shell { width:min(1280px,100%); margin:0 auto; padding:20px 22px 72px; }
  .hero { position:relative; overflow:hidden; padding:28px; border:1px solid #2a4358; border-radius:24px; background:linear-gradient(135deg,#11263a 0%,#0c1926 62%,#251a19 100%); box-shadow:0 24px 70px #0006; }
  .hero:after { content:""; position:absolute; width:260px; height:260px; right:-90px; top:-130px; border-radius:50%; background:#ff9f4330; filter:blur(4px); }
  .hero-top { position:relative; z-index:1; display:flex; justify-content:space-between; gap:24px; align-items:flex-start; }
  .eyebrow { margin:0 0 8px; color:var(--amber); font-size:12px; font-weight:800; letter-spacing:.14em; text-transform:uppercase; }
  h1 { margin:0; max-width:680px; font-size:clamp(34px,6vw,64px); line-height:.95; letter-spacing:-.05em; }
  .hero-copy { margin:14px 0 0; color:#bed0df; max-width:650px; font-size:16px; }
  .hero-actions { display:flex; gap:10px; align-items:center; }
  .btn { min-height:42px; display:inline-flex; align-items:center; justify-content:center; gap:8px; padding:9px 14px; border:1px solid #38526a; border-radius:12px; color:var(--text); background:#102235; text-decoration:none; cursor:pointer; font-weight:700; white-space:nowrap; }
  .btn:hover { border-color:#64829c; background:#162b40; }
  .btn.ghost { background:transparent; }
  .status-row { position:relative; z-index:1; display:flex; flex-wrap:wrap; gap:10px 18px; align-items:center; margin-top:24px; color:var(--muted); font-size:13px; }
  .live { display:inline-flex; align-items:center; gap:8px; color:#bdf7d5; font-weight:750; }
  .live:before { content:""; width:9px; height:9px; border-radius:50%; background:var(--green); box-shadow:0 0 0 5px #58d68d1c; }
  .section-nav { position:sticky; z-index:5; top:0; display:flex; gap:8px; margin:16px 0; padding:8px; overflow:auto; border:1px solid #20364a; border-radius:15px; background:#081522e8; backdrop-filter:blur(14px); }
  .section-nav a { flex:1; min-width:max-content; padding:9px 12px; border-radius:9px; color:#aebfd0; text-align:center; text-decoration:none; font-weight:750; }
  .section-nav a:hover { color:#fff; background:#17293a; }
  .metrics { display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); gap:12px; margin:16px 0 28px; }
  .metric { min-height:122px; padding:18px; border:1px solid var(--line); border-radius:17px; background:linear-gradient(155deg,#102235,#0b1825); }
  .metric span { display:block; color:var(--muted); font-size:12px; font-weight:750; text-transform:uppercase; letter-spacing:.08em; }
  .metric strong { display:block; margin-top:8px; font-size:clamp(25px,3vw,39px); line-height:1; letter-spacing:-.04em; font-variant-numeric:tabular-nums; }
  .metric small { display:block; margin-top:10px; color:#8299ae; }
  .metric.accent { border-color:#6c4c28; background:linear-gradient(155deg,#2b2018,#171a20); }
  .metric.accent strong { color:var(--amber); }
  .section { scroll-margin-top:76px; margin-top:24px; padding:22px; border:1px solid var(--line); border-radius:21px; background:#091725d9; box-shadow:0 16px 40px #0003; }
  .section-head { display:flex; justify-content:space-between; align-items:flex-end; gap:18px; margin-bottom:18px; }
  .section-head h2 { margin:0; font-size:clamp(22px,3vw,31px); letter-spacing:-.03em; }
  .section-head p { margin:5px 0 0; color:var(--muted); }
  .section-kicker { color:var(--amber); font-size:11px; font-weight:850; letter-spacing:.12em; text-transform:uppercase; }
  .tools { display:flex; flex-wrap:wrap; gap:8px; justify-content:flex-end; }
  .search { width:min(290px,100%); min-height:42px; padding:9px 13px; border:1px solid #314a61; border-radius:11px; outline:none; color:#fff; background:#0a1724; }
  .search:focus { border-color:var(--blue); box-shadow:0 0 0 3px #55b7ff22; }
  .filters { display:flex; gap:6px; padding:4px; border:1px solid #2b4053; border-radius:11px; background:#07121d; }
  .filter { border:0; border-radius:8px; padding:6px 10px; color:#8ea4b8; background:transparent; cursor:pointer; font-weight:750; text-transform:capitalize; }
  .filter[aria-pressed="true"] { color:#fff; background:#243c51; }
  .privacy-note { margin:0 0 16px; padding:12px 14px; border-left:3px solid var(--blue); border-radius:0 10px 10px 0; color:#a8bed1; background:#0d2133; font-size:13px; }
  .request-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:12px; }
  .request-card { padding:17px; border:1px solid #263c50; border-radius:15px; background:linear-gradient(155deg,#102235,#0a1723); }
  .card-topline { display:flex; gap:12px; justify-content:space-between; align-items:flex-start; }
  .request-name { font-size:18px; font-weight:850; overflow-wrap:anywhere; }
  .request-count { flex:0 0 auto; padding:4px 8px; border-radius:99px; color:#17120b; background:var(--amber); font-size:11px; font-weight:850; }
  .request-stats { display:grid; grid-template-columns:repeat(3,1fr); gap:8px; margin:16px 0; }
  .request-stats div { min-width:0; padding:9px; border-radius:10px; background:#07131f; }
  .request-stats b,.request-stats span { display:block; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .request-stats b { font-size:15px; }
  .request-stats span { margin-top:2px; color:var(--muted); font-size:10px; text-transform:uppercase; }
  .opponents { color:#c1d0dc; font-size:13px; }
  .opponents span { display:block; color:var(--muted); font-size:10px; font-weight:800; text-transform:uppercase; letter-spacing:.08em; }
  .activity-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:10px; }
  .battle-card { padding:15px 16px; border:1px solid #21384b; border-radius:14px; background:#0c1b29; }
  .battle-meta,.result { display:flex; align-items:center; justify-content:space-between; gap:12px; }
  .battle-meta { color:var(--muted); font-size:12px; }
  .mode { padding:3px 8px; border-radius:99px; font-size:10px; font-weight:850; letter-spacing:.06em; text-transform:uppercase; }
  .mode.full { color:#aaf2c7; background:#183e2a; }
  .mode.quick { color:#ffe09b; background:#493719; }
  .mode.melee { color:#dcc7ff; background:#352653; }
  .matchup { display:grid; grid-template-columns:1fr auto 1fr; gap:9px; align-items:center; margin:14px 0; font-size:16px; font-weight:800; }
  .matchup span:last-child { text-align:right; }
  .matchup i { color:var(--amber); font-size:10px; font-style:normal; letter-spacing:.1em; }
  .result { padding-top:12px; border-top:1px solid #203447; }
  .result span { color:var(--muted); font-size:11px; text-transform:uppercase; letter-spacing:.08em; }
  .result b { color:var(--green); }
  .arena { margin-top:7px; color:#7f96aa; font-size:12px; text-align:right; }
  .result-count { min-width:64px; color:var(--muted); font-size:12px; text-align:right; }
  .rankings { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:12px; }
  .ranking-panel { overflow:hidden; border:1px solid #263c50; border-radius:15px; background:#0c1a27; }
  .ranking-head { padding:16px; border-bottom:1px solid #23384a; }
  .ranking-head h3 { margin:0; font-size:17px; }
  .ranking-head p { margin:3px 0 0; color:var(--muted); font-size:12px; }
  .ranking-panel ol { max-height:540px; overflow:auto; margin:0; padding:7px; list-style:none; }
  .ranking-panel li { display:grid; grid-template-columns:28px minmax(0,1fr) auto; grid-template-areas:"rank name metric" "rank detail detail"; gap:1px 9px; align-items:center; padding:9px; border-radius:9px; }
  .ranking-panel li:nth-child(-n+3) { background:#172a3b; }
  .rank { grid-area:rank; display:grid; place-items:center; width:27px; height:27px; border-radius:8px; color:#a9bed0; background:#07131f; font-weight:850; }
  .animal-name { grid-area:name; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font-weight:750; }
  .ranking-panel strong { grid-area:metric; color:var(--amber); font-variant-numeric:tabular-nums; }
  .ranking-panel small { grid-area:detail; color:#748ba0; }
  .empty { grid-column:1/-1; padding:34px 18px; border:1px dashed #365169; border-radius:15px; text-align:center; color:var(--muted); background:#0a1825; }
  .empty b { display:block; margin-bottom:6px; color:#dce9f2; font-size:17px; }
  [hidden] { display:none !important; }
  @media (max-width:980px) { .metrics { grid-template-columns:repeat(3,1fr); } .request-grid,.rankings { grid-template-columns:1fr 1fr; } .ranking-panel:last-child { grid-column:1/-1; } }
  @media (max-width:700px) {
    .shell { padding:12px 12px calc(48px + env(safe-area-inset-bottom)); }
    .hero { padding:20px; border-radius:19px; }
    .hero-top,.section-head { display:block; }
    .hero-actions { margin-top:20px; }
    .hero-actions .btn { flex:1; }
    .section-nav { margin:10px 0; }
    .metrics { grid-template-columns:1fr 1fr; gap:9px; margin-bottom:20px; }
    .metric { min-height:108px; padding:15px; }
    .metric:first-child { grid-column:1/-1; }
    .section { padding:16px; border-radius:17px; }
    .section-head .tools { justify-content:stretch; margin-top:14px; }
    .search { width:100%; }
    .filters { width:100%; overflow:auto; }
    .filter { flex:1; }
    .request-grid,.activity-grid,.rankings { grid-template-columns:1fr; }
    .ranking-panel:last-child { grid-column:auto; }
    .request-stats { grid-template-columns:1fr 1fr 1fr; }
    .matchup { font-size:15px; }
  }
  @media (prefers-reduced-motion:reduce) { html { scroll-behavior:auto; } }
</style>
</head>
<body>
<main class="shell">
  <header class="hero">
    <div class="hero-top">
      <div>
        <p class="eyebrow">Animal vs Animal · Live operations</p>
        <h1>Battle Pulse</h1>
        <p class="hero-copy">See what players are battling, which creatures are winning, and what they want added next.</p>
      </div>
      <div class="hero-actions">
        <a class="btn" href="/api/admin/dashboard">↻ Refresh</a>
        <form method="post" action="/api/admin/logout"><button class="btn ghost" type="submit">Sign out</button></form>
      </div>
    </div>
    <div class="status-row"><span class="live">Backend online</span><span>Last battle · ${lastActivity}</span><span>Updated · <time data-time="${esc(data.animals.generatedAt)}">${esc(data.animals.generatedAt.slice(0, 16).replace('T', ' '))}</time></span></div>
  </header>

  <nav class="section-nav" aria-label="Dashboard sections">
    <a href="#requests">Requests</a><a href="#activity">Battles</a><a href="#leaders">Leaders</a>
  </nav>

  <section class="metrics" aria-label="Battle overview">
    <article class="metric"><span>All battles</span><strong>${n(data.overview.totalBattles)}</strong><small>Every recorded mode</small></article>
    <article class="metric"><span>Last 24 hours</span><strong>${n(data.overview.battles24h)}</strong><small>Fresh activity</small></article>
    <article class="metric"><span>Last 7 days</span><strong>${n(data.overview.battles7d)}</strong><small>Weekly volume</small></article>
    <article class="metric accent"><span>Custom requests</span><strong>${n(data.overview.customAppearances)}</strong><small>${n(data.overview.customBattles)} battles involved one</small></article>
    <article class="metric"><span>Named requests now</span><strong>${n(data.custom.totalUniqueCreatures)}</strong><small>Private, in-memory tally</small></article>
  </section>

  <section class="section" id="requests">
    <div class="section-head">
      <div><span class="section-kicker">Product demand</span><h2>Custom creature requests</h2><p>The clearest signal for what to add to the roster next.</p></div>
      ${data.custom.topCreatures.length ? '<div class="tools"><input class="search" id="custom-search" type="search" placeholder="Search requests or opponents" aria-label="Search custom requests"><span class="result-count" id="custom-count"></span></div>' : ''}
    </div>
    <p class="privacy-note">Typed names are held only in this running server’s bounded memory and never written to permanent logs or the battle database. Anonymous custom-request totals remain available above.</p>
    <div class="request-grid" id="custom-list">${customCards || '<div class="empty"><b>No named requests on this server yet</b>The next custom battle will appear here immediately. Historical custom activity is still counted in the overview.</div>'}</div>
  </section>

  <section class="section" id="activity">
    <div class="section-head">
      <div><span class="section-kicker">Live feed</span><h2>Recent battle results</h2><p>The latest 200 matchups, newest first.</p></div>
      <div class="tools">
        <input class="search" id="activity-search" type="search" placeholder="Search fighters, winners or arenas" aria-label="Search recent battles">
        <div class="filters" aria-label="Filter by battle mode">
          <button class="filter" type="button" data-mode-filter="all" aria-pressed="true">All</button>
          <button class="filter" type="button" data-mode-filter="full" aria-pressed="false">Full</button>
          <button class="filter" type="button" data-mode-filter="quick" aria-pressed="false">Quick</button>
          <button class="filter" type="button" data-mode-filter="melee" aria-pressed="false">Melee</button>
        </div>
        <span class="result-count" id="activity-count"></span>
      </div>
    </div>
    <div class="activity-grid" id="activity-list">${recentCards || '<div class="empty"><b>No battles recorded yet</b>Completed battles will show up here.</div>'}</div>
  </section>

  <section class="section" id="leaders">
    <div class="section-head"><div><span class="section-kicker">Roster performance</span><h2>Built-in creature leaders</h2><p>Full-mode results only. Win-rate rankings require at least 10 battles.</p></div></div>
    <div class="rankings">
      ${ranking('Most wins', 'Consistent champions', data.animals.topByWins, row => `${n(row.wins)} wins`)}
      ${ranking('Best win rate', 'Minimum 10 battles', data.animals.topByWinRate, row => `${(row.winRate * 100).toFixed(1)}%`)}
      ${ranking('Most popular', 'Most often selected', data.animals.topByPopularity, row => `${n(row.battles)} picks`)}
    </div>
  </section>
</main>
<script nonce="${esc(nonce)}">
  (function () {
    var rtf = typeof Intl.RelativeTimeFormat === 'function' ? new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' }) : null;
    function relative(iso) {
      var then = new Date(iso).getTime();
      var delta = then - Date.now();
      var abs = Math.abs(delta);
      var unit = abs < 3600000 ? 'minute' : abs < 86400000 ? 'hour' : 'day';
      var size = unit === 'minute' ? 60000 : unit === 'hour' ? 3600000 : 86400000;
      var value = Math.round(delta / size);
      return rtf ? rtf.format(value, unit) : new Date(iso).toLocaleString();
    }
    document.querySelectorAll('time[data-time]').forEach(function (el) {
      var iso = el.getAttribute('data-time');
      el.textContent = relative(iso);
      el.setAttribute('title', new Date(iso).toLocaleString());
    });

    var activityMode = 'all';
    var activitySearch = document.getElementById('activity-search');
    var activityCards = Array.prototype.slice.call(document.querySelectorAll('.activity-filterable'));
    var activityCount = document.getElementById('activity-count');
    function filterActivity() {
      var query = (activitySearch && activitySearch.value || '').trim().toLowerCase();
      var shown = 0;
      activityCards.forEach(function (card) {
        var visible = (activityMode === 'all' || card.getAttribute('data-mode') === activityMode)
          && (!query || (card.getAttribute('data-search') || '').indexOf(query) !== -1);
        card.hidden = !visible;
        if (visible) shown += 1;
      });
      if (activityCount) activityCount.textContent = shown + ' shown';
    }
    if (activitySearch) activitySearch.addEventListener('input', filterActivity);
    document.querySelectorAll('[data-mode-filter]').forEach(function (button) {
      button.addEventListener('click', function () {
        activityMode = button.getAttribute('data-mode-filter') || 'all';
        document.querySelectorAll('[data-mode-filter]').forEach(function (item) {
          item.setAttribute('aria-pressed', item === button ? 'true' : 'false');
        });
        filterActivity();
      });
    });
    filterActivity();

    var customSearch = document.getElementById('custom-search');
    var customCards = Array.prototype.slice.call(document.querySelectorAll('.custom-filterable'));
    var customCount = document.getElementById('custom-count');
    function filterCustom() {
      var query = (customSearch && customSearch.value || '').trim().toLowerCase();
      var shown = 0;
      customCards.forEach(function (card) {
        var visible = !query || (card.getAttribute('data-search') || '').indexOf(query) !== -1;
        card.hidden = !visible;
        if (visible) shown += 1;
      });
      if (customCount) customCount.textContent = shown + ' shown';
    }
    if (customSearch) customSearch.addEventListener('input', filterCustom);
    filterCustom();
  }());
</script>
</body>
</html>`;
}
exports.default = router;
