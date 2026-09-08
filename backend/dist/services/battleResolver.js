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
// Fine-grained realism nudges WITHIN a tier (fractional). The integer tier
// table is coarse — these express well-established 1v1 edges between same-tier
// creatures without bumping anyone a full tier. Effective power is
// 2^(tier + adjust). KEEP IN SYNC with the iOS app's OnDeviceTiers.tierAdjust.
//   • Tiger beats Lion: bigger, more muscular, a solitary fighter (lions evolved
//     for pack combat). Historical staged fights + expert consensus favor tigers.
const TIER_ADJUST = {
    tiger: 0.45, // edges its tier-6 peers (lion, gorilla) in single combat
};
function isKnown(id) {
    return id in claudeService_1.POWER_PROFILES || claudeService_1.DEITY_IDS.has(id);
}
function getTier(id) {
    if (claudeService_1.DEITY_IDS.has(id))
        return 10;
    return claudeService_1.POWER_PROFILES[id]?.tier ?? null;
}
/** Integer tier + fractional realism nudge. */
function getEffectiveTier(id) {
    const t = getTier(id);
    return t === null ? null : t + (TIER_ADJUST[id] ?? 0);
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
function powerScore(id, environmentName, customTier) {
    // A custom creature uses its estimated tier (no fractional realism nudge);
    // a known creature uses its profile tier + nudge.
    const tier = isKnown(id)
        ? getEffectiveTier(id)
        : (customTier != null ? customTier : null);
    if (tier === null)
        return 0; // unknown — caller will skip force
    const env = envModifier(id, environmentName);
    return Math.pow(2, tier) * env;
}
function resolveBattle(args) {
    const { fighter1Id, fighter2Id, environmentName, customTier1, customTier2 } = args;
    const f1Known = isKnown(fighter1Id);
    const f2Known = isKnown(fighter2Id);
    // A custom fighter is "resolvable" once we have an estimated tier for it.
    const f1Resolvable = f1Known || (customTier1 != null);
    const f2Resolvable = f2Known || (customTier2 != null);
    // ── Truly unknown (no estimate) → leave to AI ───────────────────────────
    // Only when we have NO tier at all for a custom fighter do we defer to Claude.
    if (!f1Resolvable || !f2Resolvable) {
        return { kind: 'open', reason: 'custom fighter without a tier estimate — AI decides' };
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
    const s1 = powerScore(fighter1Id, environmentName, customTier1);
    const s2 = powerScore(fighter2Id, environmentName, customTier2);
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
    return (`\n🔒 OUTCOME ALREADY DECIDED: ${winnerName} WINS (${v.reason}).\n` +
        `This verdict is FINAL — the game's referee has already ruled. Your job is to ` +
        `write the narration explaining WHY ${winnerName} defeats ${loserName} in a way ` +
        `kids will find satisfying. Cite real biology, size, weapons, or arena conditions. ` +
        `DO NOT pick a different winner — the JSON's "winner" field MUST be ` +
        `"${v.winnerId}". Any other value will be rejected and the response thrown out.\n\n`);
}
