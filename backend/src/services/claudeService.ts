import Anthropic from '@anthropic-ai/sdk';
import { createMessage } from './anthropicClient';
import { repairStory, storyProblem } from '../middleware/sanitize';
import {
  displayName, envModifier, getCreature, isBuiltIn, isDeity, survivalWarning,
} from '../data/creatures';
import {
  FACT_RULES, SIGNATURE_MOVE_RULE, SOLO_RULE, TONE_RULES, WHY_RULES,
} from './storyRules';

// Deterministic battle resolver — picks the winner for clear-cut matchups so
// Claude is only asked to NARRATE, not to decide. See battleResolver.ts.
import { resolveBattle, verdictPromptLine, type Verdict } from './battleResolver';

// Every built-in fighter's name, habitat, tier and profile lives in the master
// list (data/creatures.json). Custom/user fighters get an estimated tier below.

/** Profile line for the prompt: tier + a kid-safe blurb for built-ins, the
 *  estimated tier for custom creatures. */
function getPowerProfile(id: string, name: string): string {
  const c = getCreature(id);
  if (c) {
    const tier = c.habitat === 'deity' ? 'TIER 10/10 (god)' : `TIER ${c.tier}/10`;
    return `${name} — ${tier} — ${c.blurb}. Verified fact: ${c.fact}`;
  }
  // Custom creature: use the estimated tier (populated by estimateCustomTier
  // before the prompt is built) so the narration is anchored to real scale.
  const est = customTierCache.get(name.trim().toLowerCase());
  if (est) {
    return `${name} — TIER ${est.tier}/10 (estimated) — ${est.blurb}`;
  }
  return `${name} — tier unknown (custom/user-defined creature) — judge from your own knowledge of this creature's real-world or fictional abilities`;
}

// ───────────────────────────────────────────────────────────────────────────
// Custom-creature tier estimation
// ───────────────────────────────────────────────────────────────────────────
// User-typed creatures have no tier profile, so the resolver used to defer the
// whole fight to the AI — which let a gram-scale "gravedigger beetle" beat a
// 45 kg wolf because it sounded mighty. We instead classify the custom creature
// into the SAME 1–10 tier scale (a cheap Haiku call, cached by name) and feed it
// into the deterministic resolver, so REAL physical scale decides the winner —
// consistent, realistic, educational. Falls back to the AI path on any failure.

const customTierCache = new Map<string, { tier: number; blurb: string }>();

const TIER_RUBRIC_SYSTEM =
  `You classify a creature into a POWER TIER from 1 to 10 for a kids' "who would win" game. ` +
  `The tier reflects REAL physical size, mass, and fighting ability in a 1-on-1 contest.\n\n` +
  `ABSOLUTE SCALE DOMINATES. Being "strong for its size" does NOT raise the tier — a beetle that ` +
  `lifts 50× its gram-scale body is still TIER 1, because a wolf outweighs it ten-thousand-fold.\n\n` +
  `Tier anchors:\n` +
  `1 = gram-scale invertebrate / insect / bug (ant, beetle, wasp, mantis, hornet), tiny pets (hamster, goldfish, canary) or famously defenseless (dodo)\n` +
  `2 = small (tarantula, scorpion, crow ~1kg, piranha, house cat, small dog, chicken)\n` +
  `3 = small-but-dangerous ~6–30kg (cobra, octopus, honey badger, medium dog, sheep, goat)\n` +
  `4 = medium ~15–250kg (wolf, cheetah, eagle, boar, large dog, donkey)\n` +
  `5 = large ~80–1200kg, not apex (komodo dragon, giraffe, horse, bull, swordfish)\n` +
  `6 = apex land predator / great ape ~180–500kg (lion, tiger, gorilla, saber-tooth, moose)\n` +
  `7 = heavy/armored megafauna ~360–2000kg (grizzly, crocodile, rhino, hippo, giant squid, griffin)\n` +
  `8 = giant ~1100–7000kg (elephant, great white shark, T-Rex, phoenix, chimera)\n` +
  `9 = colossal / apex legendary 5000kg+ (orca, megalodon, dragon, kraken, leviathan, hydra)\n` +
  `10 = god / deity with reality-bending power\n\n` +
  `Rules: judge a REAL animal by its typical adult size; a mythical/fictional one by its established lore size. ` +
  `Insects and bugs are TIER 1 no matter their reputation. A small real animal can NEVER be tier 5+. ` +
  `If the name is vague, estimate conservatively from the most likely real creature it names.\n` +
  `Output ONLY a JSON object: {"tier": <1-10 integer>, "blurb": "<=12 kid-friendly words: typical weight + standout ability>"}`;

