import Anthropic from '@anthropic-ai/sdk';
import dotenv from 'dotenv';
dotenv.config({ override: true }); // override: true needed because Claude Code pre-sets ANTHROPIC_API_KEY to ""

// IDs that represent immortal gods/deities — they always dominate mortals
const DEITY_IDS = new Set<string>([
  'zeus', 'poseidon', 'hades', 'ares', 'athena', 'apollo',
  'artemis', 'hermes', 'hephaestus', 'hercules', 'medusa', 'kronos',
]);

// Mapping of animal IDs to human-readable display names
const ANIMAL_NAMES: Record<string, string> = {
  lion: 'Lion',
  tiger: 'Tiger',
  grizzly_bear: 'Grizzly Bear',
  wolf: 'Wolf',
  elephant: 'Elephant',
  rhinoceros: 'Rhinoceros',
  hippopotamus: 'Hippopotamus',
  gorilla: 'Gorilla',
  cheetah: 'Cheetah',
  crocodile: 'Crocodile',
  komodo_dragon: 'Komodo Dragon',
  wolverine: 'Wolverine',
  honey_badger: 'Honey Badger',
  giraffe: 'Giraffe',
  zebra: 'Zebra',
  moose: 'Moose',
  boar: 'Boar',
  tarantula: 'Tarantula',
  scorpion: 'Scorpion',
  cobra: 'Cobra',
  great_white_shark: 'Great White Shark',
  orca: 'Orca',
  giant_squid: 'Giant Squid',
  piranha: 'Piranha',
  octopus: 'Octopus',
  barracuda: 'Barracuda',
  electric_eel: 'Electric Eel',
  hammerhead_shark: 'Hammerhead Shark',
  mantis_shrimp: 'Mantis Shrimp',
  blue_ringed_octopus: 'Blue-Ringed Octopus',
  swordfish: 'Swordfish',
  coelacanth: 'Coelacanth',
  bald_eagle: 'Bald Eagle',
  peregrine_falcon: 'Peregrine Falcon',
  harpy_eagle: 'Harpy Eagle',
  barn_owl: 'Barn Owl',
  pterodactyl: 'Pterodactyl',
  hornet: 'Hornet',
  dragonfly: 'Dragonfly',
  albatross: 'Albatross',
  pelican: 'Pelican',
  crow: 'Crow',
  army_ant: 'Army Ant',
  bombardier_beetle: 'Bombardier Beetle',
  bullet_ant: 'Bullet Ant',
  praying_mantis: 'Praying Mantis',
  fire_ant: 'Fire Ant',
  centipede: 'Centipede',
  wasp: 'Wasp',
  stag_beetle: 'Stag Beetle',
  // Prehistoric
  t_rex: 'T-Rex', triceratops: 'Triceratops', velociraptor: 'Velociraptor',
  spinosaurus: 'Spinosaurus', megalodon: 'Megalodon', woolly_mammoth: 'Woolly Mammoth',
  saber_tooth_tiger: 'Saber-Tooth Tiger', ankylosaurus: 'Ankylosaurus',
  pteranodon: 'Pteranodon', dire_wolf: 'Dire Wolf', therizinosaurus: 'Therizinosaurus',
  dodo: 'Dodo',
  // Mythic
  thunderbird: 'Thunderbird', manticore: 'Manticore', sphinx: 'Sphinx',
  chimera: 'Chimera', wyvern: 'Wyvern', kirin: 'Kirin', roc: 'Roc',
  jackalope: 'Jackalope', baku: 'Baku', nue: 'Nue', ammit: 'Ammit', peryton: 'Peryton',
  // Mount Olympus
  zeus:       'Zeus',
  poseidon:   'Poseidon',
  hades:      'Hades',
  ares:       'Ares',
  athena:     'Athena',
  apollo:     'Apollo',
  artemis:    'Artemis',
  hermes:     'Hermes',
  hephaestus: 'Hephaestus',
  hercules:   'Hercules',
  medusa:     'Medusa',
  kronos:     'Kronos',
};

export interface BattleResult {
  winner: string;               // animal ID or "draw"
  narration: string;            // 2-sentence battle description
  funFact: string;              // one fun fact about the winner (or both if draw)
  winnerHealthPercent: number;  // 10–90
  loserHealthPercent: number;   // 0–25
}

