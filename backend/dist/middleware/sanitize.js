"use strict";
/**
 * Input sanitization for animal/fighter names.
 *
 * Defends against:
 *  - Prompt injection (instructions embedded in fighter names)
 *  - Absurdly long inputs that waste Claude tokens
 *  - Control characters and null bytes
 *  - HTML/script injection (not a threat here, but cheap to block)
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.MAX_NAME_LENGTH = void 0;
exports.isSafeGeneratedText = isSafeGeneratedText;
exports.sanitizeName = sanitizeName;
exports.sanitizeFighterId = sanitizeFighterId;
exports.sanitizeEnvironment = sanitizeEnvironment;
exports.sanitizeTournamentContext = sanitizeTournamentContext;
// Maximum characters allowed in any name field
exports.MAX_NAME_LENGTH = 60;
// Characters we allow: letters (any script/emoji fine), digits, spaces,
// apostrophes, hyphens, dots.  Everything else is stripped.
const ALLOWED_CHARS = /[^\p{L}\p{N}\p{Emoji_Presentation}\p{Emoji}\s'\-\.]/gu;
// Words that are never appropriate in a kids app — whole-word match only
// (split on whitespace, check each token) to avoid the Scunthorpe problem.
const BLOCKED_WORDS = new Set([
    // Sexual anatomy
    'penis', 'vagina', 'vulva', 'anus', 'anal', 'rectum', 'testicle', 'testicles',
    'scrotum', 'breasts', 'nipple', 'nipples', 'clitoris', 'genitals', 'genitalia', 'foreskin',
    // Sexual profanity
    'fuck', 'shit', 'bitch', 'cunt', 'ass', 'asshole', 'cock', 'dick', 'pussy',
    'whore', 'slut', 'cum', 'semen', 'sperm', 'tits', 'boobs', 'butthole', 'twat',
    'wank', 'wanker', 'jizz', 'boner',
    // NSFW concepts
    'porn', 'porno', 'naked', 'nude', 'erection', 'dildo', 'vibrator', 'condom',
    'sexting', 'blowjob', 'handjob', 'rimjob', 'threesome', 'orgasm', 'masturbate',
    'masturbation', 'intercourse', 'prostitute', 'prostitution', 'stripper', 'brothel',
    // Mild profanity (kids app)
    'bastard', 'piss', 'prick', 'crap', 'damn', 'hell', 'damnit', 'goddamn',
    'bullshit', 'horseshit', 'jackass', 'dumbass', 'dipshit', 'dickhead',
    // Slurs
    'nigger', 'nigga', 'faggot', 'fag', 'kike', 'spic', 'chink', 'wetback',
    'tranny', 'coon', 'gook', 'retard', 'cracker', 'dyke', 'beaner', 'towelhead',
    'raghead', 'zipperhead', 'sandnigger', 'honky',
    // Drugs
    'cocaine', 'heroin', 'meth', 'methamphetamine', 'marijuana', 'weed', 'crack',
    'fentanyl', 'mdma', 'ecstasy', 'lsd', 'opioid', 'opioids', 'ketamine',
    'shrooms', 'mushrooms', 'peyote', 'mescaline', 'amphetamine', 'amphetamines',
    'xanax', 'adderall', 'morphine', 'oxycodone', 'oxycontin',
    // Violence / harm
    'rape', 'murder', 'kill', 'suicide', 'terrorist', 'terrorism', 'genocide',
    'torture', 'massacre', 'stabbing', 'shooting', 'assault', 'molest', 'molestation',
    'pedophile', 'pedophilia', 'incest', 'necrophilia', 'bestiality',
]);
// Legitimate real animals whose names contain a blocked whole word
// ("sperm" in "sperm whale", "ass" in "wild ass"). Scrubbed out before the
// word-level check. Longest variants first so they're consumed before a bare
// "sperm"/"ass" can match.
const ALLOWED_ANIMAL_PHRASES = [
    'pygmy sperm whale', 'dwarf sperm whale', 'sperm whale',
    'african wild ass', 'asiatic wild ass', 'asian wild ass',
    'indian wild ass', 'mongolian wild ass', 'somali wild ass',
    'persian wild ass', 'tibetan wild ass', 'wild ass',
];
function containsBlockedWord(s) {
    let scrubbed = s.normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase();
    for (const phrase of ALLOWED_ANIMAL_PHRASES) {
        if (scrubbed.includes(phrase))
            scrubbed = scrubbed.split(phrase).join(' ');
    }
    const wordForm = scrubbed.replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
    const tokens = wordForm.split(/\s+/).filter(Boolean);
    if (tokens.some(w => BLOCKED_WORDS.has(w)))
        return true;
    // Also catch punctuation-separated spelling such as "f.u.c.k" while
    // retaining whole-word boundaries so harmless words like "bass" survive.
    return [...BLOCKED_WORDS].some(word => {
        if (word.length < 4)
            return false;
        const separated = word.split('').join('[^\\p{L}\\p{N}]*');
        return new RegExp(`(^|[^\\p{L}\\p{N}])${separated}($|[^\\p{L}\\p{N}])`, 'iu').test(scrubbed);
    });
}
function isSafeGeneratedText(value) {
    return !containsBlockedWord(value)
        && !/<\/?[a-z][^>]*>/i.test(value)
        && !/https?:\/\/|www\./i.test(value);
}
// Phrases that look like prompt injection or jailbreak attempts
const INJECTION_PATTERNS = [
    /ignore\s+(all\s+)?(previous|above|prior)\s+instructions?/i,
    /forget\s+(everything|all|previous)/i,
    /you\s+are\s+now\s+(a|an)/i,
    /act\s+as\s+(a|an)/i,
    /pretend\s+(you\s+are|to\s+be)/i,
    /system\s*:/i,
    /\[system\]/i,
    /\[user\]/i,
    /\[assistant\]/i,
    /<\/?[a-z]+[^>]*>/i, // HTML tags
    /```/, // Code fences (used to escape JSON context)
    /\\\"/, // Escaped quotes trying to break JSON
    /(\w)\1{8,}/, // Eight or more repeated chars ("aaaaaaaaa")
];
function sanitizeName(raw) {
    if (typeof raw !== 'string') {
        return { ok: false, value: '', error: 'must be a string' };
    }
    // Trim whitespace
    let s = raw.normalize('NFKC').trim();
    if (s.length === 0) {
        return { ok: false, value: '', error: 'cannot be empty' };
    }
    // Do not accept obvious personal contact details as a creature name.
    if (/\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/i.test(s)
        || /\b(?:https?:\/\/|www\.)\S+/i.test(s)
        || /(?:\+?\d[\s().-]*){8,}/.test(s)) {
        return { ok: false, value: '', error: 'personal contact information is not allowed' };
    }
    // Hard length cap BEFORE any other processing (don't even process huge strings)
    if (s.length > exports.MAX_NAME_LENGTH * 4) {
        return { ok: false, value: '', error: `too long (max ${exports.MAX_NAME_LENGTH} characters)` };
    }
    // Block inappropriate content for this kids app
    if (containsBlockedWord(s)) {
        return { ok: false, value: '', error: 'name is not allowed' };
    }
    // Check for prompt injection patterns on the raw string
    for (const pattern of INJECTION_PATTERNS) {
        if (pattern.test(s)) {
            return { ok: false, value: '', error: 'invalid characters or patterns in name' };
        }
    }
    // Strip disallowed characters
    s = s.replace(ALLOWED_CHARS, '').replace(/\s+/g, ' ').trim();
    // After stripping, enforce the length limit
    if (s.length > exports.MAX_NAME_LENGTH) {
        s = s.slice(0, exports.MAX_NAME_LENGTH).trim();
    }
    if (s.length === 0) {
        return { ok: false, value: '', error: 'name contains no valid characters' };
    }
    return { ok: true, value: s };
}
// Built-in IDs use underscores. Privacy-preserving custom IDs use UUIDs, so
// hyphens are valid as well; no other punctuation reaches prompts or queries.
const FIGHTER_ID = /^[a-z0-9_-]{1,64}$/;
function sanitizeFighterId(raw) {
    if (typeof raw !== 'string')
        return { ok: false, value: '', error: 'must be a string' };
    const value = raw.trim().toLowerCase();
    if (!FIGHTER_ID.test(value)) {
        return { ok: false, value: '', error: 'must contain only lowercase letters, numbers, underscores, and hyphens' };
    }
    return { ok: true, value };
}
const ENVIRONMENTS = new Map([
    ['grassland', 'Grassland'], ['ocean', 'Ocean'], ['sky', 'Sky'],
    ['arctic', 'Arctic'], ['desert', 'Desert'], ['jungle', 'Jungle'],
    ['volcano', 'Volcano'], ['night', 'Night'], ['storm', 'Storm'],
]);
function sanitizeEnvironment(raw) {
    if (typeof raw !== 'string')
        return undefined;
    return ENVIRONMENTS.get(raw.trim().toLowerCase());
}
function sanitizeTournamentContext(raw) {
    if (typeof raw !== 'string')
        return undefined;
    const value = raw.toLowerCase();
    if (value.includes('championship') || value.includes('final'))
        return 'This is the tournament final.';
    if (value.includes('semifinal'))
        return 'This is a tournament semifinal.';
    if (value.includes('quarterfinal'))
        return 'This is a tournament quarterfinal.';
    if (value.includes('round of 16'))
        return 'This is a tournament round-of-16 battle.';
    if (value.includes('round of 32'))
        return 'This is a tournament round-of-32 battle.';
    if (value.includes('tournament'))
        return 'This is an early-round tournament battle.';
    return undefined;
}
