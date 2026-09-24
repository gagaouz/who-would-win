/**
 * Private, temporary creature-request tally. Names are never written to a
 * database or process logs, and no app, device, or network identity is stored.
 * A restart clears the list. Entries also expire after 90 days of inactivity.
 */
import { CREATURES } from '../data/creatures';
import { sanitizeName } from '../middleware/sanitize';

const RETENTION_DAYS = 90;
const MAX_ENTRIES = 5000;
const RETENTION_MS = RETENTION_DAYS * 24 * 60 * 60 * 1000;

export interface CustomCreatureEntry {
  name: string;
  displayName: string;
  /** Completed battle appearances, separate from creature lookups. */
  count: number;
  lookupCount: number;
  attemptCount: number;
  wins: number;
  firstSeen: string;
  lastSeen: string;
  opponentNames: string[];
}

// Insertion order is last-seen order, so pruning never sorts the whole store.
const store = new Map<string, CustomCreatureEntry>();
let capturedSince = new Date(Date.now()).toISOString();
let evictedCount = 0;
let expiredCount = 0;

function normalize(name: string): string {
  return name.normalize('NFKC').toLocaleLowerCase('en-US').trim().replace(/\s+/g, ' ');
}

const builtInNames = new Set(CREATURES.flatMap(creature => [
  normalize(creature.name), normalize(creature.id), normalize(creature.id.replace(/_/g, ' ')),
]));

function safeName(value: string): string | undefined {
  const result = sanitizeName(value);
  return result.ok ? result.value : undefined;
}

/** Prune on writes, reads, and hourly even when no requests arrive. */
function pruneStore(): void {
  const cutoff = Date.now() - RETENTION_MS;
  for (const [key, entry] of store) {
    if (Date.parse(entry.lastSeen) > cutoff) break;
    store.delete(key);
    expiredCount += 1;
  }
  while (store.size > MAX_ENTRIES) {
    const oldest = store.keys().next().value as string | undefined;
    if (!oldest) break;
    store.delete(oldest);
    evictedCount += 1;
  }
}

setInterval(pruneStore, 60 * 60 * 1000).unref();

function record(name: string, kind: 'lookup' | 'attempt' | 'completed', opponentName?: string, won = false): void {
  const accepted = safeName(name);
  if (!accepted) return;
  if (kind === 'lookup' && (builtInNames.has(normalize(accepted)) || builtInNames.has(normalize(name)))) return;

  pruneStore();
  const key = normalize(accepted);
  const now = new Date(Date.now()).toISOString();
  const entry: CustomCreatureEntry = store.get(key) ?? {
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
  } else if (kind === 'attempt') {
    entry.attemptCount += 1;
  } else {
    entry.count += 1;
    if (won) entry.wins += 1;
    const opponent = opponentName ? safeName(opponentName) : undefined;
    if (opponent) {
      entry.opponentNames.push(opponent);
      if (entry.opponentNames.length > 10) entry.opponentNames.shift();
    }
  }
  store.delete(key);
  store.set(key, entry);
  pruneStore();
}

/** An accepted classification request, even if AI generation later fails. */
export function logCustomCreatureLookup(name: string): void {
  record(name, 'lookup');
}

/** An accepted battle attempt, recorded before generation so failures remain visible. */
export function logCustomCreatureAttempt(name: string): void {
  record(name, 'attempt');
}

/** A completed cloud battle appearance. Keep retries out at the route layer. */
export function logCustomCreature(
  customName: string,
  opponentName: string,
  _arena?: string,
  won = false,
): void {
  record(customName, 'completed', opponentName, won);
}

/** Wipe the list and its reporting window, without retaining name tombstones. */
export function purgeAllCustomCreatures(): number {
  const count = store.size;
  store.clear();
  capturedSince = new Date(Date.now()).toISOString();
  evictedCount = 0;
  expiredCount = 0;
  return count;
}

/** Every available name is returned; pagination belongs to the dashboard. */
export function getCustomCreatureReport(): {
  totalUniqueCreatures: number;
  totalBattles: number;
  totalLookups: number;
  totalAttempts: number;
  topCreatures: CustomCreatureEntry[];
  generatedAt: string;
  capturedSince: string;
  retentionDays: number;
  capacity: number;
  storageMode: 'temporary-memory';
  evictedCount: number;
  expiredCount: number;
  truncated: boolean;
} {
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
