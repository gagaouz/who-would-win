import { Router, Request, Response } from 'express';
import { getBattleResult } from '../services/claudeService';
import { rateLimitMiddleware } from '../middleware/rateLimit';
import { sanitizeName } from '../middleware/sanitize';

const router = Router();

// Whitelist of all valid animal IDs
const VALID_ANIMALS = new Set<string>([
  'lion', 'tiger', 'grizzly_bear', 'wolf', 'elephant', 'rhinoceros',
  'hippopotamus', 'gorilla', 'cheetah', 'crocodile', 'komodo_dragon',
  'wolverine', 'honey_badger', 'giraffe', 'zebra', 'moose', 'boar',
  'tarantula', 'scorpion', 'cobra', 'great_white_shark', 'orca',
  'giant_squid', 'piranha', 'octopus', 'barracuda', 'electric_eel',
  'hammerhead_shark', 'mantis_shrimp', 'blue_ringed_octopus', 'swordfish',
  'coelacanth', 'bald_eagle', 'peregrine_falcon', 'harpy_eagle', 'barn_owl',
  'pterodactyl', 'hornet', 'dragonfly', 'albatross', 'pelican', 'crow',
  'army_ant', 'bombardier_beetle', 'bullet_ant', 'praying_mantis',
  'fire_ant', 'centipede', 'wasp', 'stag_beetle',
]);

// POST /api/battle
router.post('/battle', rateLimitMiddleware, async (req: Request, res: Response): Promise<void> => {
  const body = req.body as Record<string, unknown>;

  // ── Type-check raw fields ──────────────────────────────────────────────────
  const rawF1    = body['fighter1'];
  const rawF2    = body['fighter2'];
  const rawF1Name = body['fighter1Name'];
  const rawF2Name = body['fighter2Name'];

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

  // ── Call Claude ────────────────────────────────────────────────────────────
  try {
    const result = await getBattleResult(fighter1, fighter2, fighter1Name, fighter2Name);
    res.json(result);
  } catch (err) {
    console.error('Battle error:', err);
    res.status(500).json({ error: 'Failed to determine the battle result. Please try again.' });
  }
});

export default router;
