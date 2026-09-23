"use strict";
// battleLogger.ts — Postgres-backed battle logging + leaderboard queries.
//
// All exports are safe to call when DATABASE_URL is unset: log calls no-op,
// reads return empty data. Lets local dev run with zero Postgres setup.
Object.defineProperty(exports, "__esModule", { value: true });
exports.initDb = initDb;
exports.pruneAgedCustomNames = pruneAgedCustomNames;
exports.logBattle = logBattle;
exports.getAnimalLeaderboard = getAnimalLeaderboard;
exports.getCustomCreatureLeaderboard = getCustomCreatureLeaderboard;
exports.purgeCustomCreatureNames = purgeCustomCreatureNames;
exports.getRecentActivity = getRecentActivity;
const creatures_1 = require("../data/creatures");
const database_1 = require("./database");
// ── Schema bootstrap ───────────────────────────────────────────────────────────
let initialized = false;
async function initDb() {
    const p = (0, database_1.getDbPool)();
    if (!p) {
        console.log('[battleLogger] DATABASE_URL not set — logging disabled');
        return;
    }
    try {
        await p.query(`
      CREATE TABLE IF NOT EXISTS battles (
        id            BIGSERIAL PRIMARY KEY,
        fighter1_id   TEXT NOT NULL,
        fighter2_id   TEXT NOT NULL,
        fighter1_name TEXT,
        fighter2_name TEXT,
        winner_id     TEXT NOT NULL,
        environment   TEXT,
        is_custom1    BOOLEAN NOT NULL,
        is_custom2    BOOLEAN NOT NULL,
        mode          TEXT NOT NULL,
        created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS battles_fighter1_idx ON battles(fighter1_id);
      CREATE INDEX IF NOT EXISTS battles_fighter2_idx ON battles(fighter2_id);
      CREATE INDEX IF NOT EXISTS battles_mode_idx     ON battles(mode);
      CREATE INDEX IF NOT EXISTS battles_created_idx  ON battles(created_at DESC);

      -- Older builds derived custom IDs from child-entered text. Remove both
      -- that identifier and the display-name copy immediately.
      UPDATE battles
         SET winner_id = CASE
               WHEN is_custom1 AND winner_id = fighter1_id THEN 'custom'
               WHEN is_custom2 AND winner_id = fighter2_id THEN 'custom'
               ELSE winner_id
             END,
             fighter1_id = CASE WHEN is_custom1 THEN 'custom' ELSE fighter1_id END,
             fighter2_id = CASE WHEN is_custom2 THEN 'custom' ELSE fighter2_id END,
             fighter1_name = CASE WHEN is_custom1 THEN NULL ELSE fighter1_name END,
             fighter2_name = CASE WHEN is_custom2 THEN NULL ELSE fighter2_name END
       WHERE is_custom1 OR is_custom2;
    `);
        initialized = true;
        console.log('[battleLogger] Postgres ready');
        // Enforce the privacy policy's 90-day retention promise continuously:
        // once at boot, then daily. unref() so the timer never holds the process.
        void pruneAgedCustomNames();
        setInterval(() => { void pruneAgedCustomNames(); }, 24 * 60 * 60 * 1000).unref();
    }
    catch (err) {
        console.error('[battleLogger] initDb failed:', err.message);
        // Don't throw — battles must still resolve when the DB is broken.
    }
}
// ── Privacy retention ──────────────────────────────────────────────────────────
// Custom free text is not retained at all. This cleanup remains scheduled so
// rows created by an older instance during a rolling deploy are also scrubbed.
async function pruneAgedCustomNames() {
    const p = (0, database_1.getDbPool)();
    if (!p || !initialized)
        return;
    try {
        const res = await p.query(`UPDATE battles
          SET winner_id = CASE
                WHEN is_custom1 AND winner_id = fighter1_id THEN 'custom'
                WHEN is_custom2 AND winner_id = fighter2_id THEN 'custom'
                ELSE winner_id
              END,
              fighter1_id = CASE WHEN is_custom1 THEN 'custom' ELSE fighter1_id END,
              fighter2_id = CASE WHEN is_custom2 THEN 'custom' ELSE fighter2_id END,
              fighter1_name = CASE WHEN is_custom1 THEN NULL ELSE fighter1_name END,
              fighter2_name = CASE WHEN is_custom2 THEN NULL ELSE fighter2_name END
        WHERE (is_custom1 AND (fighter1_id <> 'custom' OR fighter1_name IS NOT NULL))
           OR (is_custom2 AND (fighter2_id <> 'custom' OR fighter2_name IS NOT NULL))`);
        if ((res.rowCount ?? 0) > 0) {
            console.log(`[battleLogger] privacy scrub: de-identified ${res.rowCount} custom battle rows`);
            invalidateCache();
        }
    }
    catch (err) {
        console.error('[battleLogger] pruneAgedCustomNames failed:', err.message);
    }
}
const cache = new Map();
const CACHE_TTL = 5 * 60 * 1000;
async function cached(key, fn) {
    const hit = cache.get(key);
    if (hit && hit.expires > Date.now())
        return hit.value;
    const value = await fn();
    cache.set(key, { value, expires: Date.now() + CACHE_TTL });
    return value;
}
function invalidateCache() {
    cache.clear();
}
async function logBattle(args) {
    const p = (0, database_1.getDbPool)();
    if (!p || !initialized)
        return;
    try {
        await p.query(`INSERT INTO battles
         (fighter1_id, fighter2_id, fighter1_name, fighter2_name,
          winner_id, environment, is_custom1, is_custom2, mode)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`, [
            args.isCustom1 ? 'custom' : args.fighter1Id,
            args.isCustom2 ? 'custom' : args.fighter2Id,
            null,
            null,
            (args.isCustom1 && args.winnerId === args.fighter1Id)
                || (args.isCustom2 && args.winnerId === args.fighter2Id)
                ? 'custom' : args.winnerId,
            args.environment ?? null,
            args.isCustom1,
            args.isCustom2,
            args.mode,
        ]);
        invalidateCache();
    }
    catch (err) {
        console.error('[battleLogger] logBattle failed:', err.message);
        // Best-effort — never bubble up.
    }
}
const MIN_BATTLES_FOR_RATE = 10; // exclude single-game flukes from win-rate ranking
async function getAnimalLeaderboard(limit = 25) {
    return cached(`animal:${limit}`, async () => {
        const p = (0, database_1.getDbPool)();
        if (!p || !initialized) {
            return {
                topByWins: [],
                topByWinRate: [],
                topByPopularity: [],
                totalBattles: 0,
                generatedAt: new Date().toISOString(),
            };
        }
        // Single query produces per-fighter counts across both slots.
        const sql = `
      WITH appearances AS (
        SELECT fighter1_id AS id,
               CASE WHEN winner_id = fighter1_id THEN 1 ELSE 0 END AS won
        FROM battles
        WHERE mode = 'full' AND is_custom1 = FALSE
        UNION ALL
        SELECT fighter2_id AS id,
               CASE WHEN winner_id = fighter2_id THEN 1 ELSE 0 END AS won
        FROM battles
        WHERE mode = 'full' AND is_custom2 = FALSE
      )
      SELECT id,
             COUNT(*)::int AS battles,
             SUM(won)::int AS wins
      FROM appearances
      GROUP BY id
    `;
        const { rows } = await p.query(sql);
        const totalBattlesQ = await p.query(`SELECT COUNT(*)::int AS n FROM battles
        WHERE mode = 'full' AND is_custom1 = FALSE AND is_custom2 = FALSE`);
        const enriched = rows.map(r => ({
            id: r.id,
            name: (0, creatures_1.displayName)(r.id),
            wins: r.wins,
            battles: r.battles,
            winRate: r.battles > 0 ? r.wins / r.battles : 0,
        }));
        return {
            topByWins: [...enriched]
                .sort((a, b) => b.wins - a.wins)
                .slice(0, limit),
            topByWinRate: [...enriched]
                .filter(r => r.battles >= MIN_BATTLES_FOR_RATE)
                .sort((a, b) => b.winRate - a.winRate)
                .slice(0, limit),
            topByPopularity: [...enriched]
                .sort((a, b) => b.battles - a.battles)
                .slice(0, limit),
            totalBattles: totalBattlesQ.rows[0]?.n ?? 0,
            generatedAt: new Date().toISOString(),
        };
    });
}
async function getCustomCreatureLeaderboard(limit = 25) {
    return cached(`custom:${limit}`, async () => {
        const p = (0, database_1.getDbPool)();
        if (!p || !initialized)
            return [];
        const sql = `
      WITH custom_appearances AS (
        SELECT TRIM(LOWER(fighter1_name)) AS name,
               CASE WHEN winner_id = fighter1_id THEN 1 ELSE 0 END AS won,
               created_at,
               COALESCE(fighter2_name, fighter2_id) AS opponent
        FROM battles
        WHERE is_custom1 = TRUE AND fighter1_name IS NOT NULL
        UNION ALL
        SELECT TRIM(LOWER(fighter2_name)) AS name,
               CASE WHEN winner_id = fighter2_id THEN 1 ELSE 0 END AS won,
               created_at,
               COALESCE(fighter1_name, fighter1_id) AS opponent
        FROM battles
        WHERE is_custom2 = TRUE AND fighter2_name IS NOT NULL
      )
      SELECT name,
             COUNT(*)::int AS battles,
             SUM(won)::int AS wins,
             MAX(created_at) AS last_seen,
             (array_agg(opponent ORDER BY created_at DESC))[1] AS sample_opponent
      FROM custom_appearances
      WHERE name IS NOT NULL AND name <> ''
      GROUP BY name
      ORDER BY battles DESC
      LIMIT $1
    `;
        const { rows } = await p.query(sql, [limit]);
        return rows.map(r => ({
            name: r.name,
            battles: r.battles,
            wins: r.wins,
            lastSeen: r.last_seen.toISOString(),
            sampleOpponent: r.sample_opponent ?? '',
        }));
    });
}
// ── Data deletion: erase persisted custom-creature names ───────────────────────
/**
 * COPPA / data-minimization: erase raw child-typed names and name-derived IDs.
 * This backs the admin purge so the "delete data" path actually removes the
 * names everywhere (the in-memory tally alone did not). Returns how many name
 * fields were cleared. No-op when there is no database configured.
 */
