import Anthropic from '@anthropic-ai/sdk';
import type { Message, MessageCreateParamsNonStreaming } from '@anthropic-ai/sdk/resources/messages/messages';
import { AiOperation, runAiOperation } from './costControl';

export const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL ?? 'claude-haiku-4-5-20251001';
let client: Anthropic | null = null;

function getClient(): Anthropic {
  if (client) return client;
  client = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY,
    maxRetries: 0,
    timeout: Number(process.env.ANTHROPIC_TIMEOUT_MS ?? 15_000),
  });
  return client;
}

export async function createMessage(
  operation: AiOperation,
  params: Omit<MessageCreateParamsNonStreaming, 'model'> & { model?: string },
  signal?: AbortSignal,
): Promise<Message> {
  return runAiOperation(operation, () => getClient().messages.create(
    { ...params, model: params.model ?? ANTHROPIC_MODEL } as MessageCreateParamsNonStreaming,
    signal ? { signal } : undefined,
  ));
}
