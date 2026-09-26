import { randomUUID } from 'crypto';
import { configured, enabled, requireGenerationAvailable } from './config';
import { validateAndPackSheet } from './png';
import { OpenAISpriteProvider, SpriteProvider } from './provider';
import { FighterStore, getFighterStore } from './store';
import { ProviderError } from './types';

/** One claim does at most one image request. Uncertain paid outcomes never get automatic retries. */
export async function processNextFighter(store: FighterStore, provider: SpriteProvider, available: () => void = requireGenerationAvailable): Promise<boolean> {
  available();
  await store.recover();
  const job = await store.claim();
  if (!job) return false;
  try {
    available();
    await provider.moderate(job.name);
    available();
    if (!await store.markDispatched(job)) {
      await store.fail(job, 'failed', 'subscription_expired'); return true;
    }
    const usage = (value: Parameters<FighterStore['usage']>[1]) => store.usage(job, value);
    const original = await provider.generate(job.name, usage);
    if (!await store.markValidating(job)) return true; // Account deletion/cancellation won the race.
    const pack = await validateAndPackSheet(original, randomUUID());
    await provider.moderate(job.name, [pack.original, ...pack.poses]);
    available();
    pack.manifest.archetype = await provider.review(job.name, pack.runtime, usage);
    await store.publish(job, pack.original, pack.runtime, pack.manifest);
  } catch (error) {
    const code = error instanceof ProviderError ? error.code : 'provider_unavailable';
    await store.fail(job, code === 'provider_uncertain' ? 'reconciling' : code === 'content_rejected' || code === 'quality_rejected' ? 'rejected' : 'failed', code);
  }
  return true;
}

let timer: NodeJS.Timeout | undefined, maintenance: NodeJS.Timeout | undefined, running = false;
export function startCustomFighterWorker(): void {
  if (timer) return;
  const tick = async () => {
    if (running || !enabled() || !configured()) return;
    running = true;
    try { await processNextFighter(getFighterStore(), new OpenAISpriteProvider(process.env.SPRITE_OPENAI_API_KEY!)); }
    catch { console.warn('[custom-fighters] Worker unavailable; no request details logged.'); }
    finally { running = false; }
  };
  timer = setInterval(() => { void tick(); }, 5_000); timer.unref();
  // Privacy cleanup and abandoned-worker recovery continue when generation is switched off.
  const clean = async () => { try { await getFighterStore().recover(); } catch { /* Retry next hour; never affect legacy gameplay. */ } };
  maintenance = setInterval(() => { void clean(); }, 60 * 60 * 1000); maintenance.unref();
  void clean();
  void tick();
}
export function stopCustomFighterWorker(): void { if (timer) clearInterval(timer); if (maintenance) clearInterval(maintenance); timer = undefined; maintenance = undefined; }
