import { Router, Request, Response } from 'express';
import { getBattleResult, getQuickBattleResult, BattleResult } from '../services/claudeService';
import { getMeleeResult, MeleeResult } from '../services/meleeService';
import { rateLimitMiddleware } from '../middleware/rateLimit';
import { sanitizeName } from '../middleware/sanitize';
import { logCustomCreature, getCustomCreatureReport } from '../services/customCreatureLogger';
import {
  logBattle,
  getAnimalLeaderboard,
  getCustomCreatureLeaderboard,
  getRecentActivity,
} from '../services/battleLogger';

const router = Router();

// ── In-memory battle result cache ──────────────────────────────────────────────
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour
const MAX_RESULTS_PER_KEY = 3;

interface CacheEntry {
  results: BattleResult[];
  createdAt: number;
}

const battleCache = new Map<string, CacheEntry>();

function makeCacheKey(f1: string, f2: string, env?: string): string {
  return [f1, f2].sort().join('-') + '-' + (env || 'none');
}

function getCachedResult(key: string): BattleResult | null {
  const entry = battleCache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.createdAt >= CACHE_TTL_MS) {
    battleCache.delete(key);
    return null;
  }
  return entry.results[Math.floor(Math.random() * entry.results.length)];
}

function storeCachedResult(key: string, result: BattleResult): void {
  const entry = battleCache.get(key);
  if (entry && Date.now() - entry.createdAt < CACHE_TTL_MS) {
    if (entry.results.length < MAX_RESULTS_PER_KEY) {
      entry.results.push(result);
    } else {
      // Rotate: replace the oldest entry
      entry.results.shift();
      entry.results.push(result);
    }
  } else {
    battleCache.set(key, { results: [result], createdAt: Date.now() });
  }
}

// Purge expired cache entries every 10 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of battleCache) {
    if (now - entry.createdAt >= CACHE_TTL_MS) {
      battleCache.delete(key);
    }
  }
}, 10 * 60 * 1000);

// Whitelist of all valid animal IDs
const VALID_ANIMALS = new Set<string>([
  // Land
  'lion', 'tiger', 'grizzly_bear', 'wolf', 'elephant', 'rhinoceros',
  'hippopotamus', 'gorilla', 'cheetah', 'crocodile', 'komodo_dragon',
  'wolverine', 'honey_badger', 'giraffe', 'zebra', 'moose', 'boar',
  'tarantula', 'scorpion', 'cobra',
  // Sea
  'great_white_shark', 'orca', 'giant_squid', 'piranha', 'octopus',
  'barracuda', 'electric_eel', 'hammerhead_shark', 'mantis_shrimp',
  'blue_ringed_octopus', 'swordfish', 'coelacanth',
  // Air
  'bald_eagle', 'peregrine_falcon', 'harpy_eagle', 'barn_owl',
  'pterodactyl', 'hornet', 'dragonfly', 'albatross', 'pelican', 'crow',
  // Bugs
  'army_ant', 'bombardier_beetle', 'bullet_ant', 'praying_mantis',
  'fire_ant', 'centipede', 'wasp', 'stag_beetle',
  // Pets
  'great_dane', 'german_shepherd', 'golden_retriever', 'labrador',
  'husky', 'bulldog', 'beagle', 'poodle', 'corgi', 'pug',
  'dachshund', 'chihuahua', 'tabby_cat', 'persian_cat', 'maine_coon',
  'parakeet', 'cockatiel', 'canary', 'hamster', 'gerbil',
  'guinea_pig', 'pet_rabbit', 'goldfish', 'betta_fish', 'leopard_gecko',
  // Farm
  'cow', 'bull', 'ox', 'pig', 'piglet', 'sheep', 'lamb', 'ram', 'goat',
  'horse', 'donkey', 'mule', 'llama', 'alpaca',
  'chicken', 'rooster', 'duck', 'goose', 'turkey', 'border_collie',
  // Fantasy
  'dragon', 'unicorn', 'griffin', 'kraken', 'minotaur', 'werewolf',
  'hydra', 'phoenix', 'kitsune', 'basilisk', 'cerberus', 'leviathan',
  // Prehistoric
  't_rex', 'triceratops', 'velociraptor', 'spinosaurus', 'megalodon',
  'woolly_mammoth', 'saber_tooth_tiger', 'ankylosaurus', 'pteranodon',
  'dire_wolf', 'therizinosaurus', 'dodo',
  // Mythic
  'thunderbird', 'manticore', 'sphinx', 'chimera', 'wyvern', 'kirin',
  'roc', 'jackalope', 'baku', 'nue', 'ammit', 'peryton',
  // Mount Olympus (cheat code)
  'zeus', 'poseidon', 'hades', 'ares', 'athena', 'apollo',
  'artemis', 'hermes', 'hephaestus', 'hercules', 'medusa', 'kronos',
]);