export async function estimateCustomTier(
  name: string, signal?: AbortSignal,
): Promise<{ tier: number; blurb: string } | null> {
  const key = name.trim().toLowerCase();
  if (!key) return null;
  const cached = customTierCache.get(key);
  if (cached) return cached;
  try {
    const resp = await createMessage('tier', {
      max_tokens: 80,
      system: TIER_RUBRIC_SYSTEM,
      messages: [{ role: 'user', content: `Creature: "${name}"` }],
    }, signal);
    const block = resp.content.find((b) => b.type === 'text');
    const text = block && block.type === 'text' ? block.text : '';
    const m = text.match(/\{[\s\S]*\}/);
    if (!m) return null;
    const parsed = JSON.parse(m[0]) as { tier?: unknown; blurb?: unknown };
    let tier = Math.round(Number(parsed.tier));
    if (!Number.isFinite(tier)) return null;
    tier = Math.max(1, Math.min(10, tier));
    const rawBlurb = String(parsed.blurb ?? '').slice(0, 80);
    const blurb = storyProblem(rawBlurb, 'narration', [name]) === null ? rawBlurb : '';
    const result = { tier, blurb };
    if (customTierCache.size >= 1_000) {
      const oldest = customTierCache.keys().next().value as string | undefined;
      if (oldest) customTierCache.delete(oldest);
    }
    customTierCache.set(key, result);
    return result;
  } catch {
    return null; // never block a battle — fall back to the AI-judged path
  }
}

/** A fighter is custom when it isn't one of the app's built-in creatures. */
export function isCustomFighter(id: string): boolean {
  return !isBuiltIn(id);
}

/**
 * Estimate tiers for whichever fighters are custom (concurrently). Returns the
 * tier numbers to thread into resolveBattle; also primes customTierCache so
 * getPowerProfile shows the estimate in the prompt.
 */
async function estimateCustomTiers(
  fighter1Id: string, fighter1Name: string | undefined,
  fighter2Id: string, fighter2Name: string | undefined,
  signal?: AbortSignal,
): Promise<{ customTier1: number | null; customTier2: number | null }> {
  const [e1, e2] = await Promise.all([
    isCustomFighter(fighter1Id) ? estimateCustomTier(fighter1Name ?? fighter1Id, signal) : Promise.resolve(null),
    isCustomFighter(fighter2Id) ? estimateCustomTier(fighter2Name ?? fighter2Id, signal) : Promise.resolve(null),
  ]);
  return { customTier1: e1?.tier ?? null, customTier2: e2?.tier ?? null };
}

export interface BattleResult {
  winner: string;               // animal ID or "draw"
  narration: string;            // short battle story
  funFact: string;              // one true fun fact about the winner (or both if draw)
  winnerHealthPercent: number;  // 10–90
  loserHealthPercent: number;   // 0–89
  why?: string;                 // one short kid-friendly reason the winner won
}

const SYSTEM_PROMPT =
  'You are the storyteller for "Who Would Win?" — a fun, educational battle game for kids aged 6–12. ' +
  'Outcomes must be ACCURATE and REALISTIC, based on real biology, physics, and established lore. Accuracy is the core value of this app — kids are learning real facts about animals. Never give a surprising upset just to be interesting.\n\n' +

  'POWER TIERS (ground truth — never override these with guesses):\n' +
  '• Treat every tier number in FIGHTER PROFILES as fact about that creature\'s size and power.\n' +
  '• A 2-tier gap: the higher-tier creature wins the large majority of the time.\n' +
  '• A 3-tier gap: the higher-tier creature wins decisively — only an extreme arena mismatch changes this.\n' +
  '• A 4+ tier gap: the higher-tier creature wins almost certainly — the arena cannot overcome this.\n' +
  '• NEVER let a small creature (bug, small snake, small bird) beat a large apex animal unless it has an overwhelming special ability (like very strong venom) AND the large animal has no defense.\n\n' +

  'ARENA RULES (apply these strictly when an arena is given):\n' +
  '• SURVIVAL FIRST: a land animal in deep ocean cannot breathe, a fish on land is stranded, and a creature that cannot fly is helpless in the sky. These decide the fight.\n' +
  '• EFFECTIVENESS: a creature in its home environment is at full strength; outside it, it is much weaker.\n' +
  '• NO ARENA: judge purely on the creatures\' natural abilities. No terrain bonuses or penalties.\n\n' +

  'MYTHOLOGICAL/FANTASY: use their established legendary abilities from mythology and folklore. Gods beat all mortal creatures.\n\n' +

  'STORY: follow the tone rules in the request exactly — exciting and specific, but a contest, never an injury.\n\n' +

  'FORMAT: Respond with ONLY valid JSON matching the exact schema. No markdown, no text outside the JSON.';

