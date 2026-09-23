/**
 * Shared writing rules for every AI battle story (1v1 full, quick, melee).
 *
 * One place so the three prompts can't drift apart. The tone is a cartoon
 * action scene: exciting, specific and true to real biology — but a contest,
 * never an injury. `storyProblem` in middleware/sanitize.ts backstops the
 * banned words listed here.
 */

export const TONE_RULES =
  `Tone — an exciting cartoon action scene for kids aged 6–12 (nature documentary meets Saturday-morning cartoon):\n` +
  `- Show the contest through movement and real abilities: charging, dodging, leaping, shoving, pinning, tackling, out-running, out-swimming, out-smarting, zapping, knocking off balance.\n` +
  `- You may name real weapons (jaws, horns, claws, tusks, venom, stinger, electric shock, fire breath) but NEVER describe an injury: nothing bleeds, breaks, tears or gets crushed, and nothing is bitten, clawed or struck INTO a body part (no necks, throats, flanks or gills).\n` +
  `- Never use these words: blood, gore, kill, dead, death, die, drown, suffocate, gasp, choke, fatal, wound, injure, maul, shred, lethal, deadly, devastating, crushing, "rips apart", "tears apart", "bone-crushing", "bone-shattering".\n` +
  `- If the arena decides it, the out-of-place fighter is never in danger: it simply can't keep up, then paddles back to shore, drifts down to a soft landing, or wriggles back to the water. Never describe running out of air, sinking, falling, drowning or being helpless.\n` +
  `- The fighters are opponents, not food: never call either one "prey" or talk about eating it.\n` +
  `- The loser is beaten, not hurt: it gets pinned, knocked over, out-lasted or out-smarted, then backs away, swims off or gives up. End on the winner's triumphant moment.\n` +
  `- Refer to fighters exactly by the names given (e.g. "Great Dane"). Never write an id with underscores.\n` +
  `- FORBIDDEN bland phrases: "ultimately won", "proved too much", "fought bravely", "stood victorious", "couldn't keep up", "no match for".\n` +
  `- FORBIDDEN game jargon: never mention "tier", "stat", "rating", "power level" or numbered size classes — describe size with imagery ("massive frame", "thunderous mass").\n`;

export const SOLO_RULE =
  `- ONE-ON-ONE: each side is a single fighter with no help. Never mention packs, pods, herds, prides, swarms, family members or allies helping either fighter.\n`;

export const SIGNATURE_MOVE_RULE =
  `- Name AT LEAST ONE specific signature move or ability, e.g. "a thunderous 5-ton hip-check", "a lightning-fast swooping dive", "a famous 600-volt zap", "a horn-first charge".\n`;

export const FACT_RULES =
  `- It must be TRUE: real-world biology for real animals, the established legend for mythical ones. Prefer the "verified fact" given in the fighter profiles; otherwise only use well-known facts you are sure of. No invented numbers.\n` +
  `- Keep it friendly: no details about hurting, killing or breaking bones.\n` +
  `- About the winner (or both fighters) — a surprising real detail a kid would want to repeat, ideally tied to why the winner won.\n` +
  `- Speak like a kid is reading it. No jargon like "tier" or "stat".\n`;

export const WHY_RULES =
  `- ONE short sentence (max ~14 words) naming the SPECIFIC real thing that decided it: size, speed, armor, venom, a special ability, or the arena. e.g. "A wolf is thousands of times heavier than a tiny beetle." or "Medusa's stone-turning stare ends the fight in a blink."\n` +
  `- Concrete and accurate — never generic ("bigger and stronger", "too powerful"). Kid-friendly, no jargon, not a repeat of the narration.\n`;
