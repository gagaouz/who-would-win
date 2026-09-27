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
/** Private diagnostic facts only. A completed HTTP response is never proof of a paid request's bill. */
export interface ProviderFailureMetadata {
  operation: 'moderation' | 'image' | 'review';
  outcome: 'http_refusal' | 'http_error' | 'timeout' | 'transport_error' | 'invalid_response' | 'safety_rejection' | 'quality_rejection';
  responseReceived: boolean;
  responseComplete: boolean;
  httpStatus?: number;
  requestID?: string;
  moderationStage?: 'input' | 'output' | 'unknown';
  paid: boolean;
  billing: 'unknown' | 'not_applicable';
}
export interface FailureDiagnostic {
  stage: 'name_moderation' | 'dispatch' | 'image_generation' | 'image_validation' | 'artwork_moderation' | 'artwork_review' | 'publication';
  reason?: string;
  provider?: ProviderFailureMetadata;
}
export class FighterError extends Error {
  constructor(public readonly code: string, public readonly status: number, message: string) { super(message); this.name = 'FighterError'; }
}
export class ProviderError extends Error {
  constructor(public readonly code: 'content_rejected' | 'provider_unavailable' | 'provider_uncertain' | 'quality_rejected', message: string,
    public readonly reason?: string, public readonly provider?: ProviderFailureMetadata) {
    super(message); this.name = 'ProviderError';
  }
}