// POST /api/battle
router.post('/battle', rateLimitMiddleware, async (req: Request, res: Response): Promise<void> => {
  const body = req.body as Record<string, unknown>;

  // ── Type-check raw fields ──────────────────────────────────────────────────
  const rawF1    = body['fighter1'];
  const rawF2    = body['fighter2'];
  const rawF1Name = body['fighter1Name'];
  const rawF2Name = body['fighter2Name'];
  const rawEnvName = body['environmentName'];
  const rawTournamentContext = body['tournamentContext'];

  if (typeof rawF1 !== 'string' || typeof rawF2 !== 'string') {
    res.status(400).json({ error: 'fighter1 and fighter2 must be strings.' });
    return;
  }

  // ── Sanitize IDs (just trim + lowercase — these are internal IDs) ──────────
  const fighter1 = rawF1.trim().toLowerCase().slice(0, 80);
  const fighter2 = rawF2.trim().toLowerCase().slice(0, 80);

  if (!fighter1 || !fighter2) {
    res.status(400).json({ error: 'Both fighter1 and fighter2 are required.' });
    return;
  }

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

  const isCustom1 = !VALID_ANIMALS.has(fighter1);
  const isCustom2 = !VALID_ANIMALS.has(fighter2);

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

  // ── Log custom creatures for demand tracking ───────────────────────────────
  const environmentName = typeof rawEnvName === 'string' ? rawEnvName.trim().slice(0, 40) : undefined;
  if (isCustom1 && fighter1Name) {
    const opponentLabel = isCustom2 ? (fighter2Name ?? fighter2) : fighter2;
    logCustomCreature(fighter1Name, opponentLabel, environmentName);
  }
  if (isCustom2 && fighter2Name) {
    const opponentLabel = isCustom1 ? (fighter1Name ?? fighter1) : fighter1;
    logCustomCreature(fighter2Name, opponentLabel, environmentName);
  }

  // ── Call Claude (with cache) ───────────────────────────────────────────────
  // Tournament context: a short server-trusted string (e.g. "This battle is a Quarterfinal in an 8-creature tournament. Build drama accordingly.")
  // Tournament battles SKIP the cache entirely so the narration always reflects the current round.
  const tournamentContext = typeof rawTournamentContext === 'string'
    ? rawTournamentContext.trim().slice(0, 200)
    : undefined;
  const isTournamentBattle = !!tournamentContext;
  const cacheKey = makeCacheKey(fighter1, fighter2, environmentName);

  // Check cache first (skip for tournament battles so each round gets fresh narration)
  if (!isTournamentBattle) {
    const cached = getCachedResult(cacheKey);
    if (cached) {
      res.json(cached);
      return;
    }
  }

  try {
    const result = await getBattleResult(fighter1, fighter2, fighter1Name, fighter2Name, environmentName, tournamentContext);
    if (!isTournamentBattle) {
      storeCachedResult(cacheKey, result);
    }
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
    console.error('Battle error:', err);
    res.status(500).json({ error: 'Failed to determine the battle result. Please try again.' });
  }
});

// POST /api/battle/quick
// Lightweight AI battle — returns winner with minimal narration.
// Same validation/sanitization as /api/battle but uses a shorter Claude prompt
// (~4× fewer tokens). Used by tournament Quick Mode on the iOS client.
router.post('/battle/quick', rateLimitMiddleware, async (req: Request, res: Response): Promise<void> => {
  const body = req.body as Record<string, unknown>;

  const rawF1     = body['fighter1'];
  const rawF2     = body['fighter2'];
  const rawF1Name = body['fighter1Name'];
  const rawF2Name = body['fighter2Name'];
  const rawEnvName = body['environmentName'];

  if (typeof rawF1 !== 'string' || typeof rawF2 !== 'string') {
    res.status(400).json({ error: 'fighter1 and fighter2 must be strings.' });
    return;
  }

  const fighter1 = rawF1.trim().toLowerCase().slice(0, 80);
  const fighter2 = rawF2.trim().toLowerCase().slice(0, 80);

  if (!fighter1 || !fighter2) {
    res.status(400).json({ error: 'Both fighter1 and fighter2 are required.' });
    return;
  }
  if (fighter1 === fighter2) {
    res.status(400).json({ error: 'A fighter cannot battle itself.' });
    return;
  }

  const isCustom1 = !VALID_ANIMALS.has(fighter1);
  const isCustom2 = !VALID_ANIMALS.has(fighter2);

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

  const environmentName = typeof rawEnvName === 'string' ? rawEnvName.trim().slice(0, 40) : undefined;

  // Log custom creatures
  if (isCustom1 && fighter1Name) {
    logCustomCreature(fighter1Name, isCustom2 ? (fighter2Name ?? fighter2) : fighter2, environmentName);
  }
  if (isCustom2 && fighter2Name) {
    logCustomCreature(fighter2Name, isCustom1 ? (fighter1Name ?? fighter1) : fighter1, environmentName);
  }

  try {
    const result = await getQuickBattleResult(fighter1, fighter2, fighter1Name, fighter2Name, environmentName);
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
    console.error('Quick battle error:', err);
    res.status(500).json({ error: 'Failed to determine the quick battle result. Please try again.' });
  }
});