const ENVIRONMENT_DESCRIPTIONS: Record<string, string> = {
  Grassland: 'open savanna with tall grass and a wide sky — neutral terrain with no water nearby',
  Ocean:     'deep open ocean, fully submerged underwater — there is NO land, no shore, only sea',
  Sky:       'high in the sky among the clouds — both fighters are airborne with no ground beneath them',
  Arctic:    'a frozen tundra of ice and snow — bitterly cold, slippery, no vegetation',
  Desert:    'a scorching hot desert with sand dunes and blazing sun — no water anywhere',
  Jungle:    'dense tropical rainforest with thick trees, vines, and undergrowth — tight quarters, plenty of cover',
  Volcano:   'the rocky rim of an erupting volcano surrounded by rivers of lava and falling ash — extreme heat',
  Night:     'a dark wilderness at night under a full moon — low visibility, shadows everywhere',
  Storm:     'a raging thunderstorm with lightning strikes, gale-force winds, and torrential rain',
};

/** Prompt tier for the gap note: built-in tier, 10 for gods, null for customs. */
function promptTier(id: string): number | null {
  const c = getCreature(id);
  return c ? c.tier : null;
}

export function buildUserPrompt(fighter1Id: string, fighter2Id: string, fighter1Name?: string, fighter2Name?: string, environmentName?: string, tournamentContext?: string, verdict?: Verdict): string {
  const name1 = displayName(fighter1Id, fighter1Name);
  const name2 = displayName(fighter2Id, fighter2Name);

  // 🔒 Deterministic verdict — when present, locks in the winner so Claude
  // only writes the narration. Forced verdicts are emitted at the very top so
  // they dominate every other instruction the model sees.
  const verdictLine = verdict ? verdictPromptLine(verdict, name1, name2, fighter1Id) : '';

  // Tournament context: prepended as a single line so the narrator builds drama
  // appropriate to the round (early rounds scrappier, finals epic). Optional.
  const tournamentLine = tournamentContext
    ? `TOURNAMENT CONTEXT: ${tournamentContext}\n\n`
    : '';

  const isDeity1 = isDeity(fighter1Id);
  const isDeity2 = isDeity(fighter2Id);

  const deityNote = (isDeity1 || isDeity2)
    ? `Note: ${[isDeity1 ? name1 : null, isDeity2 ? name2 : null].filter(Boolean).join(' and ')} ${isDeity1 && isDeity2 ? 'are legendary figures from Greek mythology with extraordinary divine powers.' : 'is a legendary figure from Greek mythology with extraordinary powers — use those mythological abilities in the story.'}\n\n`
    : '';

  const customNote1 = isCustomFighter(fighter1Id) && fighter1Name
    ? `Note: "${fighter1Name}" is a user-defined fighter — describe it from everything you know about it (biology, mythology, fiction, pop culture, etc.).\n`
    : '';
  const customNote2 = isCustomFighter(fighter2Id) && fighter2Name
    ? `Note: "${fighter2Name}" is a user-defined fighter — describe it from everything you know about it (biology, mythology, fiction, pop culture, etc.).\n`
    : '';

  const arenaDesc = environmentName && ENVIRONMENT_DESCRIPTIONS[environmentName]
    ? ENVIRONMENT_DESCRIPTIONS[environmentName]
    : null;
  const arenaLine = arenaDesc
    ? `ARENA: ${environmentName} — ${arenaDesc}.\n` +
      `CRITICAL RULES — apply these to EVERY creature including custom, mythical, and fictional ones:\n` +
      `(1) The entire fight stays here — neither fighter escapes to another environment.\n` +
      `(2) SURVIVAL: Can it physically survive here? A land animal in deep ocean cannot breathe. A fish in a desert is stranded. A creature that cannot fly is helpless in the sky. A creature that cannot survive loses unless it has a special ability.\n` +
      `(3) EFFECTIVENESS: Even if a creature can survive, does this arena hold it back? Judge each fighter in THIS arena — not in its home environment.\n` +
      `(4) HOME ADVANTAGE: A creature native to this environment fights at full strength. An outsider fights at a fraction of its normal ability.\n\n`
    : `There is NO arena environment for this battle. Judge each fighter purely on their natural strengths, biology, and abilities. Do NOT apply any terrain advantage or disadvantage — neither fighter has a home-environment bonus or penalty.\n` +
      `NARRATION WORDING (strict, because there is no arena): do NOT mention savanna, ocean, jungle, sky, land, water, or any terrain. Do NOT use habitat descriptors like "ocean giant" or "savanna king" — refer to fighters by NAME. Do NOT describe anyone as "out of its element", "stranded", "beached", or "in its home".\n\n`;

  const warn1 = environmentName ? survivalWarning(fighter1Id, name1, environmentName) : '';
  const warn2 = environmentName ? survivalWarning(fighter2Id, name2, environmentName) : '';

  // Tier profiles — ground truth on size and capability. Also emit an explicit
  // guidance line when the gap is wide, so the model doesn't hand a
  // kraken-vs-hawk matchup to the hawk just because it's in the sky.
  const profile1 = getPowerProfile(fighter1Id, name1);
  const profile2 = getPowerProfile(fighter2Id, name2);
  const tier1 = promptTier(fighter1Id);
  const tier2 = promptTier(fighter2Id);

  let tierGapLine = '';
  if (tier1 !== null && tier2 !== null && tier1 !== tier2) {
    const gap = Math.abs(tier1 - tier2);
    const strongerId = tier1 > tier2 ? fighter1Id : fighter2Id;
    const strongerName = tier1 > tier2 ? name1 : name2;
    // A tier-9 orca on grassland is helpless — tier gap must NOT override survival.
    if (environmentName && envModifier(strongerId, environmentName) <= 0.10) {
      tierGapLine = `TIER GAP NOTE: ${strongerName} is far more powerful on paper, BUT it cannot function in this arena (see SURVIVAL WARNING above). Survival overrides the tier gap.\n\n`;
    } else if (gap >= 4) {
      tierGapLine = `TIER GAP: ${gap} tiers. ${strongerName} is dramatically more powerful and wins decisively; terrain cannot overcome this gap.\n\n`;
    } else if (gap === 3) {
      tierGapLine = `TIER GAP: 3 tiers. ${strongerName} has a decisive size and power advantage.\n\n`;
    }
  }

  const profilesBlock =
    `FIGHTER PROFILES (use these as ground truth for size, weight, and ability — do NOT upgrade a small creature past its tier):\n` +
    `  • ${profile1}\n` +
    `  • ${profile2}\n\n` +
    tierGapLine;

  return (
    verdictLine +
    tournamentLine +
    `Two fighters are about to battle: ${name1} vs ${name2}.\n\n` +
    profilesBlock +
    deityNote +
    customNote1 +
    customNote2 +
    arenaLine +
    warn1 +
    warn2 +
    (warn1 || warn2 ? '\n' : '') +
    `Decide who would win in this arena. Use all relevant knowledge: real biology, ecology, mythology, legendary abilities, or fictional lore — whatever applies to these specific fighters. ` +
    `Respond with ONLY a JSON object:\n\n` +
    `{\n` +
    `  "winner": "<${fighter1Id} or ${fighter2Id} or \\"draw\\">",\n` +
    `  "narration": "<EXACTLY 3 sentences as described in the Narration rules below>",\n` +
    `  "funFact": "<a WHOA-DID-YOU-KNOW reveal — see Fun Fact rules>",\n` +
    `  "why": "<see Why rules below>",\n` +
    `  "winnerHealthPercent": <integer 10-90>,\n` +
    `  "loserHealthPercent": <integer 0-89, must be less than winnerHealthPercent>\n` +
    `}\n\n` +
    `Hard rules:\n` +
    `- "winner" must be exactly: "${fighter1Id}", "${fighter2Id}", or "draw"\n` +
    `- winnerHealthPercent: 10–90 (higher = more dominant win)\n` +
    `- loserHealthPercent: 0–89, always strictly less than winnerHealthPercent\n\n` +
    `Why rules — a single crisp takeaway a kid actually learns from:\n` +
    WHY_RULES + `\n` +
    `Narration rules — like a kids' action-movie trailer:\n` +
    `- EXACTLY 3 sentences, present tense, every sentence full of action. Do not exceed 3 sentences.\n` +
    `- Use punchy verbs (charges, slams, vaults, soars, crashes, pounces, dodges, zaps) and sensory moments (dust kicks up, the ground shakes, a roar echoes).\n` +
    `- Open with a dramatic moment, not a bland intro. End with a triumphant beat: "stands tall over the arena", "lifts its head as the crowd erupts".\n` +
    SIGNATURE_MOVE_RULE +
    SOLO_RULE +
    TONE_RULES + `\n` +
    `Fun-fact rules — a WHOA-DID-YOU-KNOW reveal kids will want to repeat:\n` +
    `- 1–2 sentences.\n` +
    FACT_RULES
  );
}