const SYSTEM_PROMPT =
  'You are the referee for "Who Would Win?" — a fun educational game for kids. ' +
  'THE ARENA IS THE MOST IMPORTANT FACTOR. An animal fighting outside its element is massively disadvantaged — a land animal in deep ocean cannot breathe and will drown; a sea creature in a desert cannot move; a ground animal in the sky cannot fly. Always let the arena dictate survival first, then decide the winner based on biology. ' +
  'For real animals, base decisions on biology: size, natural weapons, speed, venom, armor, hunting behavior — all adjusted for the arena conditions. ' +
  'For mythological and fantasy creatures, use their established legendary abilities from mythology and folklore. ' +
  'For figures from Greek mythology like Zeus, Poseidon, Hades, Ares, Athena, Apollo, Artemis, Hermes, Hephaestus, Kronos (Olympian gods), Hercules, and Medusa — these are legendary mythological figures with extraordinary powers; they should win convincingly against any ordinary animal or creature based on their mythological abilities. Two mythological gods fighting each other can result in a win for either side or a draw. ' +
  'Keep narration exciting and appropriate for children — like a myth retelling, not a graphic fight. ' +
  'Always respond with ONLY valid JSON matching the exact schema. No markdown, no explanation outside the JSON.';

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

// Animals that are native to each element — used for survival warnings
const SEA_ANIMALS = new Set([
  'great_white_shark','orca','giant_squid','piranha','octopus','barracuda',
  'electric_eel','hammerhead_shark','mantis_shrimp','blue_ringed_octopus',
  'swordfish','coelacanth','megalodon','kraken','leviathan',
]);
const AIR_ANIMALS = new Set([
  'bald_eagle','peregrine_falcon','harpy_eagle','barn_owl','pterodactyl',
  'hornet','dragonfly','albatross','pelican','crow','thunderbird','roc','pteranodon',
]);
const LAND_ANIMALS = new Set(
  Object.keys(ANIMAL_NAMES).filter(id => !SEA_ANIMALS.has(id) && !AIR_ANIMALS.has(id))
);

function getSurvivalWarning(id: string, name: string, environmentName: string): string {
  const isSea  = SEA_ANIMALS.has(id);
  const isAir  = AIR_ANIMALS.has(id);
  const isLand = LAND_ANIMALS.has(id);

  if (environmentName === 'Ocean') {
    if (isLand) return `⚠️ SURVIVAL WARNING: ${name} is a land animal — it cannot breathe underwater and will drown in minutes. It is at an extreme, near-certain disadvantage in this arena.\n`;
    if (isAir)  return `⚠️ SURVIVAL WARNING: ${name} is an air animal — it cannot breathe underwater and will drown in minutes. It is at an extreme disadvantage in this arena.\n`;
  }
  if (environmentName === 'Sky') {
    if (isLand && !['dragon','griffin','wyvern','phoenix','thunderbird','roc'].includes(id))
      return `⚠️ SURVIVAL WARNING: ${name} cannot fly — it will fall and is helpless in this airborne arena.\n`;
    if (isSea)  return `⚠️ SURVIVAL WARNING: ${name} is an aquatic animal — it cannot fly and is helpless in a sky arena.\n`;
  }
  if (environmentName === 'Desert') {
    if (isSea)  return `⚠️ SURVIVAL WARNING: ${name} is an aquatic animal — it cannot survive out of water in a desert and will quickly die from dehydration.\n`;
  }
  if (environmentName === 'Arctic') {
    if (isSea && !['orca','great_white_shark','hammerhead_shark','megalodon'].includes(id))
      return `⚠️ NOTE: ${name} is a warm-water sea animal and will struggle in freezing arctic conditions.\n`;
  }
  return '';
}

