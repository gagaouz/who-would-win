"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEITY_IDS = exports.CREATURES = void 0;
exports.getCreature = getCreature;
exports.isBuiltIn = isBuiltIn;
exports.isDeity = isDeity;
exports.displayName = displayName;
exports.effectiveTier = effectiveTier;
exports.isLandArena = isLandArena;
exports.envModifier = envModifier;
exports.survivalWarning = survivalWarning;
/**
 * Master creature list — the ONE source of truth for every built-in fighter.
 *
 * `creatures.json` holds each creature's display name, habitat, power tier and
 * a short kid-safe profile. The server's resolvers and prompts read it here;
 * the iOS app's OnDeviceTiers.swift is GENERATED from the same file by
 * `scripts/sync_creatures.mjs` (which also checks the iOS roster matches).
 * Add or change a creature in the JSON, never in code.
 */
const creatures_json_1 = __importDefault(require("./creatures.json"));
const HABITATS = new Set(['land', 'sea', 'air', 'deity']);
function load(entries) {
    if (!Array.isArray(entries))
        throw new Error('creatures.json must be an array');
    const seen = new Set();
    for (const c of entries) {
        if (!/^[a-z0-9_]+$/.test(c.id) || seen.has(c.id))
            throw new Error(`creatures.json: bad or duplicate id "${c.id}"`);
        if (!c.name || !c.blurb || !c.fact || !HABITATS.has(c.habitat))
            throw new Error(`creatures.json: incomplete entry "${c.id}"`);
        if (!Number.isInteger(c.tier) || c.tier < 1 || c.tier > 10)
            throw new Error(`creatures.json: bad tier for "${c.id}"`);
        if (c.adjust !== undefined && Math.abs(c.adjust) >= 1)
            throw new Error(`creatures.json: adjust must be < 1 for "${c.id}"`);
        seen.add(c.id);
    }
    return entries;
}
exports.CREATURES = load(creatures_json_1.default);
const BY_ID = new Map(exports.CREATURES.map(c => [c.id, c]));
function getCreature(id) {
    return BY_ID.get(id);
}
/** True for any of the app's built-in fighters (custom creatures use UUID ids). */
function isBuiltIn(id) {
    return BY_ID.has(id);
}
exports.DEITY_IDS = new Set(exports.CREATURES.filter(c => c.habitat === 'deity').map(c => c.id));
function isDeity(id) {
    return exports.DEITY_IDS.has(id);
}
/** The name kids see. Built-ins always use the master name; anything else uses
 *  the supplied (already sanitized) name, never a raw id. */
function displayName(id, suppliedName) {
    return BY_ID.get(id)?.name ?? suppliedName ?? id.replace(/_/g, ' ');
}
/** Tier + realism nudge, or null for a custom/unknown fighter. */
function effectiveTier(id) {
    const c = BY_ID.get(id);
    return c ? c.tier + (c.adjust ?? 0) : null;
}
const LAND_ARENAS = new Set(['Grassland', 'Jungle', 'Volcano', 'Desert', 'Arctic']);
function isLandArena(environmentName) {
    return environmentName !== undefined && LAND_ARENAS.has(environmentName);
}
/**
 * Arena effectiveness (0 = can't function, 1 = home turf). The ONLY copy on the
 * server — both resolvers call this, and the iOS OnDeviceResolver mirrors it.
 *   Ocean (fully underwater): sea 1.0 · swimmers 0.5 · everyone else drowns 0.10
 *   Sky: air creatures and winged land creatures 1.0 · everyone else falls 0.05
 *   Land arenas: land 1.0 · air 0.85 · sea creatures are beached 0.05
 *   Night / Storm / no arena: 1.0
 * Custom creatures (unknown habitat) get mild, neutral-ish values.
 */
function envModifier(id, environmentName) {
    if (!environmentName)
        return 1.0;
    const c = BY_ID.get(id);
    if (c?.habitat === 'deity')
        return 1.0;
    if (!c) {
        if (environmentName === 'Ocean')
            return 0.6;
        if (environmentName === 'Sky')
            return 0.5;
        if (LAND_ARENAS.has(environmentName))
            return 0.9;
        return 1.0;
    }
    if (environmentName === 'Ocean') {
        if (c.habitat === 'sea')
            return 1.0;
        if (c.swims)
            return 0.5;
        return 0.10;
    }
    if (environmentName === 'Sky') {
        if (c.habitat === 'air' || c.flies)
            return 1.0;
        return 0.05;
    }
    if (LAND_ARENAS.has(environmentName)) {
        if (c.habitat === 'sea')
            return 0.05;
        if (c.habitat === 'air')
            return 0.85;
        return 1.0;
    }
    return 1.0;
}
/** Prompt note describing how the arena affects this fighter ('' = no issue).
 *  Mirrors envModifier so the story never contradicts the referee. */
function survivalWarning(id, name, environmentName) {
    const c = BY_ID.get(id);
    if (!c || c.habitat === 'deity')
        return '';
    if (environmentName === 'Ocean' && c.habitat !== 'sea') {
        return c.swims
            ? `NOTE: ${name} can swim, but deep open ocean is not its home — it is much slower and weaker here.\n`
            : `SURVIVAL WARNING: ${name} is not built for deep water and cannot keep up here — a near-certain loss. Keep it safe in the story: it paddles back to shore.\n`;
    }
    if (environmentName === 'Sky' && c.habitat !== 'air' && !c.flies) {
        return `SURVIVAL WARNING: ${name} cannot fly, so it can't keep up in a sky battle — a near-certain loss. Keep it safe in the story: it drifts gently down to a soft landing.\n`;
    }
    if (isLandArena(environmentName) && c.habitat === 'sea') {
        return `SURVIVAL WARNING: ${name} is a water animal — on land it can barely move, a near-certain loss. Keep it safe in the story: it wriggles back to the water.\n`;
    }
    if (environmentName === 'Arctic' && c.habitat === 'land' && !c.arctic) {
        return `NOTE: ${name} is not built for snow and ice and will struggle with the cold.\n`;
    }
    return '';
}
