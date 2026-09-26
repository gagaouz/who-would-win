"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LEASE_MS = exports.JOB_RESERVATION_MICRODOLLARS = exports.MAX_LIBRARY_SIZE = exports.MAX_PNG_BYTES = exports.REVIEW_MODEL = exports.IMAGE_MODEL = void 0;
exports.enabled = enabled;
exports.configured = configured;
exports.monthlyAllowance = monthlyAllowance;
exports.budgetMicrodollars = budgetMicrodollars;
exports.requireGenerationAvailable = requireGenerationAvailable;
exports.allowedEnvironment = allowedEnvironment;
const types_1 = require("./types");
exports.IMAGE_MODEL = 'gpt-image-2.5-flare-2026-09-08';
exports.REVIEW_MODEL = 'gpt-4.1-mini-2025-04-14';
exports.MAX_PNG_BYTES = 8 * 1024 * 1024;
exports.MAX_LIBRARY_SIZE = 100;
exports.JOB_RESERVATION_MICRODOLLARS = 1000000;
exports.LEASE_MS = 12 * 60 * 1000;
function enabled() { return process.env.SPRITE_GENERATION_ENABLED === 'true'; }
function configured() {
    const entitlementReady = process.env.SPRITE_ALLOW_SANDBOX === 'true'
        || (process.env.SPRITE_ALLOW_PRODUCTION === 'true' && Boolean(process.env.SPRITE_APPLE_PRIVATE_KEY && process.env.SPRITE_APPLE_KEY_ID && process.env.SPRITE_APPLE_ISSUER_ID));
    return Boolean(entitlementReady && process.env.SPRITE_OPENAI_API_KEY && (process.env.DATABASE_PRIVATE_URL || process.env.DATABASE_URL));
}
function monthlyAllowance() {
    const value = Number(process.env.SPRITE_MONTHLY_ALLOWANCE ?? '3');
    return Number.isInteger(value) && value >= 1 && value <= 10 ? value : 3;
}
/** A lifetime beta ledger, not a reset-on-restart/month counter. Raising it is an operator action. */
function budgetMicrodollars() {
    const value = Number(process.env.SPRITE_BETA_BUDGET_USD ?? '5');
    return Number.isFinite(value) && value > 0 && value <= 100 ? Math.round(value * 1000000) : 5000000;
}
function requireGenerationAvailable() {
    if (!enabled())
        throw new types_1.FighterError('feature_disabled', 503, 'Custom artwork creation is not available yet. Your saved fighters are still yours.');
    if (!configured())
        throw new types_1.FighterError('provider_unavailable', 503, 'Custom artwork creation is temporarily unavailable.');
}
function allowedEnvironment(environment) {
    return (environment === 'Sandbox' && process.env.SPRITE_ALLOW_SANDBOX === 'true')
        || (environment === 'Production' && process.env.SPRITE_ALLOW_PRODUCTION === 'true');
}
