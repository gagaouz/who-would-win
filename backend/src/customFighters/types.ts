export const POSES = ['idle', 'anticipation', 'attack', 'reaction'] as const;
export type Pose = typeof POSES[number];
export type SubscriptionEnvironment = 'Sandbox' | 'Production';
export interface SubscriptionProof { periodKey: string; environment: SubscriptionEnvironment; expiresAt: string }
export type JobState = 'queued' | 'generating' | 'validating' | 'ready' | 'rejected' | 'failed' | 'reconciling' | 'cancelled';
export interface FighterManifest {
  schemaVersion: 1; assetID: string; version: 1; sha256: string; styleVersion: 'retro-v1';
  width: number; height: number; archetype: string; frames: Record<Pose, number[]>;
}
export interface Fighter {
  id: string; name: string; createdAt: string;
  appearance: { schemaVersion: 1; assetID: string; version: 1; sha256: string };
  manifest: FighterManifest; sheetPath: string;
}
export interface FighterJob {
  id: string; state: JobState; name: string; assetId?: string; errorCode?: string;
  createdAt: string; updatedAt: string;
}
export interface Allowance { limit: number; used: number; reserved: number; remaining: number; periodKey: string }
export interface ClaimedJob {
  id: string; ownerId: string; name: string; workerToken: string; expiresAt: string;
  environment: SubscriptionEnvironment; periodKey: string;
}
export interface ProviderUsage { operation: string; requestId?: string; inputTokens?: number; outputTokens?: number; estimatedMicrodollars?: number }
export class FighterError extends Error {
  constructor(public readonly code: string, public readonly status: number, message: string) { super(message); this.name = 'FighterError'; }
}
export class ProviderError extends Error {
  constructor(public readonly code: 'content_rejected' | 'provider_unavailable' | 'provider_uncertain' | 'quality_rejected', message: string) {
    super(message); this.name = 'ProviderError';
  }
}
