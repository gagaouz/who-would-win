import { Router, Request, Response } from 'express';
import Anthropic from '@anthropic-ai/sdk';
import dotenv from 'dotenv';
import { rateLimitMiddleware } from '../middleware/rateLimit';
import { sanitizeName } from '../middleware/sanitize';
dotenv.config({ override: true });

const router = Router();
const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// GET /api/animal?name=wolverine
// Shares the same per-IP rate limit bucket as /api/battle.
router.get('/animal', rateLimitMiddleware, async (req: Request, res: Response): Promise<void> => {
  const raw = req.query['name'];

  // Type-check: query params can technically be arrays if ?name=a&name=b
  if (typeof raw !== 'string') {
    res.status(400).json({ error: 'name query parameter must be a single string' });
    return;
  }

  const sanitized = sanitizeName(raw);
  if (!sanitized.ok) {
    // Return a safe default rather than erroring — the app will still work
    res.json({ emoji: '🐾', category: 'land', color: '#888888' });
    return;
  }

  const name = sanitized.value;

  try {
    const message = await client.messages.create({
      model: 'claude-haiku-4-5',
      max_tokens: 80,   // Emoji + category + hex color — 80 tokens is plenty
      messages: [{
        role: 'user',
        content:
          `For the animal or creature named "${name}", respond with ONLY a JSON object (no markdown):\n` +
          `{"emoji":"<single emoji>","category":"<land|sea|air|insect>","color":"<hex>"}\n` +
          `Use the closest animal emoji if no exact match exists.`,
      }],
    });

    const text = (message.content[0] as { type: string; text: string }).text.trim();
    const cleaned = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim();
    const parsed = JSON.parse(cleaned) as Record<string, unknown>;

    // Validate the response shape before forwarding to the client
    const emoji    = typeof parsed['emoji']    === 'string' ? parsed['emoji']    : '🐾';
    const category = ['land','sea','air','insect'].includes(parsed['category'] as string)
                     ? parsed['category'] as string : 'land';
    const color    = typeof parsed['color'] === 'string' && /^#[0-9a-fA-F]{6}$/.test(parsed['color'] as string)
                     ? parsed['color'] as string : '#888888';

    res.json({ emoji, category, color });
  } catch (err) {
    console.error('Animal info error:', err);
    res.json({ emoji: '🐾', category: 'land', color: '#888888' });
  }
});

export default router;