async function purgeCustomCreatureNames() {
    const p = (0, database_1.getDbPool)();
    if (!p || !initialized)
        return 0;
    const result = await p.query(`
    UPDATE battles
       SET winner_id = CASE
             WHEN is_custom1 AND winner_id = fighter1_id THEN 'custom'
             WHEN is_custom2 AND winner_id = fighter2_id THEN 'custom'
             ELSE winner_id
           END,
           fighter1_id = CASE WHEN is_custom1 THEN 'custom' ELSE fighter1_id END,
           fighter2_id = CASE WHEN is_custom2 THEN 'custom' ELSE fighter2_id END,
           fighter1_name = CASE WHEN is_custom1 THEN NULL ELSE fighter1_name END,
           fighter2_name = CASE WHEN is_custom2 THEN NULL ELSE fighter2_name END
     WHERE is_custom1 OR is_custom2
  `);
    invalidateCache();
    return result.rowCount ?? 0;
}
async function getRecentActivity(limit = 200) {
    return cached(`recent:${limit}`, async () => {
        const p = (0, database_1.getDbPool)();
        if (!p || !initialized)
            return [];
        const { rows } = await p.query(`SELECT id, fighter1_id, fighter2_id, fighter1_name, fighter2_name,
              winner_id, environment, mode, created_at
       FROM battles
       ORDER BY created_at DESC
       LIMIT $1`, [limit]);
        return rows.map(r => {
            const f1Display = (0, creatures_1.displayName)(r.fighter1_id, r.fighter1_name ?? undefined);
            const f2Display = (0, creatures_1.displayName)(r.fighter2_id, r.fighter2_name ?? undefined);
            let winnerDisplay;
            if (r.winner_id === 'draw') {
                winnerDisplay = 'Draw';
            }
            else if (r.winner_id === r.fighter1_id) {
                winnerDisplay = f1Display;
            }
            else if (r.winner_id === r.fighter2_id) {
                winnerDisplay = f2Display;
            }
            else {
                winnerDisplay = r.winner_id;
            }
            return {
                id: r.id,
                fighter1: f1Display,
                fighter2: f2Display,
                winner: winnerDisplay,
                environment: r.environment,
                mode: r.mode,
                createdAt: r.created_at.toISOString(),
            };
        });
    });
}
