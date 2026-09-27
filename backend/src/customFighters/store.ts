import { randomUUID, createHmac } from 'crypto';
import { Pool, PoolClient } from 'pg';
import { getDbPool } from '../services/database';
import { allowedEnvironment, budgetMicrodollars, IMAGE_MODEL, JOB_RESERVATION_MICRODOLLARS, LEASE_MS, MAX_LIBRARY_SIZE, MAX_PNG_BYTES, monthlyAllowance, REVIEW_MODEL } from './config';
import { Allowance, ClaimedJob, FailureDiagnostic, Fighter, FighterError, FighterJob, FighterManifest, JobState, ProviderUsage, SubscriptionProof } from './types';

interface JobRow {
  id: string; owner_id: string; name: string | null; name_digest: string; state: JobState; asset_id: string | null;
  environment: 'Sandbox' | 'Production'; period_key: string; error_code: string | null;
  created_at: Date; updated_at: Date; worker_token: string | null; expires_at: Date;
  dispatched_at: Date | null; quota_reserved: boolean; budget_reserved: string;
}
interface AssetRow { id: string; name: string; created_at: Date; manifest: FighterManifest; runtime_png?: Buffer }
const iso = (value: Date | string): string => new Date(value).toISOString();
const jobDTO = (row: JobRow): FighterJob => ({ id: row.id, state: row.state, name: row.name ?? '',
  ...(row.asset_id ? { assetId: row.asset_id } : {}), ...(row.error_code ? { errorCode: row.error_code } : {}),
  createdAt: iso(row.created_at), updatedAt: iso(row.updated_at) });
const fighterDTO = (row: AssetRow): Fighter => ({ id: row.id, name: row.name, createdAt: iso(row.created_at),
  appearance: { schemaVersion: 1, assetID: row.id, version: 1, sha256: row.manifest.sha256 },
  manifest: row.manifest, sheetPath: `/api/custom-fighters/${row.id}/sheet` });

/** Private durable storage adapter. Binaries are bounded bytea during the small beta; swap behind this interface for object storage. */
export interface FighterStore {
  initialize(): Promise<void>;
  existing(owner: string, key: string, name: string): Promise<{ job: FighterJob; allowance: Allowance } | null>;
  enqueue(owner: string, key: string, name: string, proof: SubscriptionProof, expectedEpoch: number): Promise<{ job: FighterJob; allowance: Allowance }>;
  allowance(owner: string, proof: SubscriptionProof): Promise<Allowance>;
  list(owner: string): Promise<{ fighters: Fighter[]; jobs: FighterJob[]; removedAssetIDs: string[]; libraryEpoch: number }>;
  job(owner: string, id: string): Promise<{ job: FighterJob; fighter?: Fighter } | null>;
  fighter(owner: string, id: string): Promise<Fighter | null>;
  sheet(owner: string, id: string): Promise<Buffer | null>;
  remove(owner: string, id: string): Promise<void>;
  report(owner: string, id: string, reason: string): Promise<void>;
  eraseOwner(owner: string): Promise<void>;
  recover(): Promise<void>;
  claim(): Promise<ClaimedJob | null>;
  markDispatched(job: ClaimedJob): Promise<boolean>;
  markValidating(job: ClaimedJob): Promise<boolean>;
  usage(job: ClaimedJob, usage: ProviderUsage): Promise<void>;
  publish(job: ClaimedJob, original: Buffer, runtime: Buffer, manifest: FighterManifest): Promise<boolean>;
  fail(job: ClaimedJob, state: 'rejected' | 'failed' | 'reconciling', code: string, diagnostic?: FailureDiagnostic): Promise<void>;
}

