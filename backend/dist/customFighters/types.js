"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProviderError = exports.FighterError = exports.POSES = void 0;
exports.POSES = ['idle', 'anticipation', 'attack', 'reaction'];
class FighterError extends Error {
    constructor(code, status, message) {
        super(message);
        this.code = code;
        this.status = status;
        this.name = 'FighterError';
    }
}
exports.FighterError = FighterError;
class ProviderError extends Error {
    constructor(code, message, reason) {
        super(message);
        this.code = code;
        this.reason = reason;
        this.name = 'ProviderError';
    }
}
exports.ProviderError = ProviderError;
