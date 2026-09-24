"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const rateLimit_1 = require("../middleware/rateLimit");
const sanitize_1 = require("../middleware/sanitize");
const anthropicClient_1 = require("../services/anthropicClient");
const responseStore_1 = require("../services/responseStore");
const appAttest_1 = require("../services/appAttest");
const customCreatureLogger_1 = require("../services/customCreatureLogger");
const router = (0, express_1.Router)();
const DEFAULT_INFO = { emoji: '🐾', category: 'land', color: '#888888' };
// Backward compatibility for App Store builds that put child-entered text in a
// URL. Do not forward those requests to Anthropic; new builds use POST only.
router.get('/animal', rateLimit_1.animalRateLimit, (_req, res) => {
    res.setHeader('Deprecation', 'true');
    res.json(DEFAULT_INFO);
});
router.post('/animal', appAttest_1.requireAppAttest, rateLimit_1.animalRateLimit, async (req, res) => {
    const sanitized = (0, sanitize_1.sanitizeName)(req.body?.['name']);
    if (!sanitized.ok) {
        res.json(DEFAULT_INFO);
        return;
    }
    // Keep the complete available list of accepted custom lookups in temporary
    // memory, including lookups whose classification later falls back or fails.
    (0, customCreatureLogger_1.logCustomCreatureLookup)(sanitized.value);
    const controller = new AbortController();
    res.once('close', () => { if (!res.writableEnded)
        controller.abort(); });
    try {
        const { value } = await (0, responseStore_1.cachedOperation)('animal-info', sanitized.value.toLocaleLowerCase('en-US'), 7 * 24 * 60 * 60 * 1000, async () => {
            const message = await (0, anthropicClient_1.createMessage)('animal', {
                max_tokens: 60,
                messages: [{
                        role: 'user',
                        content: `Pick the single best emoji for the creature named "${sanitized.value}" and classify it. ` +
                            `Respond with only JSON: {"emoji":"<one emoji>","category":"<land|sea|air|insect>","color":"<#RRGGBB>"}`,
                    }],
            }, controller.signal);
            const block = message.content.find(item => item.type === 'text');
            const text = block && block.type === 'text' ? block.text : '';
            const match = text.match(/\{[\s\S]*\}/);
            const parsed = match ? JSON.parse(match[0]) : {};
            const emoji = typeof parsed['emoji'] === 'string'
                ? [...parsed['emoji']].slice(0, 4).join('') : DEFAULT_INFO.emoji;
            const category = ['land', 'sea', 'air', 'insect'].includes(String(parsed['category']))
                ? String(parsed['category']) : DEFAULT_INFO.category;
            const color = typeof parsed['color'] === 'string' && /^#[0-9a-f]{6}$/i.test(parsed['color'])
                ? parsed['color'] : DEFAULT_INFO.color;
            return { emoji, category, color };
        });
        res.json(value);
    }
    catch (error) {
        if (!controller.signal.aborted) {
            console.error('[animal] lookup failed');
            res.json(DEFAULT_INFO);
        }
    }
});
exports.default = router;
