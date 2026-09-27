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
    let stage = 'name_moderation';
    try {
        available();
        await provider.moderate(job.name);
        available();
        stage = 'dispatch';
        if (!await store.markDispatched(job)) {
            await store.fail(job, 'failed', 'subscription_expired', { stage });
            return true;
        }
        const usage = (value) => store.usage(job, value);
        stage = 'image_generation';
        const original = await provider.generate(job.name, usage);
        if (!await store.markValidating(job))
            return true; // Account deletion/cancellation won the race.
        stage = 'image_validation';
        const pack = await (0, png_1.validateAndPackSheet)(original, (0, crypto_1.randomUUID)());
        stage = 'artwork_moderation';
        await provider.moderate(job.name, [pack.original, ...pack.poses]);
        available();
        stage = 'artwork_review';
        pack.manifest.archetype = await provider.review(job.name, pack.runtime, usage);
        stage = 'publication';
        await store.publish(job, pack.original, pack.runtime, pack.manifest);
    }
    catch (error) {
        const providerCode = error instanceof types_1.ProviderError ? error.code : 'provider_unavailable';
        // Once the subject passed screening, an image/refusal does not establish that the
        // user's name was inappropriate. Existing clients show the credit-returned artwork
        // message while the private diagnostic preserves the actual failed safety stage.
        const code = providerCode === 'content_rejected' && stage !== 'name_moderation' ? 'quality_rejected' : providerCode;
        await store.fail(job, code === 'provider_uncertain' ? 'reconciling' : code === 'content_rejected' || code === 'quality_rejected' ? 'rejected' : 'failed', code, { stage, reason: error instanceof types_1.ProviderError ? error.reason : undefined });
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
