"use strict";
/**
 * Custom Creature Logger
 *
 * Tracks the custom (user-typed) creature NAMES kids battle, so we can see what
 * creatures to add. Privacy-conscious for a kids app:
 *   - The raw kid-typed name is NOT written to the permanent process log
 *     anymore (only an anonymous event + arena), so it isn't retained "forever"
 *     in Railway logs.
 *   - The in-memory tally (which keeps names for the report) is BOUNDED: it
 *     ages out entries older than RETENTION_DAYS and caps the store size.
 *   - purgeAll() wipes everything (backs the parent "delete my data" path).
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.logCustomCreature = logCustomCreature;
exports.purgeAllCustomCreatures = purgeAllCustomCreatures;
exports.getCustomCreatureReport = getCustomCreatureReport;
const RETENTION_DAYS = 90;
const MAX_ENTRIES = 5000;
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
    // Bound retention: age out stale entries and cap the store size so kid-typed
    // names are never kept indefinitely.
    pruneStore();
    // Anonymous metric only — the raw kid-typed name is intentionally NOT written
    // to the permanent process log. Names live only in the bounded in-memory
    // tally above (for the "what creatures do kids want" report).
    console.log(JSON.stringify({
        event: 'custom_creature_battle',
        arena: arena ?? null,
        timestamp: now,
    }));
}
/** Drop entries older than RETENTION_DAYS, then trim to MAX_ENTRIES by recency. */
function pruneStore() {
    const cutoff = Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000;
    for (const [key, entry] of store) {
        if (new Date(entry.lastSeen).getTime() < cutoff)
            store.delete(key);
    }
    if (store.size > MAX_ENTRIES) {
        const sorted = Array.from(store.entries())
            .sort((a, b) => new Date(b[1].lastSeen).getTime() - new Date(a[1].lastSeen).getTime());
        store.clear();
        for (const [k, v] of sorted.slice(0, MAX_ENTRIES))
            store.set(k, v);
    }
}
/** Wipe all stored custom-creature data (backs the "delete my data" path). */
function purgeAllCustomCreatures() {
    const n = store.size;
    store.clear();
    return n;
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
