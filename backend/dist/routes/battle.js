"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const claudeService_1 = require("../services/claudeService");
const rateLimit_1 = require("../middleware/rateLimit");
const sanitize_1 = require("../middleware/sanitize");
const router = (0, express_1.Router)();
// ── In-memory battle result cache ──────────────────────────────────────────────
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour
const MAX_RESULTS_PER_KEY = 3;
const battleCache = new Map();
function makeCacheKey(f1, f2, env) {
    return [f1, f2].sort().join('-') + '-' + (env || 'none');
}
function getCachedResult(key) {
    const entry = battleCache.get(key);
    if (!entry)
        return null;
    if (Date.now() - entry.createdAt >= CACHE_TTL_MS) {
        battleCache.delete(key);
        return null;
    }
    return entry.results[Math.floor(Math.random() * entry.results.length)];
}
function storeCachedResult(key, result) {
    const entry = battleCache.get(key);
    if (entry && Date.now() - entry.createdAt < CACHE_TTL_MS) {
        if (entry.results.length < MAX_RESULTS_PER_KEY) {
            entry.results.push(result);
        }
        else {
            // Rotate: replace the oldest entry
            entry.results.shift();
            entry.results.push(result);
        }
    }
    else {
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
const VALID_ANIMALS = new Set([
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
router.post('/battle', rateLimit_1.rateLimitMiddleware, async (req, res) => {
    const body = req.body;
    // ── Type-check raw fields ──────────────────────────────────────────────────
    const rawF1 = body['fighter1'];
    const rawF2 = body['fighter2'];
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
    let fighter1Name;
    let fighter2Name;
    const isCustom1 = !VALID_ANIMALS.has(fighter1);
    const isCustom2 = !VALID_ANIMALS.has(fighter2);
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
    // ── Call Claude (with cache) ───────────────────────────────────────────────
    const environmentName = typeof rawEnvName === 'string' ? rawEnvName.trim().slice(0, 40) : undefined;
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
        const result = await (0, claudeService_1.getBattleResult)(fighter1, fighter2, fighter1Name, fighter2Name, environmentName, tournamentContext);
        if (!isTournamentBattle) {
            storeCachedResult(cacheKey, result);
        }
        res.json(result);
    }
    catch (err) {
        console.error('Battle error:', err);
        res.status(500).json({ error: 'Failed to determine the battle result. Please try again.' });
    }
});
// POST /api/battle/quick
// Lightweight AI battle — returns winner with minimal narration.
// Same validation/sanitization as /api/battle but uses a shorter Claude prompt
// (~4× fewer tokens). Used by tournament Quick Mode on the iOS client.
router.post('/battle/quick', rateLimit_1.rateLimitMiddleware, async (req, res) => {
    const body = req.body;
    const rawF1 = body['fighter1'];
    const rawF2 = body['fighter2'];
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
    const environmentName = typeof rawEnvName === 'string' ? rawEnvName.trim().slice(0, 40) : undefined;
    try {
        const result = await (0, claudeService_1.getQuickBattleResult)(fighter1, fighter2, fighter1Name, fighter2Name, environmentName);
        res.json(result);
    }
    catch (err) {
        console.error('Quick battle error:', err);
        res.status(500).json({ error: 'Failed to determine the quick battle result. Please try again.' });
    }
});
exports.default = router;
