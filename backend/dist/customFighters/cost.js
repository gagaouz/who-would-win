"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.successfulPublicationCostBound = successfulPublicationCostBound;
exports.failedWorkflowCostBound = failedWorkflowCostBound;
/** A complete usage record for every paid operation that could have been dispatched. */
function completedOperationsCostBound(usage, expected) {
    if (!Array.isArray(usage) || usage.length !== expected.length)
        return null;
    const operations = new Set();
    let upperBound = 0;
    for (const item of usage) {
        if (!item || typeof item !== 'object' || !expected.includes(item.operation)
            || operations.has(item.operation))
            return null;
        operations.add(item.operation);
        const { inputTokens, outputTokens, estimatedMicrodollars } = item;
        if (![inputTokens, outputTokens, estimatedMicrodollars].every(value => Number.isSafeInteger(value) && value >= 0)
            || inputTokens > 1000000 || outputTokens > 1000000)
            return null;
        // Pinned model rates, in microdollars: all image input uses the higher image rate.
        const tokens = item.operation === 'image'
            ? inputTokens * 8 + outputTokens * 30
            : Math.ceil((inputTokens * 4 + outputTokens * 16) / 10);
        upperBound += Math.max(estimatedMicrodollars, tokens);
        if (!Number.isSafeInteger(upperBound))
            return null;
    }
    // Round the full workflow up to a cent, then double it; retain at least ten cents.
    const exposure = Math.max(100000, Math.ceil(upperBound / 10000) * 10000 * 2);
    return Number.isSafeInteger(exposure) ? exposure : null;
}
function successfulPublicationCostBound(usage) {
    return completedOperationsCostBound(usage, ['image', 'review']);
}
/** No guess about refusal billing: missing usage or an unknown stage keeps the hold. */
function failedWorkflowCostBound(usage, stage) {
    switch (stage) {
        case 'image_generation':
        case 'image_validation':
        case 'artwork_moderation':
            return completedOperationsCostBound(usage, ['image']);
        case 'artwork_review':
        case 'publication':
            return completedOperationsCostBound(usage, ['image', 'review']);
        default:
            return null;
    }
}
