/**
 * Input sanitization for animal/fighter names.
 *
 * Defends against:
 *  - Prompt injection (instructions embedded in fighter names)
 *  - Absurdly long inputs that waste Claude tokens
 *  - Control characters and null bytes
 *  - HTML/script injection (not a threat here, but cheap to block)
 */

// Maximum characters allowed in any name field
export const MAX_NAME_LENGTH = 60;

// Characters we allow: letters (any script/emoji fine), digits, spaces,
// apostrophes, hyphens, dots.  Everything else is stripped.
const ALLOWED_CHARS = /[^\p{L}\p{N}\p{Emoji_Presentation}\p{Emoji}\s'\-\.]/gu;

// Words that are never appropriate in a kids app — whole-word match only
// (split on whitespace, check each token) to avoid the Scunthorpe problem.
const BLOCKED_WORDS = new Set([
  'penis','vagina','vulva','anus','anal','rectum','testicle','testicles',
  'scrotum','breasts','nipple','nipples','clitoris','cock','dick','pussy',
  'cunt','ass','asshole','fuck','shit','bitch','whore','slut','cum',
  'semen','sperm','porn','porno','naked','nude','genitals','genitalia',
  'erection','dildo','vibrator','condom','foreskin','butthole','tits',
  'boobs','boner','jizz','wank','wanker','twat',
]);

function containsBlockedWord(s: string): boolean {
  return s.toLowerCase().split(/\s+/).some(w => BLOCKED_WORDS.has(w));
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
  /<\/?[a-z]+[^>]*>/i,          // HTML tags
  /```/,                          // Code fences (used to escape JSON context)
  /\\\"/,                         // Escaped quotes trying to break JSON
  /(\w)\1{8,}/,                   // Eight or more repeated chars ("aaaaaaaaa")
];

export interface SanitizeResult {
  ok:    boolean;
  value: string;
  error?: string;
}

export function sanitizeName(raw: unknown): SanitizeResult {
  if (typeof raw !== 'string') {
    return { ok: false, value: '', error: 'must be a string' };
  }

  // Trim whitespace
  let s = raw.trim();

  if (s.length === 0) {
    return { ok: false, value: '', error: 'cannot be empty' };
  }

  // Hard length cap BEFORE any other processing (don't even process huge strings)
  if (s.length > MAX_NAME_LENGTH * 4) {
    return { ok: false, value: '', error: `too long (max ${MAX_NAME_LENGTH} characters)` };
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
  if (s.length > MAX_NAME_LENGTH) {
    s = s.slice(0, MAX_NAME_LENGTH).trim();
  }

  if (s.length === 0) {
    return { ok: false, value: '', error: 'name contains no valid characters' };
  }

  return { ok: true, value: s };
}
