"use strict";
/**
 * Custom Creature Logger
 *
 * Tracks every custom (user-typed) creature name that gets battled.
 * Two layers:
 *   1. console.log in structured JSON → searchable in Railway logs forever
 *   2. In-memory tally → queryable via /api/admin/custom-creatures between deploys
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.logCustomCreature = logCustomCreature;
exports.getCustomCreatureReport = getCustomCreatureReport;
// In-memory store: normalized name → entry
const store = new Map();
function normalize(name) {
    return name.toLowerCase().trim().replace(/\s+/g, ' ');
}
/**
 * Log a custom creature request. Call this whenever a battle involves a
 * custom (non-whitelist) fighter.
 */
function logCustomCreature(customName, opponentName, arena) {
    const key = normalize(customName);
    const now = new Date().toISOString();
    // Update in-memory tally
    const existing = store.get(key);
    if (existing) {
        existing.count += 1;
        existing.lastSeen = now;
        if (existing.opponentNames.length < 10) {
            existing.opponentNames.push(opponentName);
        }
        else {
            existing.opponentNames.shift();
            existing.opponentNames.push(opponentName);
        }
    }
    else {
        store.set(key, {
            name: key,
            displayName: customName.trim(),
            count: 1,
            firstSeen: now,
            lastSeen: now,
            opponentNames: [opponentName],
        });
    }
    // Structured log line — shows up in `railway logs` and is grep-able
    console.log(JSON.stringify({
        event: 'custom_creature_battle',
        customCreature: customName.trim(),
        opponent: opponentName,
        arena: arena ?? null,
        timestamp: now,
    }));
}
/**
 * Return the current in-memory tally, sorted by count descending.
 */
function getCustomCreatureReport() {
    const entries = Array.from(store.values()).sort((a, b) => b.count - a.count);
    const totalBattles = entries.reduce((sum, e) => sum + e.count, 0);
    return {
        totalUniqueCreatures: entries.length,
        totalBattles,
        topCreatures: entries,
        generatedAt: new Date().toISOString(),
    };
}
