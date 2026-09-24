"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logCustomCreatureLookup = logCustomCreatureLookup;
exports.logCustomCreatureAttempt = logCustomCreatureAttempt;
exports.logCustomCreature = logCustomCreature;
exports.purgeAllCustomCreatures = purgeAllCustomCreatures;
exports.getCustomCreatureReport = getCustomCreatureReport;
/**
 * Private, temporary creature-request tally. Names are never written to a
 * database or process logs, and no app, device, or network identity is stored.
 * A restart clears the list. Entries also expire after 90 days of inactivity.
 */
const creatures_1 = require("../data/creatures");
const sanitize_1 = require("../middleware/sanitize");
const RETENTION_DAYS = 90;
const MAX_ENTRIES = 5000;
const RETENTION_MS = RETENTION_DAYS * 24 * 60 * 60 * 1000;
// Insertion order is last-seen order, so pruning never sorts the whole store.
const store = new Map();
let capturedSince = new Date(Date.now()).toISOString();
let evictedCount = 0;
let expiredCount = 0;
function normalize(name) {
    return name.normalize('NFKC').toLocaleLowerCase('en-US').trim().replace(/\s+/g, ' ');
}
const builtInNames = new Set(creatures_1.CREATURES.flatMap(creature => [
    normalize(creature.name), normalize(creature.id), normalize(creature.id.replace(/_/g, ' ')),
]));
function safeName(value) {
    const result = (0, sanitize_1.sanitizeName)(value);
    return result.ok ? result.value : undefined;
}
/** Prune on writes, reads, and hourly even when no requests arrive. */
function pruneStore() {
    const cutoff = Date.now() - RETENTION_MS;
    for (const [key, entry] of store) {
        if (Date.parse(entry.lastSeen) > cutoff)
            break;
        store.delete(key);
        expiredCount += 1;
    }
    while (store.size > MAX_ENTRIES) {
        const oldest = store.keys().next().value;
        if (!oldest)
            break;
        store.delete(oldest);
        evictedCount += 1;
    }
}
setInterval(pruneStore, 60 * 60 * 1000).unref();
function record(name, kind, opponentName, won = false) {
    const accepted = safeName(name);
    if (!accepted)
        return;
    if (kind === 'lookup' && (builtInNames.has(normalize(accepted)) || builtInNames.has(normalize(name))))
        return;
    pruneStore();
    const key = normalize(accepted);
    const now = new Date(Date.now()).toISOString();
    const entry = store.get(key) ?? {
        name: key,
        displayName: accepted,
        count: 0,
        lookupCount: 0,
        attemptCount: 0,
        wins: 0,
        firstSeen: now,
        lastSeen: now,
        opponentNames: [],
    };
    entry.lastSeen = now;
    if (kind === 'lookup') {
        entry.lookupCount += 1;
    }
    else if (kind === 'attempt') {
        entry.attemptCount += 1;
    }
    else {
        entry.count += 1;
        if (won)
            entry.wins += 1;
        const opponent = opponentName ? safeName(opponentName) : undefined;
        if (opponent) {
            entry.opponentNames.push(opponent);
            if (entry.opponentNames.length > 10)
                entry.opponentNames.shift();
        }
    }
    store.delete(key);
    store.set(key, entry);
    pruneStore();
}
/** An accepted classification request, even if AI generation later fails. */
function logCustomCreatureLookup(name) {
    record(name, 'lookup');
}
/** An accepted battle attempt, recorded before generation so failures remain visible. */
function logCustomCreatureAttempt(name) {
    record(name, 'attempt');
}
/** A completed cloud battle appearance. Keep retries out at the route layer. */
function logCustomCreature(customName, opponentName, _arena, won = false) {
    record(customName, 'completed', opponentName, won);
}
/** Wipe the list and its reporting window, without retaining name tombstones. */
function purgeAllCustomCreatures() {
    const count = store.size;
    store.clear();
    capturedSince = new Date(Date.now()).toISOString();
    evictedCount = 0;
    expiredCount = 0;
    return count;
}
/** Every available name is returned; pagination belongs to the dashboard. */
function getCustomCreatureReport() {
    pruneStore();
    const entries = Array.from(store.values())
        .sort((a, b) => b.count - a.count || (b.lookupCount + b.attemptCount) - (a.lookupCount + a.attemptCount)
        || b.lastSeen.localeCompare(a.lastSeen) || a.name.localeCompare(b.name))
        .map(entry => ({ ...entry, opponentNames: [...entry.opponentNames] }));
    return {
        totalUniqueCreatures: entries.length,
        totalBattles: entries.reduce((sum, entry) => sum + entry.count, 0),
        totalLookups: entries.reduce((sum, entry) => sum + entry.lookupCount, 0),
        totalAttempts: entries.reduce((sum, entry) => sum + entry.attemptCount, 0),
        topCreatures: entries,
        generatedAt: new Date(Date.now()).toISOString(),
        capturedSince,
        retentionDays: RETENTION_DAYS,
        capacity: MAX_ENTRIES,
        storageMode: 'temporary-memory',
        evictedCount,
        expiredCount,
        truncated: evictedCount > 0,
    };
}