function buildUserPrompt(fighter1Id: string, fighter2Id: string, fighter1Name?: string, fighter2Name?: string, environmentName?: string): string {
  const name1 = fighter1Name ?? ANIMAL_NAMES[fighter1Id] ?? fighter1Id;
  const name2 = fighter2Name ?? ANIMAL_NAMES[fighter2Id] ?? fighter2Id;

  const isDeity1 = DEITY_IDS.has(fighter1Id);
  const isDeity2 = DEITY_IDS.has(fighter2Id);

  const deityNote = (isDeity1 || isDeity2)
    ? `Note: ${[isDeity1 ? name1 : null, isDeity2 ? name2 : null].filter(Boolean).join(' and ')} ${isDeity1 && isDeity2 ? 'are legendary figures from Greek mythology with extraordinary divine powers. This is an epic clash; either could win.' : 'is a legendary figure from Greek mythology with extraordinary powers — use those mythological abilities when deciding the outcome.'}\n\n`
    : '';

  const customNote1 = !DEITY_IDS.has(fighter1Id) && !(fighter1Id in ANIMAL_NAMES) && fighter1Name
    ? `Note: "${fighter1Name}" is a user-defined fighter — assess its power based on everything you know about it (biology, mythology, fiction, pop culture, etc.).\n`
    : '';
  const customNote2 = !DEITY_IDS.has(fighter2Id) && !(fighter2Id in ANIMAL_NAMES) && fighter2Name
    ? `Note: "${fighter2Name}" is a user-defined fighter — assess its power based on everything you know about it (biology, mythology, fiction, pop culture, etc.).\n`
    : '';

  const arenaDesc = environmentName && ENVIRONMENT_DESCRIPTIONS[environmentName]
    ? ENVIRONMENT_DESCRIPTIONS[environmentName]
    : null;
  const arenaLine = arenaDesc
    ? `ARENA: ${environmentName} — ${arenaDesc}.\n` +
      `CRITICAL RULES — apply these to EVERY creature including custom, mythical, and fictional ones:\n` +
      `(1) The entire fight stays here — neither fighter escapes to another environment.\n` +
      `(2) SURVIVAL: Can it physically survive here? A land animal in deep ocean drowns. A sea fish in a desert suffocates. A non-flying creature in the sky falls. A cold-blooded insect in arctic freezes. A creature that cannot survive loses automatically unless it has a special ability.\n` +
      `(3) EFFECTIVENESS: Even if a creature can survive, does this arena cripple it? A lion can swim briefly but is nearly useless in deep ocean vs a sea creature. A shark on land can thrash but has no mobility. A jungle creature loses its agility advantage in an open desert. A desert creature overheats on a volcano. Score each fighter's combat effectiveness in THIS arena — not in their home environment.\n` +
      `(4) HOME ADVANTAGE: A creature native to this environment fights at full strength. An outsider fights at a fraction of its normal ability. Weight this heavily — it often decides the outcome.\n\n`
    : `The battle takes place in a neutral grassland — consider each fighter's natural strengths equally.\n\n`;

  const warn1 = environmentName ? getSurvivalWarning(fighter1Id, name1, environmentName) : '';
  const warn2 = environmentName ? getSurvivalWarning(fighter2Id, name2, environmentName) : '';

  return (
    `Two fighters are about to battle: ${name1} vs ${name2}.\n\n` +
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
    `  "narration": "<2-3 sentences describing the battle outcome — exciting but kid-friendly>",\n` +
    `  "funFact": "<one fascinating fact about the winner's most impressive ability or trait, or about both if draw>",\n` +
    `  "winnerHealthPercent": <integer 10-90>,\n` +
    `  "loserHealthPercent": <integer 0-89, must be less than winnerHealthPercent>\n` +
    `}\n\n` +
    `Rules:\n` +
    `- "winner" must be exactly: "${fighter1Id}", "${fighter2Id}", or "draw"\n` +
    `- winnerHealthPercent: 10–90 (higher = more dominant win)\n` +
    `- loserHealthPercent: 0–89, always strictly less than winnerHealthPercent\n` +
    `- Narration: exciting and appropriate for children\n` +
    `- Fun fact: accurate and interesting`
  );
}

