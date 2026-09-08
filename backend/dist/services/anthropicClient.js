"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ANTHROPIC_MODEL = void 0;
exports.createMessage = createMessage;
const sdk_1 = __importDefault(require("@anthropic-ai/sdk"));
const costControl_1 = require("./costControl");
exports.ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL ?? 'claude-haiku-4-5-20251001';
let client = null;
function getClient() {
    if (client)
        return client;
    client = new sdk_1.default({
        apiKey: process.env.ANTHROPIC_API_KEY,
        maxRetries: 0,
        timeout: Number(process.env.ANTHROPIC_TIMEOUT_MS ?? 15000),
    });
    return client;
}
async function createMessage(operation, params, signal) {
    return (0, costControl_1.runAiOperation)(operation, () => getClient().messages.create({ ...params, model: params.model ?? exports.ANTHROPIC_MODEL }, signal ? { signal } : undefined));
}
