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
  // Mount Olympus — names include divine context so Claude knows they are gods
  zeus:       'Zeus (immortal King of the Greek Gods, master of lightning, omnipotent)',
  poseidon:   'Poseidon (immortal God of the Sea, wields a divine trident, controls oceans and earthquakes)',
  hades:      'Hades (immortal God of the Underworld, commands the dead, indestructible)',
  ares:       'Ares (immortal God of War, the ultimate warrior, invincible in battle)',
  athena:     'Athena (immortal Goddess of Wisdom and War, tactically unbeatable, divine armor)',
  apollo:     'Apollo (immortal God of the Sun, supernatural speed and precision, never misses)',
  artemis:    'Artemis (immortal Goddess of the Hunt, commands all wild animals, perfect aim)',
  hermes:     'Hermes (immortal Messenger God, faster than any mortal being, divine agility)',
  hephaestus: 'Hephaestus (immortal God of Fire and the Forge, impervious to heat, immense divine strength)',
  hercules:   'Hercules (son of Zeus, performed 12 impossible labors, strength beyond any mortal or beast)',
  medusa:     'Medusa (turns any mortal creature to stone with her gaze, virtually unstoppable)',
  kronos:     'Kronos (ancient Titan God of Time, supreme primordial power, father of the Olympian gods)',
};

export interface BattleResult {
  winner: string;               // animal ID or "draw"
  narration: string;            // 2-sentence battle description
  funFact: string;              // one fun fact about the winner (or both if draw)
  winnerHealthPercent: number;  // 10–90
  loserHealthPercent: number;   // 0–25
}

const SYSTEM_PROMPT =
  'You are the referee for "Who Would Win?" — an educational animal battle game. ' +
  'For real animals, make scientifically accurate decisions based on biology, behavior, and ecology. ' +
  'Consider: body size and mass, natural weapons (claws, teeth, venom, speed, strength), defensive adaptations, hunting behavior, and biological advantages. ' +
  'For mythological creatures, legendary beings, and fantasy animals, use their established legendary abilities. ' +
  'IMPORTANT: Greek gods and immortal deities (Zeus, Poseidon, Hades, Ares, Athena, Apollo, Artemis, Hermes, Hephaestus, Kronos, etc.) are omnipotent supernatural beings — they ALWAYS win decisively against any mortal animal or creature. Only a draw or loss is possible if they fight another god or deity of equal standing. ' +
  'Hercules and Medusa, while not full Olympian gods, possess powers so far beyond any mortal animal that they win against all natural creatures. ' +
  'Be exciting and kid-friendly. Describe the action like a nature documentary or epic myth, not a graphic fight. ' +
  'Always respond with ONLY valid JSON matching the exact schema provided. No markdown, no explanation.';

function buildUserPrompt(fighter1Id: string, fighter2Id: string, fighter1Name?: string, fighter2Name?: string): string {
  const name1 = fighter1Name ?? ANIMAL_NAMES[fighter1Id] ?? fighter1Id;
  const name2 = fighter2Name ?? ANIMAL_NAMES[fighter2Id] ?? fighter2Id;

  const isDeity1 = DEITY_IDS.has(fighter1Id);
  const isDeity2 = DEITY_IDS.has(fighter2Id);

  const deityNote = (isDeity1 || isDeity2)
    ? `IMPORTANT: ${isDeity1 ? name1.split(' (')[0] : ''}${isDeity1 && isDeity2 ? ' and ' : ''}${isDeity2 ? name2.split(' (')[0] : ''} ${isDeity1 && isDeity2 ? 'are both' : 'is a'} Greek god/deity — immortal and omnipotent. ${isDeity1 && isDeity2 ? 'This is an epic clash between gods; either could win or draw.' : 'They will decisively defeat any mortal creature.'}\n\n`
    : '';

  const customNote1 = !DEITY_IDS.has(fighter1Id) && !(fighter1Id in ANIMAL_NAMES) && fighter1Name
    ? `Note: "${fighter1Name}" is a user-defined fighter — assess its power based on everything you know about it (biology, mythology, fiction, pop culture, etc.).\n`
    : '';
  const customNote2 = !DEITY_IDS.has(fighter2Id) && !(fighter2Id in ANIMAL_NAMES) && fighter2Name
    ? `Note: "${fighter2Name}" is a user-defined fighter — assess its power based on everything you know about it (biology, mythology, fiction, pop culture, etc.).\n`
    : '';

  return (
    `Two fighters are about to battle: ${name1} vs ${name2}.\n\n` +
    deityNote +
    customNote1 +
    customNote2 +
    `Decide who would win in a direct encounter. Use all relevant knowledge: real biology, ecology, mythology, legendary abilities, or fictional lore — whatever applies to these specific fighters. ` +
    `The battle takes place in a neutral environment unless one fighter's nature gives a clear advantage.\n\n` +
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
    `- winnerHealthPercent: 10–90 (reflect how dominant the win was — gods should score 85–95)\n` +
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

  const winnerHealthPercent = obj['winnerHealthPercent'];
  if (
    typeof winnerHealthPercent !== 'number' ||
    winnerHealthPercent < 10 ||
    winnerHealthPercent > 90
  ) {
    throw new Error(`winnerHealthPercent out of range: ${winnerHealthPercent}`);
  }

  const loserHealthPercent = obj['loserHealthPercent'];
  if (
    typeof loserHealthPercent !== 'number' ||
    loserHealthPercent < 0 ||
    loserHealthPercent > 90
  ) {
    throw new Error(`loserHealthPercent out of range: ${loserHealthPercent}`);
  }
  // For non-draw fights the loser must have strictly less health than the winner
  if (winner !== 'draw' && loserHealthPercent >= winnerHealthPercent) {
    throw new Error(
      `loserHealthPercent (${loserHealthPercent}) must be less than winnerHealthPercent (${winnerHealthPercent})`
    );
  }

  return {
    winner: winner as string,
    narration: narration.trim(),
    funFact: funFact.trim(),
    winnerHealthPercent,
    loserHealthPercent,
  };
}

async function callClaude(
  client: Anthropic,
  fighter1Id: string,
  fighter2Id: string,
  topP: number,
  fighter1Name?: string,
  fighter2Name?: string
): Promise<BattleResult> {
  const response = await client.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 300,
    top_p: topP,
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: 'user',
        content: buildUserPrompt(fighter1Id, fighter2Id, fighter1Name, fighter2Name),
      },
    ],
  });

  const block = response.content[0];
  if (!block || block.type !== 'text') {
    throw new Error('Unexpected response format from Claude');
  }

  const cleaned = stripMarkdownFences(block.text);
  const parsed = JSON.parse(cleaned) as unknown;
  return validateResult(parsed, fighter1Id, fighter2Id);
}

export async function getBattleResult(
  fighter1Id: string,
  fighter2Id: string,
  fighter1Name?: string,
  fighter2Name?: string
): Promise<BattleResult> {
  const client = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY,
  });

  // First attempt with top_p equivalent to temperature 0.8 (~0.95)
  try {
    return await callClaude(client, fighter1Id, fighter2Id, 0.95, fighter1Name, fighter2Name);
  } catch (firstError) {
    console.warn('First attempt failed, retrying with lower top_p:', firstError);
  }

  // Retry once with a more deterministic top_p equivalent to temperature 0.3 (~0.7)
  try {
    return await callClaude(client, fighter1Id, fighter2Id, 0.7, fighter1Name, fighter2Name);
  } catch (secondError) {
    console.error('Second attempt also failed:', secondError);
    throw new Error('Unable to generate a valid battle result after two attempts.');
  }
}
