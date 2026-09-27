/** Complete successful workflows only; this does not reconcile failures or unknown charges. */
export function successfulPublicationCostBound(usage: unknown): number | null {
  if (!Array.isArray(usage) || usage.length !== 2) return null;
  const operations = new Set<string>();
  let upperBound = 0;
  for (const item of usage) {
    if (!item || typeof item !== 'object' || !['image', 'review'].includes(item.operation)
        || operations.has(item.operation)) return null;
    operations.add(item.operation);
    const { inputTokens, outputTokens, estimatedMicrodollars } = item;
    if (![inputTokens, outputTokens, estimatedMicrodollars].every(value => Number.isSafeInteger(value) && value >= 0)
        || inputTokens > 1_000_000 || outputTokens > 1_000_000) return null;
    // Pinned model rates, in microdollars: all image input uses the higher image rate.
    const tokens = item.operation === 'image'
      ? inputTokens * 8 + outputTokens * 30
      : Math.ceil((inputTokens * 4 + outputTokens * 16) / 10);
    upperBound += Math.max(estimatedMicrodollars, tokens);
    if (!Number.isSafeInteger(upperBound)) return null;
  }
  // Round the full workflow up to a cent, then double it; retain at least ten cents.
  const exposure = Math.max(100_000, Math.ceil(upperBound / 10_000) * 10_000 * 2);
  return Number.isSafeInteger(exposure) ? exposure : null;
}