function stripMarkdownFences(text: string): string {
  // Remove ```json ... ``` or ``` ... ``` wrappers if present
  return text
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```\s*$/, '')
    .trim();
}

function validateResult(data: unknown, fighter1Id: string, fighter2Id: string): BattleResult {
  if (typeof data !== 'object' || data === null) {
    throw new Error('Response is not an object');
  }

  const obj = data as Record<string, unknown>;

  const winner = obj['winner'];
  if (winner !== fighter1Id && winner !== fighter2Id && winner !== 'draw') {
    throw new Error(`Invalid winner value: "${winner}"`);
  }

  const narration = obj['narration'];
  if (typeof narration !== 'string' || narration.trim() === '') {
    throw new Error('narration must be a non-empty string');
  }

  const funFact = obj['funFact'];
  if (typeof funFact !== 'string' || funFact.trim() === '') {
    throw new Error('funFact must be a non-empty string');
  }

  const rawWinner = Number(obj['winnerHealthPercent']);
  if (isNaN(rawWinner)) {
    throw new Error(`winnerHealthPercent is not a number: ${obj['winnerHealthPercent']}`);
  }
  const winnerHealthPercent = Math.min(90, Math.max(10, Math.round(rawWinner)));

  const rawLoser = Number(obj['loserHealthPercent']);
  if (isNaN(rawLoser)) {
    throw new Error(`loserHealthPercent is not a number: ${obj['loserHealthPercent']}`);
  }
  // Clamp loser, then ensure it's strictly less than winner for non-draws
  let loserHealthPercent = Math.min(89, Math.max(0, Math.round(rawLoser)));
  if (winner !== 'draw' && loserHealthPercent >= winnerHealthPercent) {
    loserHealthPercent = Math.max(0, winnerHealthPercent - 1);
  }

  return {
    winner: winner as string,
    narration: narration.trim(),
    funFact: funFact.trim(),
    winnerHealthPercent,
    loserHealthPercent,
  };
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
  const warn1 = getSurvivalWarning(fighter1Id, name1, environmentName)
    .replace(/⚠️ SURVIVAL WARNING: |⚠️ NOTE: /g, '').trim();
  const warn2 = getSurvivalWarning(fighter2Id, name2, environmentName)
    .replace(/⚠️ SURVIVAL WARNING: |⚠️ NOTE: /g, '').trim();

  let prefill = `Arena: ${environmentName}. Survival & effectiveness check:\n`;
  prefill += warn1 ? `- ${name1}: ${warn1}\n` : `- ${name1}: can function in this arena.\n`;
  prefill += warn2 ? `- ${name2}: ${warn2}\n` : `- ${name2}: can function in this arena.\n`;
  prefill += `Based on the arena conditions above, my ruling is:\n{`;
  return prefill;
}

async function callClaude(
  client: Anthropic,
  fighter1Id: string,
  fighter2Id: string,
  topP: number,
  fighter1Name?: string,
  fighter2Name?: string,
  environmentName?: string
): Promise<BattleResult> {
  const name1 = fighter1Name ?? ANIMAL_NAMES[fighter1Id] ?? fighter1Id;
  const name2 = fighter2Name ?? ANIMAL_NAMES[fighter2Id] ?? fighter2Id;

  // Prefill: force Claude to commit to the arena assessment before writing JSON.
  // Claude cannot contradict its own prior turn, so this locks in the arena ruling.
  const prefill = environmentName
    ? buildArenaPrefill(fighter1Id, fighter2Id, name1, name2, environmentName)
    : null;

  const messages: Anthropic.MessageParam[] = [
    {
      role: 'user',
      content: buildUserPrompt(fighter1Id, fighter2Id, fighter1Name, fighter2Name, environmentName),
    },
  ];
  if (prefill) {
    messages.push({ role: 'assistant', content: prefill });
  }

  const response = await client.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 500,
    top_p: topP,
    system: SYSTEM_PROMPT,
    messages,
  });

  const block = response.content[0];
  if (!block || block.type !== 'text') {
    throw new Error('Unexpected response format from Claude');
  }

  // The prefill ends with '{' — prepend it so the response is valid JSON.
  const responseText = prefill ? '{' + block.text : block.text;
  const cleaned = stripMarkdownFences(responseText);
  const parsed = JSON.parse(cleaned) as unknown;
  return validateResult(parsed, fighter1Id, fighter2Id);
}

export async function getBattleResult(
  fighter1Id: string,
  fighter2Id: string,
  fighter1Name?: string,
  fighter2Name?: string,
  environmentName?: string
): Promise<BattleResult> {
  const client = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY,
  });

  // First attempt with top_p equivalent to temperature 0.8 (~0.95)
  try {
    return await callClaude(client, fighter1Id, fighter2Id, 0.95, fighter1Name, fighter2Name, environmentName);
  } catch (firstError) {
    console.warn('First attempt failed, retrying with lower top_p:', firstError);
  }

  // Retry once with a more deterministic top_p equivalent to temperature 0.3 (~0.7)
  try {
    return await callClaude(client, fighter1Id, fighter2Id, 0.7, fighter1Name, fighter2Name, environmentName);
  } catch (secondError) {
    console.error('Second attempt also failed:', secondError);
    throw new Error('Unable to generate a valid battle result after two attempts.');
  }
}