function stripMarkdownFences(text: string): string {
  // Remove ```json ... ``` or ``` ... ``` wrappers if present
  return text
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```\s*$/, '')
    .trim();
}

/** Thrown when a generated story breaks the kid-safety or format rules. The
 *  caller regenerates once; anything else (API errors) is not retried. */
export class StoryRejectedError extends Error {
  constructor(reason: string) {
    super(`story rejected: ${reason}`);
    this.name = 'StoryRejectedError';
  }
}

export function validateResult(data: unknown, fighter1Id: string, fighter2Id: string,
                               fighterNames: readonly string[] = [],
                               minNarrationSentences = 2): BattleResult {
  if (typeof data !== 'object' || data === null) {
    throw new StoryRejectedError('response is not an object');
  }

  const obj = data as Record<string, unknown>;

  const winner = obj['winner'];
  if (winner !== fighter1Id && winner !== fighter2Id && winner !== 'draw') {
    throw new StoryRejectedError('invalid winner value');
  }

  // Strip emoji BEFORE the non-empty check — an all-emoji field is non-empty raw
  // but would strip to "", and we must reject it (retry/fallback) rather than
  // ship a blank card.
  const narrationRaw = obj['narration'];
  if (typeof narrationRaw !== 'string') {
    throw new StoryRejectedError('narration missing');
  }
  const narrationText = stripEmoji(narrationRaw).slice(0, 1_200);
  if (narrationText.trim() === '') throw new StoryRejectedError('narration empty');
  const narration = repairStory(narrationText, 'narration', fighterNames, minNarrationSentences);
  if (narration === null) {
    throw new StoryRejectedError(`narration ${storyProblem(narrationText, 'narration', fighterNames)}`);
  }
  if (narration !== narrationText) logRepair('narration', narrationText, fighterNames);

  const funFactRaw = obj['funFact'];
  if (typeof funFactRaw !== 'string') {
    throw new StoryRejectedError('funFact missing');
  }
  const funFactText = stripEmoji(funFactRaw).slice(0, 500);
  if (funFactText.trim() === '') throw new StoryRejectedError('funFact empty');
  const funFact = repairStory(funFactText, 'fact', fighterNames, 1);
  if (funFact === null) {
    throw new StoryRejectedError(`funFact ${storyProblem(funFactText, 'fact', fighterNames)}`);
  }
  if (funFact !== funFactText) logRepair('funFact', funFactText, fighterNames);

  const rawWinner = Number(obj['winnerHealthPercent']);
  if (isNaN(rawWinner)) {
    throw new StoryRejectedError('winnerHealthPercent is not a number');
  }
  const winnerHealthPercent = Math.min(90, Math.max(10, Math.round(rawWinner)));

  const rawLoser = Number(obj['loserHealthPercent']);
  if (isNaN(rawLoser)) {
    throw new StoryRejectedError('loserHealthPercent is not a number');
  }
  // Clamp loser, then ensure it's strictly less than winner for non-draws
  let loserHealthPercent = Math.min(89, Math.max(0, Math.round(rawLoser)));
  if (winner !== 'draw' && loserHealthPercent >= winnerHealthPercent) {
    loserHealthPercent = Math.max(0, winnerHealthPercent - 1);
  }

  // Optional: the one-line "why". Missing/blank/unsafe → undefined (iOS falls
  // back to its local reason). Cap length so a runaway sentence can't bloat the card.
  const rawWhy = obj['why'];
  const whyStripped = typeof rawWhy === 'string' ? stripEmoji(rawWhy) : '';
  const why = whyStripped !== '' && storyProblem(whyStripped, 'narration', fighterNames) === null
    ? whyStripped.slice(0, 160) : undefined;

  return {
    winner: winner as string,
    narration,   // already emoji-stripped + validated
    funFact,     // already emoji-stripped + validated
    winnerHealthPercent,
    loserHealthPercent,
    why,
  };
}

function logRepair(field: string, original: string, fighterNames: readonly string[]): void {
  const part = field === 'narration' ? 'narration' : 'fact';
  console.warn(JSON.stringify({
    event: 'story_repaired', field, reason: storyProblem(original, part, fighterNames),
  }));
}

/// Removes emoji / pictographic symbols from AI copy. The narration model
/// sometimes sprinkles in emoji that render as empty placeholder boxes (tofu) in
/// the app's custom fonts — strip them so all user-facing text is plain words.
/// Letters, digits, and normal punctuation are preserved.
export function stripEmoji(s: string): string {
  return s
    // Keycap sequences (1️⃣) first: base char + optional FE0F + 20E3 — drop whole.
    .replace(/[0-9#*]\u{FE0F}?\u{20E3}/gu, '')
    .replace(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{1F1E6}-\u{1F1FF}\u{FE00}-\u{FE0F}\u{200D}\u{20E3}]/gu, '')
    .replace(/\p{Extended_Pictographic}/gu, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

/**
 * Parse + validate a model reply, regenerating ONCE when the story breaks the
 * rules (unsafe word, bad JSON, missing field). API/budget errors are never
 * retried — the app's local result covers those.
 */
export async function generateValidated<T>(
  label: string,
  generate: (retryNote?: string) => Promise<string>,
  parse: (text: string) => T,
): Promise<T> {
  let retryNote: string | undefined;
  for (let attempt = 1; ; attempt++) {
    const text = await generate(retryNote);
    try {
      return parse(text);
    } catch (error) {
      const retryable = error instanceof StoryRejectedError || error instanceof SyntaxError;
      const reason = (error as Error).message.slice(0, 120);
      console.warn(JSON.stringify({ event: 'story_rejected', label, attempt, reason }));
      if (!retryable || attempt >= 2) throw error;
      // Tell the model exactly what went wrong — far more effective than
      // simply asking again.
      retryNote = `\n\nIMPORTANT: a previous draft was rejected (${reason.replace(/^story rejected: /, '')}). ` +
        `Write a completely new answer that follows every tone rule and returns valid JSON.`;
    }
  }
}

/**
 * Builds a partial assistant prefill that commits Claude to the arena ruling
 * before it generates JSON. Claude must continue from this voice — it cannot
 * contradict what it has already "said".
 */
function buildArenaPrefill(
  fighter1Id: string, fighter2Id: string,
  name1: string, name2: string,
  environmentName: string
): string {
  const clean = (s: string) => s.replace(/^(SURVIVAL WARNING|NOTE): /, '').trim();
  const warn1 = clean(survivalWarning(fighter1Id, name1, environmentName));
  const warn2 = clean(survivalWarning(fighter2Id, name2, environmentName));

  let prefill = `Arena: ${environmentName}. Survival & effectiveness check:\n`;
  prefill += warn1 ? `- ${name1}: ${warn1}\n` : `- ${name1}: can function in this arena.\n`;
  prefill += warn2 ? `- ${name2}: ${warn2}\n` : `- ${name2}: can function in this arena.\n`;
  prefill += `Based on the arena conditions above, my ruling is:\n{`;
  return prefill;
}

async function callClaude(
  fighter1Id: string,
  fighter2Id: string,
  topP: number,
  fighter1Name?: string,
  fighter2Name?: string,
  environmentName?: string,
  tournamentContext?: string,
  signal?: AbortSignal,
): Promise<BattleResult> {
  const name1 = displayName(fighter1Id, fighter1Name);
  const name2 = displayName(fighter2Id, fighter2Name);

  // 🔒 Step 1: Resolve the battle deterministically. For custom creatures we
  // first estimate a real-scale tier so even user-typed fighters get a
  // realistic, forced outcome (no gram-scale beetle beating a wolf). If the
  // resolver returns a "forced" verdict, we inject it into the prompt AND
  // validate the response afterwards — Claude can't override.
  const { customTier1, customTier2 } = await estimateCustomTiers(
    fighter1Id, fighter1Name, fighter2Id, fighter2Name, signal);
  const verdict = resolveBattle({
    fighter1Id, fighter2Id,
    fighter1Name, fighter2Name,
    environmentName,
    customTier1, customTier2,
  });

  // Prefill: force Claude to commit to the arena assessment before writing JSON.
  // Claude cannot contradict its own prior turn, so this locks in the arena ruling.
  const prefill = environmentName
    ? buildArenaPrefill(fighter1Id, fighter2Id, name1, name2, environmentName)
    : null;

  const userPrompt = buildUserPrompt(fighter1Id, fighter2Id, fighter1Name, fighter2Name, environmentName, tournamentContext, verdict);

  const result = await generateValidated('battle', async (retryNote) => {
    const messages: Anthropic.MessageParam[] = [
      { role: 'user', content: userPrompt + (retryNote ?? '') },
    ];
    if (prefill) {
      messages.push({ role: 'assistant', content: prefill });
    }
    const response = await createMessage('battle', {
      max_tokens: 450,
      top_p: topP,
      system: SYSTEM_PROMPT,
      messages,
    }, signal);
    const block = response.content[0];
    if (!block || block.type !== 'text') {
      throw new Error('Unexpected response format from Claude');
    }
    // The prefill ends with '{' — prepend it so the response is valid JSON.
    return prefill ? '{' + block.text : block.text;
  }, text => validateResult(JSON.parse(stripMarkdownFences(text)) as unknown,
    fighter1Id, fighter2Id, [name1, name2]));

  // 🔒 Step 2: enforce the verdict. If Claude defied a forced verdict, override
  // the winner field and rewrite a sensible narration explaining why. The fun
  // fact and health percents are preserved from Claude's response.
  return enforceVerdict(result, verdict, name1, name2, fighter1Id);
}

/**
 * Compare Claude's chosen winner against the resolver's forced verdict. If
 * they disagree, override and write a fallback narration. This is the LAST
 * line of defense — should rarely fire because the prompt already tells the
 * model the verdict is final.
 */
function enforceVerdict(
  result: BattleResult,
  verdict: Verdict,
  name1: string,
  name2: string,
  fighter1Id: string,
): BattleResult {
  if (verdict.kind !== 'forced') return result;
  if (result.winner === verdict.winnerId) return result;

  const winnerName = verdict.winnerId === fighter1Id ? name1 : name2;
  const loserName  = verdict.winnerId === fighter1Id ? name2 : name1;

  console.warn(JSON.stringify({
    event: 'verdict_override',
    fighter1Type: isCustomFighter(verdict.winnerId) ? 'custom' : 'built-in',
    fighter2Type: isCustomFighter(verdict.loserId) ? 'custom' : 'built-in',
  }));

  return {
    winner: verdict.winnerId,
    // Terrain-neutral and name-safe on purpose: this override can fire in ANY
    // arena (or none), and the names may be people or objects a kid typed.
    narration: `${winnerName} takes charge from the very first moment and never lets ${loserName} settle in. ` +
      `One last burst of power and speed seals it, and ${winnerName} wins as the crowd erupts!`,
    funFact: result.funFact, // keep Claude's fun fact — usually still accurate
    winnerHealthPercent: Math.max(70, result.winnerHealthPercent),
    loserHealthPercent: Math.min(25, result.loserHealthPercent),
    // `why` omitted: Claude's would argue for the wrong winner; iOS recomputes.
  };
}

// ── Quick Battle ─────────────────────────────────────────────────────────────
// Lightweight prompt: same resolver, shorter story. Used by tournaments and
// the 1v1 Quick Fight.

export function buildQuickUserPrompt(
  fighter1Id: string, fighter2Id: string,
  fighter1Name?: string, fighter2Name?: string,
  environmentName?: string,
  verdict?: Verdict,
): string {
  const name1 = displayName(fighter1Id, fighter1Name);
  const name2 = displayName(fighter2Id, fighter2Name);

  // 🔒 Forced verdict line — if present, locks in the winner.
  const verdictLine = verdict ? verdictPromptLine(verdict, name1, name2, fighter1Id) : '';

  const profile1 = getPowerProfile(fighter1Id, name1);
  const profile2 = getPowerProfile(fighter2Id, name2);
  const tier1 = promptTier(fighter1Id);
  const tier2 = promptTier(fighter2Id);

  let tierGapLine = '';
  if (tier1 !== null && tier2 !== null) {
    const gap = Math.abs(tier1 - tier2);
    if (gap >= 3) {
      const stronger = tier1 > tier2 ? name1 : name2;
      tierGapLine = `TIER GAP: ${gap} — ${stronger} is dramatically more powerful and should win.\n\n`;
    }
  }

  const customNote1 = isCustomFighter(fighter1Id) && fighter1Name
    ? `Note: "${fighter1Name}" is a user-defined fighter — judge from your own knowledge of it.\n`
    : '';
  const customNote2 = isCustomFighter(fighter2Id) && fighter2Name
    ? `Note: "${fighter2Name}" is a user-defined fighter — judge from your own knowledge of it.\n`
    : '';

  const arenaDesc = environmentName && ENVIRONMENT_DESCRIPTIONS[environmentName]
    ? `ARENA: ${environmentName} — ${ENVIRONMENT_DESCRIPTIONS[environmentName]}.\n`
    : `NO ARENA — fight in a featureless neutral void. STRICT RULES:\n` +
      `  • Do NOT mention savanna, ocean, jungle, sky, land, water, or any terrain.\n` +
      `  • Do NOT use habitat descriptors like "ocean giant" or "savanna king" — refer to fighters by NAME.\n` +
      `  • Do NOT treat anyone as "out of their element", "stranded", "beached", or "in its home".\n` +
      `  • No environmental bonus or penalty for either side. Judge purely on biology, size, abilities.\n`;
  const warn1 = environmentName ? survivalWarning(fighter1Id, name1, environmentName) : '';
  const warn2 = environmentName ? survivalWarning(fighter2Id, name2, environmentName) : '';

  const survivalBlock = (warn1 || warn2)
    ? `SURVIVAL RULES — these override everything else:\n` + warn1 + warn2 +
      `A creature that cannot survive the arena LOSES.\n\n`
    : '';

  return (
    verdictLine +
    `Quick battle: ${name1} vs ${name2}.\n\n` +
    `FIGHTER PROFILES (ground truth — do not override with guesses):\n  • ${profile1}\n  • ${profile2}\n\n` +
    tierGapLine +
    customNote1 +
    customNote2 +
    arenaDesc +
    survivalBlock +
    `Pick the accurate winner based on biology, power tier, and arena. Respond with ONLY valid JSON — no markdown:\n` +
    `{"winner":"<${fighter1Id} or ${fighter2Id}>","narration":"<see Narration rules>","funFact":"<see Fun-Fact rules>","why":"<see Why rules>","winnerHealthPercent":<10-90>,"loserHealthPercent":<0-40>}\n\n` +
    `Why rules:\n` + WHY_RULES + `\n` +
    `Narration rules — like a kids' action-movie trailer:\n` +
    `- EXACTLY 2 punchy sentences in present tense. Do not exceed 2 sentences.\n` +
    `- Use punchy verbs (charges, slams, soars, crashes, pounces, dodges, zaps) and sensory moments (dust kicks up, the ground shakes, a roar echoes).\n` +
    `- End with a triumphant beat ("stands tall over the arena", "lifts its head as the crowd erupts").\n` +
    SIGNATURE_MOVE_RULE +
    SOLO_RULE +
    TONE_RULES + `\n` +
    `Fun-fact rules:\n- 1 sentence.\n` +
    FACT_RULES
  );
}

