"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MAX_NAME_LENGTH = void 0;
exports.storyProblem = storyProblem;
exports.repairStory = repairStory;
exports.isSafeGeneratedText = isSafeGeneratedText;
exports.sanitizeName = sanitizeName;
exports.sanitizeFighterId = sanitizeFighterId;
exports.sanitizeEnvironment = sanitizeEnvironment;
exports.sanitizeTournamentContext = sanitizeTournamentContext;
/**
 * Input sanitization for animal/fighter names.
 *
 * Defends against:
 *  - Prompt injection (instructions embedded in fighter names)
 *  - Absurdly long inputs that waste Claude tokens
 *  - Control characters and null bytes
 *  - HTML/script injection (not a threat here, but cheap to block)
 *
 * Also holds the kid-safety check for AI-written stories (storyProblem).
 */
const creatures_1 = require("../data/creatures");
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
    // Hate, extremism and notorious killers — the app shows real photos for
    // custom names, so these must never become a fighter. KEEP IN SYNC with
    // ios/WhoWouldWin/Services/ContentFilter.swift.
    'hitler', 'adolf', 'nazi', 'nazis', 'neonazi', 'swastika', 'goebbels', 'himmler',
    'mussolini', 'stalin', 'kkk', 'klan', 'supremacist', 'osama', 'binladen',
    'alqaeda', 'taliban', 'dahmer',
    // Weapons and gore
    'gun', 'guns', 'handgun', 'pistol', 'rifle', 'shotgun', 'ak47', 'machinegun',
    'bomb', 'bombs', 'grenade', 'grenades', 'nuke', 'nukes', 'knife', 'knives',
    'explosive', 'explosives', 'shooter', 'corpse', 'behead', 'decapitate', 'gore',
]);
// Multi-word names blocked as a whole (matched on whole words).
const BLOCKED_PHRASES = [
    'bin laden', 'ku klux klan', 'al qaeda', 'al qaida', 'islamic state',
    'white power', 'white supremacy', 'pol pot', 'ted bundy', 'charles manson',
    'jeffrey dahmer', 'school shooter', 'school shooting', 'mass shooting',
    'machine gun', 'ak 47', 'ar 15', 'atomic bomb', 'nuclear bomb',
];
// Legitimate real animals whose names contain a blocked whole word
// ("sperm" in "sperm whale", "ass" in "wild ass"). Scrubbed out before the
// word-level check. Longest variants first so they're consumed before a bare
// "sperm"/"ass" can match.
// "Maine Coon" is a built-in fighter; "coon" alone is a slur.
const ALLOWED_ANIMAL_PHRASES = [
    'pygmy sperm whale', 'dwarf sperm whale', 'sperm whale',
    'african wild ass', 'asiatic wild ass', 'asian wild ass',
    'indian wild ass', 'mongolian wild ass', 'somali wild ass',
    'persian wild ass', 'tibetan wild ass', 'wild ass',
    'maine coon', 'coon hound', 'pistol shrimp', 'knife fish',
];
function scrub(s, allowedPhrases) {
    let scrubbed = s.normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase();
    for (const phrase of allowedPhrases) {
        if (phrase && scrubbed.includes(phrase))
            scrubbed = scrubbed.split(phrase).join(' ');
    }
    return scrubbed;
}
function words(scrubbed) {
    return scrubbed.replace(/[^\p{L}\p{N}]+/gu, ' ').trim().split(/\s+/).filter(Boolean);
}
function containsBlockedWord(s) {
    const scrubbed = scrub(s, ALLOWED_ANIMAL_PHRASES);
    const nameWords = words(scrubbed);
    if (nameWords.some(w => BLOCKED_WORDS.has(w)))
        return true;
    const joined = ` ${nameWords.join(' ')} `;
    if (BLOCKED_PHRASES.some(p => joined.includes(` ${p} `)))
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
// ── AI-written stories ────────────────────────────────────────────────────────
// Stories get their own check. The name list above is deliberately strict
// ("crack", "shooting", "mushrooms" are refused as NAMES), but those words are
// harmless in a story ("a crack of thunder", "shooting across the sky").
const STORY_OK_WORDS = new Set([
    'crack', 'shooting', 'mushrooms', 'shrooms', 'weed', 'ecstasy', 'assault', 'naked',
    'gun', 'guns', 'pistol', 'rifle', 'bomb', 'bombs', 'knife', 'knives', 'explosive', 'explosives',
    'shooter', 'nuke', 'nukes', 'grenade', 'grenades',
]);
const STORY_BASE_WORDS = new Set([...BLOCKED_WORDS].filter(w => !STORY_OK_WORDS.has(w)));
// Battle narration must show a contest, not injuries or death. Fun facts may
// mention real biology ("mosquitoes drink blood", "the dodo died out"), so
// this list applies to the narration and the "why" line only.
const INJURY_WORDS = new Set([
    'blood', 'bloody', 'bleed', 'bleeds', 'bleeding', 'gore', 'gores', 'gored', 'goring', 'gory',
    'kill', 'kills', 'killed', 'killing', 'dead', 'death', 'die', 'dies', 'died', 'dying',
    'slaughter', 'slaughters', 'stab', 'stabs', 'stabbed', 'maim', 'maims', 'maul', 'mauls',
    'mauled', 'mauling', 'shred', 'shreds', 'shredded', 'disembowel', 'decapitate', 'behead',
    'guts', 'entrails', 'corpse', 'carcass', 'wound', 'wounds', 'wounded', 'injure', 'injures',
    'injured', 'injury', 'lethal', 'deadly', 'fatal',
    'drown', 'drowns', 'drowned', 'drowning', 'suffocate', 'suffocates', 'suffocated', 'suffocating',
    'gasp', 'gasps', 'gasping', 'choke', 'chokes', 'choking', 'prey',
]);
// Fun facts may talk about real biology, but not about hurting anything.
const FACT_INJURY_WORDS = new Set(['kill', 'kills', 'killed', 'killing', 'gore', 'gory', 'maim', 'maul', 'mauls']);
const FACT_INJURY_PHRASES = [
    'snap bones', 'snaps bones', 'snapping bones', 'snap through bone', 'snap bone',
    'crush bones', 'crushes bones', 'crush bone', 'break bones', 'breaks bones', 'breaking bones',
    'death trap',
];
const INJURY_PHRASES = [
    'bone crushing', 'bone shattering', 'bone shearing', 'crushes bone', 'crushing bone',
    'rips apart', 'rip apart', 'tears apart', 'tear apart', 'rips into', 'tears into',
    'sinks its teeth into', 'sinking its teeth into',
    'out of air', 'lungs burn', 'lungs scream', 'floats helplessly', 'sinks helplessly', 'falls helplessly',
];
// "snap through the thickest bones", "teeth that can crush bone", "bone-shattering":
// any breaking verb within a few words of "bone(s)", in either order.
const BONE_BREAKING = new RegExp('\\b(snap|snaps|snapping|crush|crushes|crushing|break|breaks|breaking|shatter|shatters|shattering|crack|cracks|cracking|splinter|splinters)\\b(?: \\w+){0,3} bones?\\b'
    + '|\\bbones?(?: \\w+){0,2} (snap|snaps|snapping|crush|crushed|crushing|break|breaks|breaking|broke|broken|shatter|shatters|shattering|shattered|crack|cracks|cracking|cracked)\\b');
// Game mechanics must never reach kids ("tier-7 power", "a higher stat").
const JARGON_WORDS = new Set(['tier', 'tiers', 'stat', 'stats']);
const JARGON_PHRASES = ['power level', 'power rating', 'tier gap'];
// Every built-in fighter's name is always allowed inside a story.
const BUILT_IN_NAMES = creatures_1.CREATURES.map(c => c.name.toLowerCase());
/** Returns the first problem found in AI-written text, or null when it is fine.
 *  `fighterNames` (already sanitized) are exempt so "Death Adder" can appear. */
function storyProblem(value, part, fighterNames = []) {
    if (/<\/?[a-z][^>]*>/i.test(value))
        return 'markup';
    if (/https?:\/\/|www\./i.test(value))
        return 'link';
    const allowed = [
        ...ALLOWED_ANIMAL_PHRASES,
        'birds of prey', 'bird of prey',
        ...BUILT_IN_NAMES,
        ...fighterNames.map(n => n.trim().toLowerCase()).filter(Boolean),
    ].sort((a, b) => b.length - a.length);
    const scrubbed = scrub(value, allowed);
    const tokens = words(scrubbed);
    const base = tokens.find(w => STORY_BASE_WORDS.has(w));
    if (base)
        return `word:${base}`;
    const joined = ` ${tokens.join(' ')} `;
    const jargon = tokens.find(w => JARGON_WORDS.has(w)) ?? JARGON_PHRASES.find(p => joined.includes(` ${p} `));
    if (jargon)
        return `jargon:${jargon}`;
    const bones = joined.match(BONE_BREAKING);
    if (bones)
        return `phrase:${bones[0].trim()}`;
    if (part === 'narration') {
        const injury = tokens.find(w => INJURY_WORDS.has(w));
        if (injury)
            return `word:${injury}`;
        const phrase = INJURY_PHRASES.find(p => joined.includes(` ${p} `));
        if (phrase)
            return `phrase:${phrase}`;
    }
    else {
        const injury = tokens.find(w => FACT_INJURY_WORDS.has(w));
        if (injury)
            return `word:${injury}`;
        const phrase = [...INJURY_PHRASES, ...FACT_INJURY_PHRASES].find(p => joined.includes(` ${p} `));
        if (phrase)
            return `phrase:${phrase}`;
    }
    return null;
}
/**
 * Keeps an AI story when only some sentences break the rules: those sentences
 * are dropped, and the rest is kept if at least `minSentences` remain.
 * Returns null when the text can't be saved (the caller then regenerates).
 */
function repairStory(value, part, fighterNames, minSentences) {
    if (storyProblem(value, part, fighterNames) === null)
        return value;
    const sentences = value.match(/[^.!?]+[.!?]+["')\]]*\s*|[^.!?]+$/g)?.map(s => s.trim()).filter(Boolean) ?? [];
    const kept = sentences.filter(s => storyProblem(s, part, fighterNames) === null);
    if (kept.length === sentences.length || kept.length < minSentences)
        return null;
    return kept.join(' ');
}
/** Plain check for short AI text that isn't a battle story (e.g. a tier blurb). */
function isSafeGeneratedText(value) {
    return storyProblem(value, 'fact') === null;
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
