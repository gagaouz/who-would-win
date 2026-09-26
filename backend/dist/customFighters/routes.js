"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validID = validID;
exports.validatedName = validatedName;
exports.createCustomFighterRouter = createCustomFighterRouter;
const express_1 = require("express");
const node_path_1 = require("node:path");
const sanitize_1 = require("../middleware/sanitize");
const customFighterAuth_1 = require("../services/customFighterAuth");
const config_1 = require("./config");
const store_1 = require("./store");
const types_1 = require("./types");
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function validID(value) {
    if (typeof value !== 'string' || !UUID.test(value))
        throw new types_1.FighterError('invalid_request', 400, 'Invalid fighter request.');
    return value.toLowerCase();
}
function validatedName(raw) {
    if (typeof raw !== 'string')
        throw new types_1.FighterError('invalid_request', 400, 'Enter a fighter name.');
    const normalized = raw.normalize('NFKC').trim().replace(/\s+/g, ' ');
    if (!normalized || [...normalized].length > 24 || /[\p{Cc}\p{Cf}]/u.test(normalized))
        throw new types_1.FighterError('name_not_allowed', 400, 'Choose a short, family-friendly name (24 characters or fewer).');
    const result = (0, sanitize_1.sanitizeName)(normalized);
    if (!result.ok || !result.value)
        throw new types_1.FighterError('name_not_allowed', 400, 'Choose a different, family-friendly fighter.');
    return result.value;
}
function createCustomFighterRouter(dependencies = {}) {
    const router = (0, express_1.Router)();
    const store = dependencies.store ?? store_1.getFighterStore;
    const subscription = dependencies.subscription ?? customFighterAuth_1.requireCustomFighterSubscription;
    const available = dependencies.available ?? config_1.requireGenerationAvailable;
    const status = dependencies.status ?? (() => ({ enabled: (0, config_1.enabled)(), configured: (0, config_1.configured)(), monthlyAllowance: (0, config_1.monthlyAllowance)(), requiresSubscription: true }));
    const owner = (req) => {
        const id = req.customFighterOwner?.id;
        if (!id)
            throw new types_1.FighterError('unauthorized', 401, 'Sign in to use your fighter library.');
        return id;
    };
    const wrap = (handler) => (req, res, next) => {
        Promise.resolve(handler(req, res, next)).catch((error) => {
            const value = error;
            const recognized = typeof value.status === 'number' && value.status >= 400 && value.status <= 599 && typeof value.code === 'string';
            res.status(recognized ? value.status : 503).json({
                code: recognized ? value.code : 'provider_unavailable',
                error: recognized ? value.message : 'The fighter library is temporarily unavailable.',
            });
        });
    };
    router.get('/status', (_req, res) => { res.json(status()); });
    router.get('/privacy', (_req, res) => {
        res.setHeader('Cache-Control', 'no-cache');
        res.sendFile((0, node_path_1.join)(__dirname, 'privacy.html'));
    });
    router.use(dependencies.owner ?? customFighterAuth_1.requireCustomFighterOwner);
    router.post('/status', wrap(async (req, res) => {
        const signed = req.body?.signedTransaction;
        if (signed == null || signed === '') {
            res.json({ ...status(), activeSubscription: false, allowance: { limit: (0, config_1.monthlyAllowance)(), used: 0, reserved: 0, remaining: 0, periodKey: new Date().toISOString().slice(0, 7) } });
            return;
        }
        if (typeof signed !== 'string' || signed.length > 20000)
            throw new types_1.FighterError('invalid_request', 400, 'Invalid subscription proof.');
        const proof = await subscription(owner(req), signed);
        res.json({ ...status(), activeSubscription: true, allowance: await store().allowance(owner(req), proof) });
    }));
    router.post('/', wrap(async (req, res) => {
        const name = validatedName(req.body?.name), key = validID(req.body?.idempotencyKey), id = owner(req);
        const prior = await store().existing(id, key, name);
        if (prior) {
            res.status(202).json(prior);
            return;
        }
        available();
        if (req.body?.consentVersion !== 'custom-art-v1')
            throw new types_1.FighterError('consent_required', 400, 'A grown-up must review the artwork service information before creation.');
        const signed = req.body?.signedTransaction;
        if (typeof signed !== 'string' || !signed || signed.length > 20000)
            throw new types_1.FighterError('subscription_required', 403, 'An active Premium subscription is required to create artwork.');
        const proof = await subscription(id, signed);
        const epoch = req.customFighterOwner?.libraryEpoch;
        if (!Number.isSafeInteger(epoch) || !epoch || epoch < 1)
            throw new types_1.FighterError('account_unavailable', 401, 'Sign in again to create artwork.');
        res.status(202).json(await store().enqueue(id, key, name, proof, epoch));
    }));
    router.get('/', wrap(async (req, res) => { res.json(await store().list(owner(req))); }));
    router.get('/jobs/:id', wrap(async (req, res) => {
        const result = await store().job(owner(req), validID(req.params.id));
        if (!result)
            throw new types_1.FighterError('not_found', 404, 'Creation request not found.');
        res.json(result);
    }));
    router.get('/:id/sheet', wrap(async (req, res) => {
        const image = await store().sheet(owner(req), validID(req.params.id));
        if (!image)
            throw new types_1.FighterError('not_found', 404, 'Fighter artwork not found.');
        res.setHeader('Cache-Control', 'private, no-store');
        res.type('image/png').send(image);
    }));
    router.get('/:id', wrap(async (req, res) => {
        const fighter = await store().fighter(owner(req), validID(req.params.id));
        if (!fighter)
            throw new types_1.FighterError('not_found', 404, 'Fighter not found.');
        res.json({ fighter });
    }));
    router.delete('/:id', wrap(async (req, res) => { await store().remove(owner(req), validID(req.params.id)); res.status(204).send(); }));
    router.post('/:id/report', wrap(async (req, res) => {
        const reason = req.body?.reason;
        if (!['unsafe', 'wrong_subject', 'poor_quality', 'other'].includes(reason))
            throw new types_1.FighterError('invalid_request', 400, 'Choose a reason for the report.');
        await store().report(owner(req), validID(req.params.id), reason);
        res.status(204).send();
    }));
    return router;
}
