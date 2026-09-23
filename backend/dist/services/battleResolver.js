"use strict";
/**
 * Deterministic Battle Resolver
 *
 * Decides the winner of a matchup using power tiers, environment compatibility,
 * and small bounded randomness for close fights. Returns a verdict object that
 * tells the caller whether the outcome should be enforced (high certainty) or
 * left to the AI (close call / unknown fighter).
 *
 * Why this exists
 * ────────────────
 * Letting Claude both PICK the winner AND write the narration creates an
 * engagement bias toward dramatic upsets — a bullet ant beating a harpy eagle,
 * an orca beating an eagle on grassland, etc. The fix: when at least one
 * fighter is a known animal AND the matchup is clear-cut (3+ tier gap, fatal
 * environment, deity vs mortal), the resolver picks the winner and the AI is
 * only asked to write the narration. The AI cannot fabricate the outcome.
 *
 * Close fights and matchups involving unknown custom creatures fall through
 * to the AI, which is the right choice — we can't deterministically resolve
 * "Pikachu vs Sonic the Hedgehog" from a table.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveBattle = resolveBattle;
exports.verdictPromptLine = verdictPromptLine;
const creatures_1 = require("../data/creatures");
/**
 * Power score = 2^tier × envModifier. Exponential tier scaling makes a 3-tier
 * gap = 8× advantage, which is the threshold above which we treat a battle as
 * "decided" rather than a close fight.
 */
function powerScore(id, environmentName, customTier) {
    // A custom creature uses its estimated tier (no fractional realism nudge);
    // a known creature uses its profile tier + nudge.
    const tier = (0, creatures_1.isBuiltIn)(id)
        ? (0, creatures_1.effectiveTier)(id)
        : (customTier != null ? customTier : null);
    if (tier === null)
        return 0; // unknown — caller will skip force
    const env = (0, creatures_1.envModifier)(id, environmentName);
    return Math.pow(2, tier) * env;
}
function resolveBattle(args) {
    const { fighter1Id, fighter2Id, environmentName, customTier1, customTier2 } = args;
    const f1Known = (0, creatures_1.isBuiltIn)(fighter1Id);
    const f2Known = (0, creatures_1.isBuiltIn)(fighter2Id);
    // A custom fighter is "resolvable" once we have an estimated tier for it.
    const f1Resolvable = f1Known || (customTier1 != null);
    const f2Resolvable = f2Known || (customTier2 != null);
    // ── Truly unknown (no estimate) → leave to AI ───────────────────────────
    // Only when we have NO tier at all for a custom fighter do we defer to Claude.
    if (!f1Resolvable || !f2Resolvable) {
        return { kind: 'open', reason: 'custom fighter without a tier estimate — AI decides' };
    }
    // ── Deity vs mortal ─────────────────────────────────────────────────────
    const d1 = (0, creatures_1.isDeity)(fighter1Id);
    const d2 = (0, creatures_1.isDeity)(fighter2Id);
    if (d1 && !d2) {
        return { kind: 'forced', winnerId: fighter1Id, loserId: fighter2Id, reason: 'deity vs mortal' };
    }
    if (d2 && !d1) {
        return { kind: 'forced', winnerId: fighter2Id, loserId: fighter1Id, reason: 'deity vs mortal' };
    }
    // ── Power-score comparison (tier + environment) ─────────────────────────
    const s1 = powerScore(fighter1Id, environmentName, customTier1);
    const s2 = powerScore(fighter2Id, environmentName, customTier2);
    // Catastrophic environment incompatibility — if one fighter is reduced to
    // ≤ 0.10 effective power and the other is at full strength, force the loss
    // regardless of tier. This catches orca-on-grassland, lion-in-ocean, etc.
    const env1 = (0, creatures_1.envModifier)(fighter1Id, environmentName);
    const env2 = (0, creatures_1.envModifier)(fighter2Id, environmentName);
    if (env1 <= 0.10 && env2 >= 0.5) {
        return { kind: 'forced', winnerId: fighter2Id, loserId: fighter1Id,
            reason: `${fighter1Id} cannot survive ${environmentName}` };
    }
    if (env2 <= 0.10 && env1 >= 0.5) {
        return { kind: 'forced', winnerId: fighter1Id, loserId: fighter2Id,
            reason: `${fighter2Id} cannot survive ${environmentName}` };
    }
    // DETERMINISTIC: for two known creatures, the higher effective power ALWAYS
    // wins — no AI dice. This is an educational app: a tiger always beats a lion,
    // a crow never beats a pterodactyl, every time. The MODEL still writes a fresh
    // story each run, but the OUTCOME is fixed by realistic power so kids learn
    // the right answer consistently. Exact ties break deterministically by id so
    // resolve(a,b) and resolve(b,a) agree. (Custom/unknown fighters returned
    // 'open' far above — there we have no power data, so the AI judges.)
    const ratio = s1 >= s2 ? s1 / Math.max(s2, 0.0001) : s2 / Math.max(s1, 0.0001);
    let f1Wins;
    if (s1 !== s2) {
        f1Wins = s1 > s2;
    }
    else {
        f1Wins = fighter1Id < fighter2Id; // stable, symmetric tiebreak
    }
    return f1Wins
        ? { kind: 'forced', winnerId: fighter1Id, loserId: fighter2Id, reason: `power advantage ${ratio.toFixed(2)}×` }
        : { kind: 'forced', winnerId: fighter2Id, loserId: fighter1Id, reason: `power advantage ${ratio.toFixed(2)}×` };
}
/**
 * Human-readable line for the prompt. When the verdict is forced, this string
 * is injected so Claude knows what it is narrating BEFORE it generates JSON.
 * When the verdict is open, returns an empty string (no nudge).
 */
function verdictPromptLine(v, name1, name2, fighter1Id) {
    if (v.kind !== 'forced')
        return '';
    const winnerName = v.winnerId === fighter1Id ? name1 : name2;
    const loserName = v.winnerId === fighter1Id ? name2 : name1;
    return (`\n🔒 OUTCOME ALREADY DECIDED: ${winnerName} WINS.\n` +
        `This verdict is FINAL — the game's referee has already ruled. Your job is to ` +
        `write the narration explaining WHY ${winnerName} beats ${loserName} in a way ` +
        `kids will find satisfying. Cite real biology, size, abilities, or arena conditions. ` +
        `DO NOT pick a different winner — the JSON's "winner" field MUST be ` +
        `"${v.winnerId}". Any other value will be rejected and the response thrown out.\n\n`);
}
