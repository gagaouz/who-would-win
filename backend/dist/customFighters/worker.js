"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.processNextFighter = processNextFighter;
exports.startCustomFighterWorker = startCustomFighterWorker;
exports.stopCustomFighterWorker = stopCustomFighterWorker;
const crypto_1 = require("crypto");
const config_1 = require("./config");
const png_1 = require("./png");
const provider_1 = require("./provider");
const store_1 = require("./store");
const types_1 = require("./types");
/** One claim does at most one image request. Uncertain paid outcomes never get automatic retries. */
async function processNextFighter(store, provider, available = config_1.requireGenerationAvailable) {
    available();
    await store.recover();
    const job = await store.claim();
    if (!job)
        return false;
    try {
        available();
        await provider.moderate(job.name);
        available();
        if (!await store.markDispatched(job)) {
            await store.fail(job, 'failed', 'subscription_expired');
            return true;
        }
        const usage = (value) => store.usage(job, value);
        const original = await provider.generate(job.name, usage);
        if (!await store.markValidating(job))
            return true; // Account deletion/cancellation won the race.
        const pack = await (0, png_1.validateAndPackSheet)(original, (0, crypto_1.randomUUID)());
        await provider.moderate(job.name, [pack.original, ...pack.poses]);
        available();
        pack.manifest.archetype = await provider.review(job.name, pack.runtime, usage);
        await store.publish(job, pack.original, pack.runtime, pack.manifest);
    }
    catch (error) {
        const code = error instanceof types_1.ProviderError ? error.code : 'provider_unavailable';
        await store.fail(job, code === 'provider_uncertain' ? 'reconciling' : code === 'content_rejected' || code === 'quality_rejected' ? 'rejected' : 'failed', code);
    }
    return true;
}
let timer, maintenance, running = false;
function startCustomFighterWorker() {
    if (timer)
        return;
    const tick = async () => {
        if (running || !(0, config_1.enabled)() || !(0, config_1.configured)())
            return;
        running = true;
        try {
            await processNextFighter((0, store_1.getFighterStore)(), new provider_1.OpenAISpriteProvider(process.env.SPRITE_OPENAI_API_KEY));
        }
        catch {
            console.warn('[custom-fighters] Worker unavailable; no request details logged.');
        }
        finally {
            running = false;
        }
    };
    timer = setInterval(() => { void tick(); }, 5000);
    timer.unref();
    // Privacy cleanup and abandoned-worker recovery continue when generation is switched off.
    const clean = async () => { try {
        await (0, store_1.getFighterStore)().recover();
    }
    catch { /* Retry next hour; never affect legacy gameplay. */ } };
    maintenance = setInterval(() => { void clean(); }, 60 * 60 * 1000);
    maintenance.unref();
    void clean();
    void tick();
}
function stopCustomFighterWorker() { if (timer)
    clearInterval(timer); if (maintenance)
    clearInterval(maintenance); timer = undefined; maintenance = undefined; }
