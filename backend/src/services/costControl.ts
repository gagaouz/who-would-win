import type { Message } from '@anthropic-ai/sdk/resources/messages/messages';
import { getDbPool } from './database';

export type AiOperation = 'animal' | 'tier' | 'battle' | 'quick' | 'melee';

const MICRODOLLARS_PER_DOLLAR = 1_000_000;
const DEFAULT_DAILY_BUDGET_USD = 2;
const DEFAULT_MONTHLY_BUDGET_USD = 25;

// Conservative reservations prevent concurrent calls from overshooting the
// ceiling. Successful calls are settled down to their actual token cost.
const RESERVATION_USD: Record<AiOperation, number> = {
  animal: 0.003,
  tier: 0.004,
  quick: 0.010,
  battle: 0.015,
  melee: 0.020,
};

export class AiUnavailableError extends Error {
  constructor(message: string, public readonly reason: 'disabled' | 'budget' | 'guard-unavailable') {
    super(message);
    this.name = 'AiUnavailableError';
  }
}

function positiveNumber(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function budgetMicrodollars(period: 'day' | 'month'): number {
  const usd = period === 'day'
    ? positiveNumber(process.env.AI_DAILY_BUDGET_USD, DEFAULT_DAILY_BUDGET_USD)
    : positiveNumber(process.env.AI_MONTHLY_BUDGET_USD, DEFAULT_MONTHLY_BUDGET_USD);
  return Math.round(usd * MICRODOLLARS_PER_DOLLAR);
}

function periodKey(period: 'day' | 'month', now = new Date()): string {
  return period === 'day' ? now.toISOString().slice(0, 10) : now.toISOString().slice(0, 7);
}

let initialized = false;
let initialization: Promise<void> | null = null;

export async function initCostControl(): Promise<void> {
  if (initialized) return;
  if (initialization) return initialization;
  initialization = (async () => {
    const pool = getDbPool();
    if (pool) {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS ai_spend_windows (
          period       TEXT NOT NULL,
          period_key   TEXT NOT NULL,
          microdollars BIGINT NOT NULL DEFAULT 0,
          updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          PRIMARY KEY (period, period_key)
        );
      `);
    }
    initialized = true;
  })().finally(() => { initialization = null; });
  return initialization;
}

const memorySpend = new Map<string, number>();

interface Reservation {
  amount: number;
  dayKey: string;
  monthKey: string;
  database: boolean;
}

async function reserve(operation: AiOperation): Promise<Reservation> {
  if (process.env.AI_ENABLED === 'false') {
    throw new AiUnavailableError('AI generation is temporarily disabled.', 'disabled');
  }

  const amount = Math.round(RESERVATION_USD[operation] * MICRODOLLARS_PER_DOLLAR);
  const dayKey = periodKey('day');
  const monthKey = periodKey('month');
  const pool = getDbPool();

  if (!pool) {
    // An in-memory counter resets on every deploy and is not shared by multiple
    // Railway replicas.  Never let production silently fall back to it: without
    // Postgres there is no trustworthy application-level spending ceiling.
    if (process.env.NODE_ENV === 'production'
        && process.env.COST_CONTROL_ALLOW_MEMORY !== 'true') {
      throw new AiUnavailableError('The AI spending guard is unavailable.', 'guard-unavailable');
    }
    const dayMapKey = `day:${dayKey}`;
    const monthMapKey = `month:${monthKey}`;
    const nextDay = (memorySpend.get(dayMapKey) ?? 0) + amount;
    const nextMonth = (memorySpend.get(monthMapKey) ?? 0) + amount;
    if (nextDay > budgetMicrodollars('day') || nextMonth > budgetMicrodollars('month')) {
      throw new AiUnavailableError('The application AI budget has been reached.', 'budget');
    }
    memorySpend.set(dayMapKey, nextDay);
    memorySpend.set(monthMapKey, nextMonth);
    return { amount, dayKey, monthKey, database: false };
  }

  try {
    await initCostControl();
    const db = await pool.connect();
    try {
      await db.query('BEGIN');
      await db.query("SELECT pg_advisory_xact_lock(hashtext('animal-vs-animal-ai-budget'))");
      const current = await db.query<{ period: string; microdollars: string }>(
        `SELECT period, microdollars FROM ai_spend_windows
          WHERE (period = 'day' AND period_key = $1)
             OR (period = 'month' AND period_key = $2)`,
        [dayKey, monthKey],
      );
      const dayUsed = Number(current.rows.find(r => r.period === 'day')?.microdollars ?? 0);
      const monthUsed = Number(current.rows.find(r => r.period === 'month')?.microdollars ?? 0);
      if (dayUsed + amount > budgetMicrodollars('day')
          || monthUsed + amount > budgetMicrodollars('month')) {
        await db.query('ROLLBACK');
        throw new AiUnavailableError('The application AI budget has been reached.', 'budget');
      }
      await db.query(
        `INSERT INTO ai_spend_windows (period, period_key, microdollars)
         VALUES ('day', $1, $3), ('month', $2, $3)
         ON CONFLICT (period, period_key) DO UPDATE
           SET microdollars = ai_spend_windows.microdollars + EXCLUDED.microdollars,
               updated_at = NOW()`,
        [dayKey, monthKey, amount],
      );
      await db.query('COMMIT');
      return { amount, dayKey, monthKey, database: true };
    } catch (error) {
      try { await db.query('ROLLBACK'); } catch { /* no-op */ }
      throw error;
    } finally {
      db.release();
    }
  } catch (error) {
    if (error instanceof AiUnavailableError) throw error;
    console.error('[cost-control] reservation failed:', (error as Error).message);
    if (process.env.COST_CONTROL_FAIL_CLOSED !== 'false') {
      throw new AiUnavailableError('The AI spending guard is unavailable.', 'guard-unavailable');
    }
    return { amount, dayKey, monthKey, database: false };
  }
}

function actualMicrodollars(message: Message): number {
  const inputPerMillion = positiveNumber(process.env.ANTHROPIC_INPUT_USD_PER_MTOK, 1);
  const outputPerMillion = positiveNumber(process.env.ANTHROPIC_OUTPUT_USD_PER_MTOK, 5);
  const usd = (message.usage.input_tokens * inputPerMillion
    + message.usage.output_tokens * outputPerMillion) / 1_000_000;
  return Math.max(0, Math.round(usd * MICRODOLLARS_PER_DOLLAR));
}

async function settle(reservation: Reservation, actual: number): Promise<void> {
  const adjustment = actual - reservation.amount;
  if (!reservation.database) {
    for (const key of [`day:${reservation.dayKey}`, `month:${reservation.monthKey}`]) {
      memorySpend.set(key, Math.max(0, (memorySpend.get(key) ?? 0) + adjustment));
    }
    return;
  }
  const pool = getDbPool();
  if (!pool) return;
  try {
    await pool.query(
      `UPDATE ai_spend_windows
          SET microdollars = GREATEST(0, microdollars + $3), updated_at = NOW()
        WHERE (period = 'day' AND period_key = $1)
           OR (period = 'month' AND period_key = $2)`,
      [reservation.dayKey, reservation.monthKey, adjustment],
    );
  } catch (error) {
    // Settlement failures intentionally leave the conservative reservation.
    console.error('[cost-control] settlement failed:', (error as Error).message);
  }
}

export async function runAiOperation(
  operation: AiOperation,
  call: () => Promise<Message>,
): Promise<Message> {
  const reservation = await reserve(operation);
  try {
    const message = await call();
    const actual = actualMicrodollars(message);
    await settle(reservation, actual);
    console.log(JSON.stringify({
      event: 'ai_usage', operation,
      inputTokens: message.usage.input_tokens,
      outputTokens: message.usage.output_tokens,
      microdollars: actual,
    }));
    return message;
  } catch (error) {
    await settle(reservation, 0);
    throw error;
  }
}

export function isAiUnavailable(error: unknown): error is AiUnavailableError {
  return error instanceof AiUnavailableError;
}
