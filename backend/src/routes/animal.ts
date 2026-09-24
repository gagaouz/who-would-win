import { Router, Request, Response } from 'express';
import { animalRateLimit } from '../middleware/rateLimit';
import { sanitizeName } from '../middleware/sanitize';
import { createMessage } from '../services/anthropicClient';
import { cachedOperation } from '../services/responseStore';
import { requireAppAttest } from '../services/appAttest';
import { logCustomCreatureLookup } from '../services/customCreatureLogger';

const router = Router();
const DEFAULT_INFO = { emoji: '🐾', category: 'land', color: '#888888' } as const;

// Backward compatibility for App Store builds that put child-entered text in a
// URL. Do not forward those requests to Anthropic; new builds use POST only.
router.get('/animal', animalRateLimit, (_req: Request, res: Response): void => {
  res.setHeader('Deprecation', 'true');
  res.json(DEFAULT_INFO);
});

router.post('/animal', requireAppAttest, animalRateLimit, async (req: Request, res: Response): Promise<void> => {
  const sanitized = sanitizeName((req.body as Record<string, unknown> | undefined)?.['name']);
  if (!sanitized.ok) {
    res.json(DEFAULT_INFO);
    return;
  }

  // Keep the complete available list of accepted custom lookups in temporary
  // memory, including lookups whose classification later falls back or fails.
  logCustomCreatureLookup(sanitized.value);

  const controller = new AbortController();
  res.once('close', () => { if (!res.writableEnded) controller.abort(); });

  try {
    const { value } = await cachedOperation(
      'animal-info',
      sanitized.value.toLocaleLowerCase('en-US'),
      7 * 24 * 60 * 60 * 1000,
      async () => {
        const message = await createMessage('animal', {
          max_tokens: 60,
          messages: [{
            role: 'user',
            content:
              `Pick the single best emoji for the creature named "${sanitized.value}" and classify it. ` +
              `Respond with only JSON: {"emoji":"<one emoji>","category":"<land|sea|air|insect>","color":"<#RRGGBB>"}`,
          }],
        }, controller.signal);

        const block = message.content.find(item => item.type === 'text');
        const text = block && block.type === 'text' ? block.text : '';
        const match = text.match(/\{[\s\S]*\}/);
        const parsed = match ? JSON.parse(match[0]) as Record<string, unknown> : {};
        const emoji = typeof parsed['emoji'] === 'string'
          ? [...parsed['emoji']].slice(0, 4).join('') : DEFAULT_INFO.emoji;
        const category = ['land', 'sea', 'air', 'insect'].includes(String(parsed['category']))
          ? String(parsed['category']) : DEFAULT_INFO.category;
        const color = typeof parsed['color'] === 'string' && /^#[0-9a-f]{6}$/i.test(parsed['color'])
          ? parsed['color'] : DEFAULT_INFO.color;
        return { emoji, category, color };
      },
    );
    res.json(value);
  } catch (error) {
    if (!controller.signal.aborted) {
      console.error('[animal] lookup failed');
      res.json(DEFAULT_INFO);
    }
  }
});

export default router;