// POST /api/battle/melee
// N-vs-M team battle. Body: { teamA: [{id,name?}], teamB: [{id,name?}], environment?, environmentName? }
// Returns { winningTeam, narration, funFact, mvp, teamAHealth, teamBHealth }
router.post('/battle/melee', rateLimitMiddleware, async (req: Request, res: Response): Promise<void> => {
  const { teamA, teamB, environmentName } = req.body ?? {};

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
      const id = (f as { id?: unknown }).id;
      if (typeof id !== 'string' || id.trim() === '') return null;
      const rawName = (f as { name?: unknown }).name;
      let name: string | undefined;
      if (typeof rawName === 'string') {
        const s = sanitizeName(rawName);
        name = s.ok ? s.value : undefined;
      }
      out.push({ id: id.trim(), name });
    }
    return out;
  };
  const normTeamA = norm(teamA);
  const normTeamB = norm(teamB);
  if (!normTeamA || !normTeamB) {
    res.status(400).json({ error: 'each fighter entry must have a string id' });
    return;
  }

  // Log any custom (non-whitelist) fighter names so we can track demand.
  const { ANIMAL_NAMES_EXPORT } = await import('../services/claudeService');
  const logTeam = (team: { id: string; name?: string }[], opponentLabel: string) => {
    team.forEach(f => {
      if (f.name && !(f.id in ANIMAL_NAMES_EXPORT)) {
        logCustomCreature(f.name, opponentLabel, environmentName);
      }
    });
  };
  logTeam(normTeamA, `melee vs team of ${normTeamB.length}`);
  logTeam(normTeamB, `melee vs team of ${normTeamA.length}`);

  try {
    const result: MeleeResult = await getMeleeResult(normTeamA, normTeamB, environmentName);
    res.json(result);
    // Log a summary row: MVP vs the first fighter on the losing team.
    // Melee data is admin-dashboard-only; the public leaderboard filters mode='full'.
    res.on('finish', () => {
      const winners = result.winningTeam === 'A' ? normTeamA : normTeamB;
      const losers  = result.winningTeam === 'A' ? normTeamB : normTeamA;
      const mvp     = winners.find(f => f.id === result.mvp) ?? winners[0];
      const opp     = losers[0];
      if (!mvp || !opp) return;
      const mvpIsCustom = !VALID_ANIMALS.has(mvp.id);
      const oppIsCustom = !VALID_ANIMALS.has(opp.id);
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
    console.error('Melee error:', err);
    res.status(500).json({ error: 'Failed to resolve the melee. Please try again.' });
  }
});

// GET /api/admin/custom-creatures
// Returns a live report of all custom creature requests since last deploy.
// Protected by a simple secret header to prevent public access.
router.get('/admin/custom-creatures', (req: Request, res: Response): void => {
  const secret = process.env.ADMIN_SECRET;
  const provided = req.headers['x-admin-secret'];

  if (!secret || provided !== secret) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  res.json(getCustomCreatureReport());
});

// GET /api/leaderboard — PUBLIC
// Returns built-in animal stats for the in-app Hall of Fame.
// Filters: mode='full', is_custom1=false AND is_custom2=false.
router.get('/leaderboard', rateLimitMiddleware, async (_req: Request, res: Response): Promise<void> => {
  try {
    const board = await getAnimalLeaderboard(25);
    res.json(board);
  } catch (err) {
    console.error('Leaderboard error:', err);
    res.status(500).json({ error: 'Failed to load leaderboard.' });
  }
});

// GET /admin/dashboard?token=… — PRIVATE HTML PAGE
// Renders a self-contained admin dashboard with three tables:
//   1. Top custom creatures (case-insensitive name aggregation)
//   2. Top built-in animals
//   3. Recent activity (last 200 battles)
// Token accepted via ?token= query string OR x-admin-secret header.
router.get('/admin/dashboard', async (req: Request, res: Response): Promise<void> => {
  const secret = process.env.ADMIN_SECRET;
  const provided = (req.query.token as string | undefined) ?? req.headers['x-admin-secret'];
  if (!secret || provided !== secret) {
    res.status(401).type('text/html').send('<h1>401 Unauthorized</h1><p>Provide ?token=&lt;ADMIN_SECRET&gt; or x-admin-secret header.</p>');
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
</style>
</head>
<body>
<h1>🐾 Animal vs Animal — Admin Dashboard</h1>
<div class="muted">Total full-mode battles: ${data.animals.totalBattles.toLocaleString()} · Generated ${esc(data.animals.generatedAt)}</div>

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
