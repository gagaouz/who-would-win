import { Router, Request, RequestHandler } from 'express';
import { join } from 'node:path';
import { sanitizeName } from '../middleware/sanitize';
import { requireCustomFighterOwner, requireCustomFighterSubscription } from '../services/customFighterAuth';
import { configured, enabled, monthlyAllowance, requireGenerationAvailable } from './config';
import { FighterStore, getFighterStore } from './store';
import { FighterError, SubscriptionProof } from './types';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function validID(value: unknown): string {
  if (typeof value !== 'string' || !UUID.test(value)) throw new FighterError('invalid_request', 400, 'Invalid fighter request.');
  return value.toLowerCase();
}
export function validatedName(raw: unknown): string {
  if (typeof raw !== 'string') throw new FighterError('invalid_request', 400, 'Enter a fighter name.');
  const normalized = raw.normalize('NFKC').trim().replace(/\s+/g, ' ');
  if (!normalized || [...normalized].length > 24 || /[\p{Cc}\p{Cf}]/u.test(normalized)) throw new FighterError('name_not_allowed', 400, 'Choose a short, family-friendly name (24 characters or fewer).');
  const result = sanitizeName(normalized);
  if (!result.ok || !result.value) throw new FighterError('name_not_allowed', 400, 'Choose a different, family-friendly fighter.');
  return result.value;
}
interface ServiceConfiguration { enabled: boolean; configured: boolean; monthlyAllowance: number; requiresSubscription: boolean }
interface Dependencies {
  owner?: RequestHandler; subscription?: (owner: string, signed: string) => Promise<SubscriptionProof>;
  store?: () => FighterStore; available?: () => void; status?: () => ServiceConfiguration;
}
export function createCustomFighterRouter(dependencies: Dependencies = {}): Router {
  const router = Router();
  const store = dependencies.store ?? getFighterStore;
  const subscription = dependencies.subscription ?? requireCustomFighterSubscription;
  const available = dependencies.available ?? requireGenerationAvailable;
  const configuration = dependencies.status ?? (() => ({ enabled: enabled(), configured: configured(), monthlyAllowance: monthlyAllowance(), requiresSubscription: true }));
  const status = async () => {
    const flags = configuration();
    let unavailabilityCode: 'feature_disabled' | 'provider_unavailable' | 'budget_exhausted' | undefined;
    if (!flags.enabled) unavailabilityCode = 'feature_disabled';
    else if (!flags.configured) unavailabilityCode = 'provider_unavailable';
    else {
      try { if (!await store().hasCreationBudget()) unavailabilityCode = 'budget_exhausted'; }
      catch { unavailabilityCode = 'provider_unavailable'; }
    }
    // Build114 already gates Create on enabled. Preserve real account credits; this flag
    // describes whether the service can admit work, not whether the customer spent credits.
    return { ...flags, enabled: unavailabilityCode === undefined, featureEnabled: flags.enabled,
      creationAvailable: unavailabilityCode === undefined,
      ...(unavailabilityCode ? { unavailabilityCode,
        availabilityMessage: 'New artwork is temporarily paused. Your artwork credits are unchanged, and saved fighters still work.' } : {}) };
  };
  const owner = (req: Request): string => {
    const id = (req as Request & { customFighterOwner?: { id: string } }).customFighterOwner?.id;
    if (!id) throw new FighterError('unauthorized', 401, 'Sign in to use your fighter library.');
    return id;
  };
  const wrap = (handler: RequestHandler): RequestHandler => (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch((error: unknown) => {
      const value = error as { status?: number; code?: string; message?: string };
      const recognized = typeof value.status === 'number' && value.status >= 400 && value.status <= 599 && typeof value.code === 'string';
      res.status(recognized ? value.status! : 503).json({
        code: recognized ? value.code : 'provider_unavailable',
        error: recognized ? value.message : 'The fighter library is temporarily unavailable.',
      });
    });
  };
  router.get('/status', wrap(async (_req, res) => { res.setHeader('Cache-Control', 'no-store'); res.json(await status()); }));
  router.get('/privacy', (_req, res) => {
    res.setHeader('Cache-Control', 'no-cache');
    res.sendFile(join(__dirname, 'privacy.html'));
  });
  router.use(dependencies.owner ?? requireCustomFighterOwner);
  router.post('/status', wrap(async (req, res) => {
    res.setHeader('Cache-Control', 'private, no-store');
    const signed = req.body?.signedTransaction;
    if (signed == null || signed === '') {
      res.json({ ...await status(), activeSubscription: false, allowance: { limit: monthlyAllowance(), used: 0, reserved: 0, remaining: 0, periodKey: new Date().toISOString().slice(0, 7) } }); return;
    }
    if (typeof signed !== 'string' || signed.length > 20_000) throw new FighterError('invalid_request', 400, 'Invalid subscription proof.');
    const proof = await subscription(owner(req), signed);
    res.json({ ...await status(), activeSubscription: true, allowance: await store().allowance(owner(req), proof) });
  }));
  router.post('/', wrap(async (req, res) => {
    const name = validatedName(req.body?.name), key = validID(req.body?.idempotencyKey), id = owner(req);
    const prior = await store().existing(id, key, name);
    if (prior) { res.status(202).json(prior); return; }
    available();
    if (req.body?.consentVersion !== 'custom-art-v1') throw new FighterError('consent_required', 400, 'A grown-up must review the artwork service information before creation.');
    const signed = req.body?.signedTransaction;
    if (typeof signed !== 'string' || !signed || signed.length > 20_000) throw new FighterError('subscription_required', 403, 'An active Premium subscription is required to create artwork.');
    const proof = await subscription(id, signed);
    const epoch = (req as Request & { customFighterOwner?: { id: string; libraryEpoch?: number } }).customFighterOwner?.libraryEpoch;
    if (!Number.isSafeInteger(epoch) || !epoch || epoch < 1) throw new FighterError('account_unavailable', 401, 'Sign in again to create artwork.');
    res.status(202).json(await store().enqueue(id, key, name, proof, epoch));
  }));
  router.get('/', wrap(async (req, res) => { res.json(await store().list(owner(req))); }));
  router.get('/jobs/:id', wrap(async (req, res) => {
    const result = await store().job(owner(req), validID(req.params.id));
    if (!result) throw new FighterError('not_found', 404, 'Creation request not found.');
    res.json(result);
  }));
  router.get('/:id/sheet', wrap(async (req, res) => {
    const image = await store().sheet(owner(req), validID(req.params.id));
    if (!image) throw new FighterError('not_found', 404, 'Fighter artwork not found.');
    res.setHeader('Cache-Control', 'private, no-store'); res.type('image/png').send(image);
  }));
  router.get('/:id', wrap(async (req, res) => {
    const fighter = await store().fighter(owner(req), validID(req.params.id));
    if (!fighter) throw new FighterError('not_found', 404, 'Fighter not found.');
    res.json({ fighter });
  }));
  router.delete('/:id', wrap(async (req, res) => { await store().remove(owner(req), validID(req.params.id)); res.status(204).send(); }));
  router.post('/:id/report', wrap(async (req, res) => {
    const reason = req.body?.reason;
    if (!['unsafe','wrong_subject','poor_quality','other'].includes(reason)) throw new FighterError('invalid_request', 400, 'Choose a reason for the report.');
    await store().report(owner(req), validID(req.params.id), reason); res.status(204).send();
  }));
  return router;
}
