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
const claudeService_1 = require("./claudeService");
// Animals that, despite being categorized as land or air, can survive in an
// alien arena because they're famously cross-environmental.
const SEMI_AQUATIC = new Set(['hippopotamus', 'alligator', 'crocodile']);
function isKnown(id) {
    return id in claudeService_1.POWER_PROFILES || claudeService_1.DEITY_IDS.has(id);
}
function getTier(id) {
    if (claudeService_1.DEITY_IDS.has(id))
        return 10;
    return claudeService_1.POWER_PROFILES[id]?.tier ?? null;
}
/**
 * Environment-effectiveness modifier (0.0 = literally cannot fight, 1.0 = home
 * advantage). This is what mathematically lets a tier-4 eagle beat a tier-9
 * orca on grassland — the orca's effective power is multiplied by 0.05.
 */
function envModifier(id, environmentName) {
    if (!environmentName)
        return 1.0;
    const isSea = claudeService_1.SEA_ANIMALS.has(id);
    const isAir = claudeService_1.AIR_ANIMALS.has(id);
    const isLand = claudeService_1.LAND_ANIMALS.has(id);
    const semi = SEMI_AQUATIC.has(id);
    const arena = environmentName;
    // Deities ignore arena.
    if (claudeService_1.DEITY_IDS.has(id))
        return 1.0;
    // Fantasy / mythic / prehistoric flexibility — let the AI judge.
    // Most of those don't appear in SEA/AIR/LAND sets, so this falls through to 1.0 anyway.
    if (arena === 'Ocean') {
        if (isSea)
            return 1.0;
        if (semi)
            return 0.5;
        if (isAir)
            return 0.10; // drowns
        if (isLand)
            return 0.10; // drowns
        return 0.6;
    }
    if (arena === 'Sky') {
        if (isAir)
            return 1.0;
        if (isSea)
            return 0.05; // can't fly, no water
        if (isLand)
            return 0.05; // falls
        return 0.5;
    }
    if (arena === 'Grassland' || arena === 'Jungle' ||
        arena === 'Volcano' || arena === 'Desert' ||
        arena === 'Arctic') {
        if (isSea && !semi)
            return 0.05; // beached, suffocating
        if (isLand)
            return 1.0;
        if (isAir)
            return 0.85; // can fly but loses altitude advantage in a land brawl
        return 0.9;
    }
    // Night / Storm — generic, no strong preference.
    return 1.0;
}
/**
 * Power score = 2^tier × envModifier. Exponential tier scaling makes a 3-tier
 * gap = 8× advantage, which is the threshold above which we treat a battle as
 * "decided" rather than a close fight.
 */
function powerScore(id, environmentName) {
    const tier = getTier(id);
    if (tier === null)
        return 0; // unknown — caller will skip force
    const env = envModifier(id, environmentName);
    return Math.pow(2, tier) * env;
}
function resolveBattle(args) {
    const { fighter1Id, fighter2Id, environmentName } = args;
    const f1Known = isKnown(fighter1Id);
    const f2Known = isKnown(fighter2Id);
    // ── Custom / unknown fighters → leave to AI ─────────────────────────────
    // If either fighter is a user-typed custom creature, we don't have ground
    // truth on its power. Let Claude decide — but emit a soft prediction when
    // possible (the known fighter's tier vs an assumed mid-tier custom).
    if (!f1Known || !f2Known) {
        return { kind: 'open', reason: 'custom-or-unknown fighter — AI decides' };
    }
    // ── Deity vs mortal ─────────────────────────────────────────────────────
    const d1 = claudeService_1.DEITY_IDS.has(fighter1Id);
    const d2 = claudeService_1.DEITY_IDS.has(fighter2Id);
    if (d1 && !d2) {
        return { kind: 'forced', winnerId: fighter1Id, loserId: fighter2Id, reason: 'deity vs mortal' };
    }
    if (d2 && !d1) {
        return { kind: 'forced', winnerId: fighter2Id, loserId: fighter1Id, reason: 'deity vs mortal' };
    }
    // ── Power-score comparison (tier + environment) ─────────────────────────
    const s1 = powerScore(fighter1Id, environmentName);
    const s2 = powerScore(fighter2Id, environmentName);
    // Catastrophic environment incompatibility — if one fighter is reduced to
    // ≤ 0.10 effective power and the other is at full strength, force the loss
    // regardless of tier. This catches orca-on-grassland, lion-in-ocean, etc.
    const env1 = envModifier(fighter1Id, environmentName);
    const env2 = envModifier(fighter2Id, environmentName);
    if (env1 <= 0.10 && env2 >= 0.5) {
        return { kind: 'forced', winnerId: fighter2Id, loserId: fighter1Id,
            reason: `${fighter1Id} cannot survive ${environmentName}` };
    }
    if (env2 <= 0.10 && env1 >= 0.5) {
        return { kind: 'forced', winnerId: fighter1Id, loserId: fighter2Id,
            reason: `${fighter2Id} cannot survive ${environmentName}` };
    }
    // Power ratio — if one fighter has ≥8× the effective power of the other,
    // force the outcome. (3-tier gap = 8×; 4-tier gap = 16×.) This is the
    // threshold above which real-world physics make the outcome a foregone
    // conclusion: an apex predator does not lose to a creature 8× weaker.
    const ratio = s1 / s2;
    if (ratio >= 8) {
        return { kind: 'forced', winnerId: fighter1Id, loserId: fighter2Id,
            reason: `tier/env advantage ${ratio.toFixed(1)}×` };
    }
    if (ratio <= 1 / 8) {
        return { kind: 'forced', winnerId: fighter2Id, loserId: fighter1Id,
            reason: `tier/env advantage ${(1 / ratio).toFixed(1)}×` };
    }
    // Close-ish match (gap < 3 tiers). Surface a soft prediction (the higher-
    // power side) and let the AI write its own ruling.
    const predicted = s1 >= s2 ? fighter1Id : fighter2Id;
    return {
        kind: 'open',
        predictedWinnerId: predicted,
        reason: `close matchup, ratio ${(s1 >= s2 ? ratio : 1 / ratio).toFixed(2)}×`,
    };
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
    return (`\n🔒 OUTCOME ALREADY DECIDED: ${winnerName} WINS (${v.reason}).\n` +
        `This verdict is FINAL — the game's referee has already ruled. Your job is to ` +
        `write the narration explaining WHY ${winnerName} defeats ${loserName} in a way ` +
        `kids will find satisfying. Cite real biology, size, weapons, or arena conditions. ` +
        `DO NOT pick a different winner — the JSON's "winner" field MUST be ` +
        `"${v.winnerId}". Any other value will be rejected and the response thrown out.\n\n`);
}
