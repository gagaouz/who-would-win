"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const sdk_1 = __importDefault(require("@anthropic-ai/sdk"));
const dotenv_1 = __importDefault(require("dotenv"));
const rateLimit_1 = require("../middleware/rateLimit");
const sanitize_1 = require("../middleware/sanitize");
dotenv_1.default.config({ override: true });
const router = (0, express_1.Router)();
const client = new sdk_1.default({ apiKey: process.env.ANTHROPIC_API_KEY });
// GET /api/animal?name=wolverine
// Shares the same per-IP rate limit bucket as /api/battle.
router.get('/animal', rateLimit_1.rateLimitMiddleware, async (req, res) => {
    const raw = req.query['name'];
    // Type-check: query params can technically be arrays if ?name=a&name=b
    if (typeof raw !== 'string') {
        res.status(400).json({ error: 'name query parameter must be a single string' });
        return;
    }
    const sanitized = (0, sanitize_1.sanitizeName)(raw);
    if (!sanitized.ok) {
        // Return a safe default rather than erroring — the app will still work
        res.json({ emoji: '🐾', category: 'land', color: '#888888' });
        return;
    }
    const name = sanitized.value;
    try {
        const message = await client.messages.create({
            model: 'claude-haiku-4-5',
            max_tokens: 80, // Emoji + category + hex color — 80 tokens is plenty
            messages: [{
                    role: 'user',
                    content: `For the animal or creature named "${name}", respond with ONLY a JSON object (no markdown):\n` +
                        `{"emoji":"<single emoji>","category":"<land|sea|air|insect>","color":"<hex>"}\n` +
                        `Use the closest animal emoji if no exact match exists.`,
                }],
        });
        const text = message.content[0].text.trim();
        const cleaned = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim();
        const parsed = JSON.parse(cleaned);
        // Validate the response shape before forwarding to the client
        const emoji = typeof parsed['emoji'] === 'string' ? parsed['emoji'] : '🐾';
        const category = ['land', 'sea', 'air', 'insect'].includes(parsed['category'])
            ? parsed['category'] : 'land';
        const color = typeof parsed['color'] === 'string' && /^#[0-9a-fA-F]{6}$/.test(parsed['color'])
            ? parsed['color'] : '#888888';
        res.json({ emoji, category, color });
    }
    catch (err) {
        console.error('Animal info error:', err);
        res.json({ emoji: '🐾', category: 'land', color: '#888888' });
    }
});
exports.default = router;
