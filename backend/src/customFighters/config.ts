import { FighterError } from './types';

export const IMAGE_MODEL = 'gpt-image-2.5-flare-2026-09-08';
export const REVIEW_MODEL = 'gpt-4.1-mini-2025-04-14';
export const MAX_PNG_BYTES = 8 * 1024 * 1024;
export const MAX_LIBRARY_SIZE = 100;
export const JOB_RESERVATION_MICRODOLLARS = 1_000_000;
export const LEASE_MS = 12 * 60 * 1000;

export function enabled(): boolean { return process.env.SPRITE_GENERATION_ENABLED === 'true'; }
export function configured(): boolean {
  const entitlementReady = process.env.SPRITE_ALLOW_SANDBOX === 'true'
    || (process.env.SPRITE_ALLOW_PRODUCTION === 'true' && Boolean(process.env.SPRITE_APPLE_PRIVATE_KEY && process.env.SPRITE_APPLE_KEY_ID && process.env.SPRITE_APPLE_ISSUER_ID));
  return Boolean(entitlementReady && process.env.SPRITE_OPENAI_API_KEY && (process.env.DATABASE_PRIVATE_URL || process.env.DATABASE_URL));
}
export function monthlyAllowance(): number {
  const value = Number(process.env.SPRITE_MONTHLY_ALLOWANCE ?? '3');
  return Number.isInteger(value) && value >= 1 && value <= 10 ? value : 3;
}
/** A lifetime beta ledger, not a reset-on-restart/month counter. Raising it is an operator action. */
export function budgetMicrodollars(): number {
  const value = Number(process.env.SPRITE_BETA_BUDGET_USD ?? '5');
  return Number.isFinite(value) && value > 0 && value <= 100 ? Math.round(value * 1_000_000) : 5_000_000;
}
export function requireGenerationAvailable(): void {
  if (!enabled()) throw new FighterError('feature_disabled', 503, 'Custom artwork creation is not available yet. Your saved fighters are still yours.');
  if (!configured()) throw new FighterError('provider_unavailable', 503, 'Custom artwork creation is temporarily unavailable.');
}
export function allowedEnvironment(environment: string): boolean {
  return (environment === 'Sandbox' && process.env.SPRITE_ALLOW_SANDBOX === 'true')
    || (environment === 'Production' && process.env.SPRITE_ALLOW_PRODUCTION === 'true');
}