export class PostgresFighterStore implements FighterStore {
  private initialized?: Promise<void>;
  constructor(private readonly pool: Pool) {}
  initialize(): Promise<void> {
    if (!this.initialized) this.initialized = this.pool.query(`
      CREATE TABLE IF NOT EXISTS custom_fighter_quotas (
        owner_id TEXT NOT NULL, environment TEXT NOT NULL, period_key TEXT NOT NULL,
        used INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0), reserved INTEGER NOT NULL DEFAULT 0 CHECK (reserved >= 0),
        PRIMARY KEY(owner_id, environment, period_key)
      );
      CREATE TABLE IF NOT EXISTS custom_fighter_budgets (
        scope TEXT PRIMARY KEY, reserved_microdollars BIGINT NOT NULL DEFAULT 0 CHECK (reserved_microdollars >= 0),
        actual_microdollars BIGINT NOT NULL DEFAULT 0 CHECK (actual_microdollars >= 0)
      );
      CREATE TABLE IF NOT EXISTS custom_fighter_jobs (
        id UUID PRIMARY KEY, owner_id TEXT NOT NULL, idempotency_key UUID NOT NULL,
        name TEXT, name_digest TEXT NOT NULL, environment TEXT NOT NULL, period_key TEXT NOT NULL,
        state TEXT NOT NULL, consent_version TEXT NOT NULL DEFAULT 'custom-art-v1', asset_id UUID, error_code TEXT, worker_token UUID, lease_until TIMESTAMPTZ,
        expires_at TIMESTAMPTZ NOT NULL, dispatched_at TIMESTAMPTZ, quota_reserved BOOLEAN NOT NULL DEFAULT TRUE,
        budget_reserved BIGINT NOT NULL, usage JSONB NOT NULL DEFAULT '[]'::jsonb,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE(owner_id, idempotency_key)
      );
      CREATE INDEX IF NOT EXISTS custom_fighter_jobs_queue ON custom_fighter_jobs(state, created_at);
      CREATE TABLE IF NOT EXISTS custom_fighter_assets (
        id UUID PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT, manifest JSONB, provenance JSONB,
        original_png BYTEA CHECK (octet_length(original_png) <= 8388608),
        runtime_png BYTEA CHECK (octet_length(runtime_png) <= 8388608),
        deleted BOOLEAN NOT NULL DEFAULT FALSE, quarantined BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), deleted_at TIMESTAMPTZ
      );
      CREATE INDEX IF NOT EXISTS custom_fighter_assets_owner ON custom_fighter_assets(owner_id, created_at);
      CREATE TABLE IF NOT EXISTS custom_fighter_reports (
        asset_id UUID NOT NULL, owner_id TEXT NOT NULL, reason TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), PRIMARY KEY(asset_id, owner_id, reason)
      );
      ALTER TABLE custom_fighter_jobs ADD COLUMN IF NOT EXISTS consent_version TEXT NOT NULL DEFAULT 'custom-art-v1';
      ALTER TABLE custom_fighter_jobs ADD COLUMN IF NOT EXISTS failure_stage TEXT;
      ALTER TABLE custom_fighter_jobs ADD COLUMN IF NOT EXISTS failure_reason TEXT;
      ALTER TABLE custom_fighter_assets ADD COLUMN IF NOT EXISTS provenance JSONB;
    `).then(() => undefined).catch(error => { this.initialized = undefined; throw error; });
    return this.initialized;
  }
  private async transaction<T>(body: (db: PoolClient) => Promise<T>, activeOwner?: string, expectedEpoch?: number): Promise<T> {
    await this.initialize(); const db = await this.pool.connect();
    try {
      await db.query('BEGIN');
      if (activeOwner) {
        const owner = await db.query('SELECT id,library_epoch FROM custom_fighter_accounts WHERE id=$1 AND deleted_at IS NULL FOR UPDATE', [activeOwner]);
        if (!owner.rows.length) throw new FighterError('account_unavailable', 401, 'Sign in again to use your fighter library.');
        if (expectedEpoch !== undefined && Number(owner.rows[0].library_epoch) !== expectedEpoch) {
          throw new FighterError('account_unavailable', 401, 'Your fighter library changed. Sign in again before creating artwork.');
        }
      }
      // The bounded beta intentionally serializes all mutations, including deletion/publication and owner quotas.
      await db.query("SELECT pg_advisory_xact_lock(hashtext('custom-fighter-ledger-v1'))");
      const value = await body(db); await db.query('COMMIT'); return value;
    } catch (error) { await db.query('ROLLBACK').catch(() => undefined); throw error; }
    finally { db.release(); }
  }
  private digest(owner: string, name: string): string {
    // Per-owner keyed digest prevents a common-name index across private libraries. No name is in an ID or URL.
    return createHmac('sha256', owner).update(name).digest('hex');
  }
  private period(proof: SubscriptionProof): string {
    // Sandbox renewals never advance real-cost allowance; both terms allocate by UTC month.
    return new Date().toISOString().slice(0, 7);
  }
  private async allowanceDB(db: Pick<PoolClient, 'query'>, owner: string, environment: string, period: string): Promise<Allowance> {
    const result = await db.query('SELECT used, reserved FROM custom_fighter_quotas WHERE owner_id=$1 AND environment=$2 AND period_key=$3', [owner, environment, period]);
    const used = Number(result.rows[0]?.used ?? 0), reserved = Number(result.rows[0]?.reserved ?? 0), limit = monthlyAllowance();
    return { limit, used, reserved, remaining: Math.max(0, limit - used - reserved), periodKey: period };
  }
  async allowance(owner: string, proof: SubscriptionProof): Promise<Allowance> {
    await this.initialize(); return this.allowanceDB(this.pool, owner, proof.environment, this.period(proof));
  }
  async existing(owner: string, key: string, name: string): Promise<{ job: FighterJob; allowance: Allowance } | null> {
    await this.initialize();
    const result = await this.pool.query<JobRow>('SELECT * FROM custom_fighter_jobs WHERE owner_id=$1 AND idempotency_key=$2', [owner, key]);
    const row = result.rows[0]; if (!row) return null;
    if (row.name_digest !== this.digest(owner, name)) throw new FighterError('idempotency_conflict', 409, 'This creation request was already used for another name.');
    return { job: jobDTO(row), allowance: await this.allowanceDB(this.pool, owner, row.environment, row.period_key) };
  }
  async enqueue(owner: string, key: string, name: string, proof: SubscriptionProof, expectedEpoch: number): Promise<{ job: FighterJob; allowance: Allowance }> {
    if (!Number.isSafeInteger(expectedEpoch) || expectedEpoch < 1) throw new FighterError('account_unavailable', 401, 'Sign in again to create artwork.');
    if (!allowedEnvironment(proof.environment)) throw new FighterError('feature_disabled', 503, 'Custom artwork is currently available only in the private beta.');
    if (!Number.isFinite(Date.parse(proof.expiresAt)) || Date.parse(proof.expiresAt) <= Date.now()) throw new FighterError('subscription_required', 403, 'An active Premium subscription is required to create artwork.');
    const period = this.period(proof);
    return this.transaction(async db => {
      const prior = await db.query<JobRow>('SELECT * FROM custom_fighter_jobs WHERE owner_id=$1 AND idempotency_key=$2', [owner, key]);
      if (prior.rows[0]) {
        if (prior.rows[0].name_digest !== this.digest(owner, name)) throw new FighterError('idempotency_conflict', 409, 'This creation request was already used for another name.');
        return { job: jobDTO(prior.rows[0]), allowance: await this.allowanceDB(db, owner, prior.rows[0].environment, prior.rows[0].period_key) };
      }
      const active = await db.query("SELECT id FROM custom_fighter_jobs WHERE owner_id=$1 AND state IN ('queued','generating','validating') LIMIT 1", [owner]);
      if (active.rows.length) throw new FighterError('job_active', 409, 'Your current fighter is still being created.');
      const attempts = await db.query("SELECT COUNT(*)::int AS count FROM custom_fighter_jobs WHERE owner_id=$1 AND created_at > NOW() - INTERVAL '1 day'", [owner]);
      if (Number(attempts.rows[0].count) >= 10) throw new FighterError('rate_limited', 429, 'Please try creating artwork again tomorrow.');
      const assets = await db.query('SELECT COUNT(*)::int AS count FROM custom_fighter_assets WHERE owner_id=$1 AND deleted=FALSE', [owner]);
      if (Number(assets.rows[0].count) >= MAX_LIBRARY_SIZE) throw new FighterError('library_full', 409, 'Your fighter library is full. Remove a fighter before creating another.');
      const allowance = await this.allowanceDB(db, owner, proof.environment, period);
      if (allowance.remaining <= 0) throw new FighterError('quota_exhausted', 429, 'You have used this month’s artwork allowance. Saved fighters are still available.');
      await db.query("INSERT INTO custom_fighter_budgets(scope) VALUES('beta-lifetime-v1') ON CONFLICT DO NOTHING");
      const budget = await db.query("SELECT reserved_microdollars,actual_microdollars FROM custom_fighter_budgets WHERE scope='beta-lifetime-v1'");
      if (Math.max(Number(budget.rows[0].reserved_microdollars), Number(budget.rows[0].actual_microdollars)) + JOB_RESERVATION_MICRODOLLARS > budgetMicrodollars()) {
        throw new FighterError('budget_exhausted', 503, 'The private beta artwork allowance is temporarily used up.');
      }
      await db.query("UPDATE custom_fighter_budgets SET reserved_microdollars=reserved_microdollars+$1 WHERE scope='beta-lifetime-v1'", [JOB_RESERVATION_MICRODOLLARS]);
      await db.query(`INSERT INTO custom_fighter_quotas(owner_id,environment,period_key,reserved) VALUES($1,$2,$3,1)
        ON CONFLICT(owner_id,environment,period_key) DO UPDATE SET reserved=custom_fighter_quotas.reserved+1`, [owner, proof.environment, period]);
      const created = await db.query<JobRow>(`INSERT INTO custom_fighter_jobs(id,owner_id,idempotency_key,name,name_digest,environment,period_key,state,expires_at,budget_reserved)
        VALUES($1,$2,$3,$4,$5,$6,$7,'queued',$8,$9) RETURNING *`,
      [randomUUID(), owner, key, name, this.digest(owner, name), proof.environment, period, proof.expiresAt, JOB_RESERVATION_MICRODOLLARS]);
      return { job: jobDTO(created.rows[0]), allowance: await this.allowanceDB(db, owner, proof.environment, period) };
    }, owner, expectedEpoch);
  }
  async list(owner: string): Promise<{ fighters: Fighter[]; jobs: FighterJob[]; removedAssetIDs: string[]; libraryEpoch: number }> {
    return this.transaction(async db => {
      // One consistent response cannot advertise an asset and its deletion simultaneously.
      const assets = await db.query<AssetRow>('SELECT id,name,created_at,manifest FROM custom_fighter_assets WHERE owner_id=$1 AND deleted=FALSE AND quarantined=FALSE ORDER BY created_at DESC LIMIT 100', [owner]);
      const jobs = await db.query<JobRow>("SELECT * FROM custom_fighter_jobs WHERE owner_id=$1 AND created_at > NOW() - INTERVAL '90 days' ORDER BY created_at DESC LIMIT 30", [owner]);
      const removed = await db.query<{id:string}>('SELECT id FROM custom_fighter_assets WHERE owner_id=$1 AND (deleted=TRUE OR quarantined=TRUE)', [owner]);
      const account = await db.query('SELECT library_epoch FROM custom_fighter_accounts WHERE id=$1', [owner]);
      const libraryEpoch = Number(account.rows[0]?.library_epoch);
      if (!Number.isSafeInteger(libraryEpoch) || libraryEpoch < 1) throw new FighterError('account_unavailable', 503, 'Your fighter library is temporarily unavailable.');
      return { fighters: assets.rows.map(fighterDTO), jobs: jobs.rows.map(jobDTO), removedAssetIDs: removed.rows.map(row => row.id), libraryEpoch };
    }, owner);
  }
  async job(owner: string, id: string): Promise<{ job: FighterJob; fighter?: Fighter } | null> {
    await this.initialize();
    const result = await this.pool.query<JobRow>('SELECT * FROM custom_fighter_jobs WHERE owner_id=$1 AND id=$2', [owner, id]);
    const row = result.rows[0]; if (!row) return null;
    const fighter = row.asset_id ? await this.fighter(owner, row.asset_id) : null;
    return { job: jobDTO(row), ...(fighter ? { fighter } : {}) };
  }
  async fighter(owner: string, id: string): Promise<Fighter | null> {
    await this.initialize();
    const result = await this.pool.query<AssetRow>('SELECT id,name,created_at,manifest FROM custom_fighter_assets WHERE owner_id=$1 AND id=$2 AND deleted=FALSE AND quarantined=FALSE', [owner, id]);
    return result.rows[0] ? fighterDTO(result.rows[0]) : null;
  }
  async sheet(owner: string, id: string): Promise<Buffer | null> {
    await this.initialize();
    const result = await this.pool.query<{runtime_png: Buffer}>('SELECT runtime_png FROM custom_fighter_assets WHERE owner_id=$1 AND id=$2 AND deleted=FALSE AND quarantined=FALSE', [owner, id]);
    return result.rows[0]?.runtime_png ?? null;
  }
  async remove(owner: string, id: string): Promise<void> {
    await this.transaction(async db => {
      const result = await db.query(`UPDATE custom_fighter_assets SET deleted=TRUE,deleted_at=NOW(),name=NULL,manifest=NULL,provenance=NULL,original_png=NULL,runtime_png=NULL
        WHERE owner_id=$1 AND id=$2 RETURNING id`, [owner, id]);
      if (!result.rows.length) throw new FighterError('not_found', 404, 'Fighter not found.');
      await db.query("UPDATE custom_fighter_jobs SET name=NULL,state='cancelled',error_code='deleted',asset_id=NULL,updated_at=NOW() WHERE owner_id=$1 AND asset_id=$2", [owner, id]);
      await db.query('DELETE FROM custom_fighter_reports WHERE owner_id=$1 AND asset_id=$2', [owner, id]);
    });
  }
  async report(owner: string, id: string, reason: string): Promise<void> {
    await this.transaction(async db => {
      const found = await db.query('SELECT id FROM custom_fighter_assets WHERE owner_id=$1 AND id=$2 AND deleted=FALSE', [owner, id]);
      if (!found.rows.length) throw new FighterError('not_found', 404, 'Fighter not found.');
      await db.query('INSERT INTO custom_fighter_reports(asset_id,owner_id,reason) VALUES($1,$2,$3) ON CONFLICT DO NOTHING', [id, owner, reason]);
      if (reason === 'unsafe') await db.query('UPDATE custom_fighter_assets SET quarantined=TRUE WHERE owner_id=$1 AND id=$2', [owner, id]);
    });
  }
  private async release(db: PoolClient, row: JobRow): Promise<void> {
    if (row.quota_reserved) await db.query(`UPDATE custom_fighter_quotas SET reserved=GREATEST(0,reserved-1)
      WHERE owner_id=$1 AND environment=$2 AND period_key=$3`, [row.owner_id, row.environment, row.period_key]);
    // A dispatch record is durable BEFORE the provider call. Never refund uncertain provider charges.
    if (!row.dispatched_at && Number(row.budget_reserved) > 0) await db.query("UPDATE custom_fighter_budgets SET reserved_microdollars=GREATEST(0,reserved_microdollars-$1) WHERE scope='beta-lifetime-v1'", [row.budget_reserved]);
  }
  async eraseOwner(owner: string): Promise<void> {
    await this.transaction(async db => {
      const jobs = await db.query<JobRow>("SELECT * FROM custom_fighter_jobs WHERE owner_id=$1 AND state IN ('queued','generating','validating')", [owner]);
      for (const row of jobs.rows) await this.release(db, row);
      await db.query("UPDATE custom_fighter_jobs SET name=NULL,name_digest='',state='cancelled',error_code='deleted',asset_id=NULL,worker_token=NULL,lease_until=NULL,quota_reserved=FALSE,budget_reserved=0,usage='[]'::jsonb,updated_at=NOW() WHERE owner_id=$1", [owner]);
      // The auth layer increments library_epoch before this purge; other devices discard the previous local epoch.
      await db.query('DELETE FROM custom_fighter_assets WHERE owner_id=$1', [owner]);
      await db.query('DELETE FROM custom_fighter_reports WHERE owner_id=$1', [owner]);
    });
  }
  async recover(): Promise<void> {
    await this.transaction(async db => {
      const rows = await db.query<JobRow>("SELECT * FROM custom_fighter_jobs WHERE state IN ('generating','validating') AND lease_until < NOW()");
      for (const row of rows.rows) {
        // Pre-dispatch jobs can safely requeue; a dispatched job is never automatically replayed after restart.
        if (!row.dispatched_at) await db.query("UPDATE custom_fighter_jobs SET state='queued',worker_token=NULL,lease_until=NULL,updated_at=NOW() WHERE id=$1", [row.id]);
        else {
          await this.release(db, row);
          await db.query("UPDATE custom_fighter_jobs SET state='reconciling',error_code='provider_uncertain',quota_reserved=FALSE,worker_token=NULL,lease_until=NULL,updated_at=NOW() WHERE id=$1", [row.id]);
        }
      }
      await db.query("UPDATE custom_fighter_jobs SET name=NULL,name_digest='' WHERE state IN ('failed','rejected','cancelled','reconciling') AND updated_at < NOW() - INTERVAL '7 days'");
      await db.query("UPDATE custom_fighter_jobs SET name=NULL,name_digest='',usage='[]'::jsonb,worker_token=NULL,lease_until=NULL WHERE state IN ('ready','failed','rejected','cancelled','reconciling') AND updated_at < NOW() - INTERVAL '90 days'");
      // Keep idempotency tombstones and current quota to prevent erase/retry from generating paid duplicates.
      await db.query("DELETE FROM custom_fighter_quotas WHERE period_key < to_char(NOW() - INTERVAL '90 days','YYYY-MM')");
      await db.query("DELETE FROM custom_fighter_reports WHERE created_at < NOW() - INTERVAL '90 days'");
    });
  }
  async claim(): Promise<ClaimedJob | null> {
    return this.transaction(async db => {
      const busy = await db.query("SELECT id FROM custom_fighter_jobs WHERE state IN ('generating','validating') LIMIT 1");
      if (busy.rows.length) return null; // one provider workflow across every replica during the beta
      const next = await db.query<JobRow>("SELECT * FROM custom_fighter_jobs WHERE state='queued' ORDER BY created_at ASC LIMIT 1");
      const row = next.rows[0]; if (!row) return null;
      if (new Date(row.expires_at).getTime() <= Date.now() || !allowedEnvironment(row.environment)) {
        await this.release(db, row);
        await db.query("UPDATE custom_fighter_jobs SET state='failed',error_code='subscription_expired',quota_reserved=FALSE,budget_reserved=0,updated_at=NOW() WHERE id=$1", [row.id]);
        return null;
      }
      const token = randomUUID();
      await db.query("UPDATE custom_fighter_jobs SET state='generating',worker_token=$2,lease_until=NOW()+($3 * INTERVAL '1 millisecond'),updated_at=NOW() WHERE id=$1", [row.id, token, LEASE_MS]);
      return { id: row.id, ownerId: row.owner_id, name: row.name ?? '', workerToken: token, expiresAt: iso(row.expires_at), environment: row.environment, periodKey: row.period_key };
    });
  }
  async markDispatched(job: ClaimedJob): Promise<boolean> {
    return this.transaction(async db => {
      const active = await db.query(`SELECT original_id FROM custom_fighter_subscriptions
        WHERE owner_id=$1 AND environment=$2 AND revoked=FALSE AND expires_at>NOW() LIMIT 1`, [job.ownerId, job.environment]);
      if (!active.rows.length) return false;
      const result = await db.query("UPDATE custom_fighter_jobs SET dispatched_at=NOW(),updated_at=NOW() WHERE id=$1 AND worker_token=$2 AND state='generating' AND dispatched_at IS NULL RETURNING id", [job.id, job.workerToken]);
      return result.rows.length === 1;
    }, job.ownerId);
  }
  async markValidating(job: ClaimedJob): Promise<boolean> {
    const result = await this.pool.query("UPDATE custom_fighter_jobs SET state='validating',updated_at=NOW() WHERE id=$1 AND worker_token=$2 AND state='generating' RETURNING id", [job.id, job.workerToken]);
    return result.rows.length === 1;
  }
  async usage(job: ClaimedJob, usage: ProviderUsage): Promise<void> {
    await this.transaction(async db => {
      // Usage may arrive after deletion; retain only aggregate cost then, never recreate the owner's job/media.
      const row = await db.query<JobRow>('SELECT * FROM custom_fighter_jobs WHERE id=$1 AND worker_token=$2', [job.id, job.workerToken]);
      const actual = Math.max(0, Math.min(100_000_000, Math.floor(usage.estimatedMicrodollars ?? 0)));
      await db.query("UPDATE custom_fighter_budgets SET actual_microdollars=actual_microdollars+$1 WHERE scope='beta-lifetime-v1'", [actual]);
      if (row.rows.length) await db.query("UPDATE custom_fighter_jobs SET usage=usage || $2::jsonb WHERE id=$1", [job.id, JSON.stringify([usage])]);
    });
  }
  async publish(job: ClaimedJob, original: Buffer, runtime: Buffer, manifest: FighterManifest): Promise<boolean> {
    if (original.length > MAX_PNG_BYTES || runtime.length > MAX_PNG_BYTES) throw new Error('Asset exceeds storage limit');
    return this.transaction(async db => {
      const result = await db.query<JobRow>("SELECT * FROM custom_fighter_jobs WHERE id=$1 AND worker_token=$2 AND state='validating'", [job.id, job.workerToken]);
      const row = result.rows[0]; if (!row || !row.quota_reserved) return false;
      await db.query('INSERT INTO custom_fighter_assets(id,owner_id,name,manifest,original_png,runtime_png,provenance) VALUES($1,$2,$3,$4::jsonb,$5,$6,$7::jsonb)',
        [manifest.assetID, row.owner_id, row.name, JSON.stringify(manifest), original, runtime,
          JSON.stringify({ jobID: job.id, promptVersion: 'custom-art-v2', normalizerVersion: 'complete-poses-v2', imageModel: IMAGE_MODEL, reviewModel: REVIEW_MODEL,
            quality: 'medium', generationModeration: 'low', acceptedModeration: true, acceptedSemanticReview: true, consentVersion: 'custom-art-v1' })]);
      await db.query('UPDATE custom_fighter_quotas SET reserved=GREATEST(0,reserved-1),used=used+1 WHERE owner_id=$1 AND environment=$2 AND period_key=$3', [row.owner_id, row.environment, row.period_key]);
      await db.query("UPDATE custom_fighter_jobs SET state='ready',asset_id=$2,quota_reserved=FALSE,worker_token=NULL,lease_until=NULL,updated_at=NOW() WHERE id=$1", [job.id, manifest.assetID]);
      return true;
    }, job.ownerId);
  }
  async fail(job: ClaimedJob, state: 'rejected' | 'failed' | 'reconciling', code: string, diagnostic?: FailureDiagnostic): Promise<void> {
    await this.transaction(async db => {
      const result = await db.query<JobRow>("SELECT * FROM custom_fighter_jobs WHERE id=$1 AND worker_token=$2 AND state IN ('generating','validating')", [job.id, job.workerToken]);
      const row = result.rows[0]; if (!row) return;
      await this.release(db, row);
      // Only bounded machine labels are retained, never provider prose, images, credentials or user input.
      const reason = diagnostic?.reason && /^[a-zA-Z][a-zA-Z0-9_]{0,63}$/.test(diagnostic.reason) ? diagnostic.reason : null;
      await db.query('UPDATE custom_fighter_jobs SET state=$2,error_code=$3,quota_reserved=FALSE,budget_reserved=$4,failure_stage=$5,failure_reason=$6,worker_token=NULL,lease_until=NULL,updated_at=NOW() WHERE id=$1',
        [job.id, state, code, row.dispatched_at ? row.budget_reserved : 0, diagnostic?.stage ?? null, reason]);
    });
  }
}

let productionStore: PostgresFighterStore | undefined;
export function getFighterStore(): PostgresFighterStore {
  if (productionStore) return productionStore;
  const pool = getDbPool();
  if (!pool) throw new FighterError('provider_unavailable', 503, 'The private fighter library is temporarily unavailable.');
  return productionStore = new PostgresFighterStore(pool);
}
export async function deleteCustomFighterOwnerData(ownerId: string): Promise<void> { await getFighterStore().eraseOwner(ownerId); }