const QUICK_SYSTEM_PROMPT =
  'You are the storyteller for "Who Would Win?" — an educational battle game for kids aged 6–12. ' +
  'ACCURACY IS EVERYTHING: give the result that would realistically happen. Never give a surprising upset just to be interesting.\n' +
  'POWER TIERS: treat tier numbers as ground truth. A 3-tier gap is decisive. A 4+ tier gap is essentially certain — the arena cannot overcome it.\n' +
  'ARENA SURVIVAL: a creature that cannot survive the arena loses — a land animal in deep ocean cannot breathe, a fish on land is stranded, a creature that cannot fly is helpless in the sky.\n' +
  'REAL BIOLOGY: base results on verified size, abilities, and biology — not random chance.\n' +
  'Never return a draw — always pick the realistic winner.\n' +
  'Follow the tone rules in the request exactly. Always respond with ONLY valid JSON. No markdown, no explanation outside the JSON.';

export async function getQuickBattleResult(
  fighter1Id: string,
  fighter2Id: string,
  fighter1Name?: string,
  fighter2Name?: string,
  environmentName?: string,
  signal?: AbortSignal,
): Promise<BattleResult> {
  // 🔒 Resolve deterministically first (estimating a real-scale tier for any
  // custom creature so it can't win on vibes); verdict is appended to the
  // prompt and enforced after the response.
  const { customTier1, customTier2 } = await estimateCustomTiers(
    fighter1Id, fighter1Name, fighter2Id, fighter2Name, signal);
  const verdict = resolveBattle({
    fighter1Id, fighter2Id,
    fighter1Name, fighter2Name,
    environmentName,
    customTier1, customTier2,
  });
  const name1 = displayName(fighter1Id, fighter1Name);
  const name2 = displayName(fighter2Id, fighter2Name);

  const quickPrompt = buildQuickUserPrompt(fighter1Id, fighter2Id, fighter1Name, fighter2Name, environmentName, verdict);
  let result = await generateValidated('quick', async (retryNote) => {
    const response = await createMessage('quick', {
      max_tokens: 360,
      top_p: 0.85,
      system: QUICK_SYSTEM_PROMPT,
      messages: [{ role: 'user', content: quickPrompt + (retryNote ?? '') }],
    }, signal);
    const block = response.content[0];
    if (!block || block.type !== 'text') {
      throw new Error('Unexpected response format from Claude (quick)');
    }
    return block.text;
  }, text => validateResult(JSON.parse(stripMarkdownFences(text)) as unknown,
    fighter1Id, fighter2Id, [name1, name2], 1));

  // Quick battles must always have a winner. A draw can only come from an
  // open verdict (a custom fighter without an estimate); break it by id so a
  // rematch gives the same answer.
  if (result.winner === 'draw') {
    const winnerId = fighter1Id < fighter2Id ? fighter1Id : fighter2Id;
    result = {
      ...result,
      winner: winnerId,
      winnerHealthPercent: Math.max(result.winnerHealthPercent, 55),
      loserHealthPercent: Math.min(result.loserHealthPercent, 35),
    };
  }

  // 🔒 Enforce the deterministic verdict — if Claude defied a forced ruling
  // (e.g. picked the bullet ant over the harpy eagle), override the winner.
  return enforceVerdict(result, verdict, name1, name2, fighter1Id);
}

export async function getBattleResult(
  fighter1Id: string,
  fighter2Id: string,
  fighter1Name?: string,
  fighter2Name?: string,
  environmentName?: string,
  tournamentContext?: string,
  signal?: AbortSignal,
): Promise<BattleResult> {
  // One generation, plus one regeneration only when the story breaks the
  // rules. The SDK is configured with maxRetries=0; API failures fall back to
  // the app's local result instead of multiplying spend.
  return callClaude(fighter1Id, fighter2Id, 0.85, fighter1Name, fighter2Name,
    environmentName, tournamentContext, signal);
}

