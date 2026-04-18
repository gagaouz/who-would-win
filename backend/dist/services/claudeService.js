"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getQuickBattleResult = getQuickBattleResult;
exports.getBattleResult = getBattleResult;
const sdk_1 = __importDefault(require("@anthropic-ai/sdk"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config({ override: true }); // override: true needed because Claude Code pre-sets ANTHROPIC_API_KEY to ""
// IDs that represent immortal gods/deities — they always dominate mortals
const DEITY_IDS = new Set([
    'zeus', 'poseidon', 'hades', 'ares', 'athena', 'apollo',
    'artemis', 'hermes', 'hephaestus', 'hercules', 'medusa', 'kronos',
]);
const POWER_PROFILES = {
    // ─── Land mammals / reptiles / insects (real) ───
    lion: { tier: 6, blurb: '~190 kg apex savanna predator with bone-crushing bite and pack coordination' },
    tiger: { tier: 6, blurb: '~260 kg solo ambush hunter, largest living cat, immense strength and claws' },
    grizzly_bear: { tier: 7, blurb: '~360 kg omnivore with devastating swipes, thick hide, and unmatched bite force for a mammal' },
    wolf: { tier: 4, blurb: '~45 kg pack hunter, exceptional endurance and bite but small solo' },
    elephant: { tier: 8, blurb: '~5,000 kg colossus — crushes most predators outright with sheer mass and tusks' },
    rhinoceros: { tier: 7, blurb: '~2,000 kg armored charger with a lethal horn, near-indestructible hide' },
    hippopotamus: { tier: 7, blurb: '~1,500 kg aggressive semi-aquatic with the largest jaws of any land mammal' },
    gorilla: { tier: 6, blurb: '~180 kg great ape with immense upper-body strength, ~10× human strength' },
    cheetah: { tier: 4, blurb: '~55 kg sprinter (110 km/h) but fragile; built for speed, not fighting' },
    crocodile: { tier: 7, blurb: '~500 kg ambush reptile with the strongest bite force on earth and armored scales' },
    komodo_dragon: { tier: 5, blurb: '~80 kg venomous reptile with serrated bite and bacteria-laden saliva' },
    wolverine: { tier: 4, blurb: '~15 kg mustelid, pound-for-pound among the strongest; kills prey many times its size' },
    honey_badger: { tier: 3, blurb: '~12 kg mustelid famous for fearlessness and tough hide but small' },
    giraffe: { tier: 5, blurb: '~1,200 kg herbivore with devastating hoof-kick' },
    zebra: { tier: 4, blurb: '~300 kg equine, dangerous kick but prey animal' },
    moose: { tier: 6, blurb: '~500 kg cervid with massive antlers and crushing hooves' },
    boar: { tier: 4, blurb: '~90 kg tusked charger, surprisingly deadly' },
    tarantula: { tier: 2, blurb: '~100 g spider with venomous bite, small scale' },
    scorpion: { tier: 2, blurb: '~50 g venomous arachnid with pincers and stinger' },
    cobra: { tier: 3, blurb: '~6 kg venomous snake, lethal neurotoxin bite' },
    // ─── Sea (real) ───
    great_white_shark: { tier: 8, blurb: '~1,100 kg apex ocean predator with serrated bite, completely dominant underwater' },
    orca: { tier: 9, blurb: '~5,500 kg apex ocean hunter, intelligent pack tactics, kills great whites' },
    giant_squid: { tier: 7, blurb: '~275 kg cephalopod with 10 m tentacles and beaked crushing bite' },
    piranha: { tier: 2, blurb: '~3 kg small fish; dangerous only in schools' },
    octopus: { tier: 3, blurb: '~15 kg intelligent cephalopod, no armor, pure agility' },
    barracuda: { tier: 4, blurb: '~50 kg torpedo-fast predator fish with razor teeth' },
    electric_eel: { tier: 4, blurb: '~20 kg fish delivering 600 V stunning shocks' },
    hammerhead_shark: { tier: 7, blurb: '~500 kg shark with wide head sensor array and powerful bite' },
    mantis_shrimp: { tier: 2, blurb: '~0.5 kg crustacean with punches that break aquarium glass (small scale)' },
    blue_ringed_octopus: { tier: 3, blurb: '~0.1 kg but carries enough tetrodotoxin to kill 20 humans' },
    swordfish: { tier: 5, blurb: '~650 kg billfish with a bladed rostrum, top ocean speeds' },
    coelacanth: { tier: 3, blurb: '~90 kg living-fossil fish, mostly defensive' },
    // ─── Air (real) ───
    bald_eagle: { tier: 4, blurb: '~6 kg raptor, fierce talons but tiny vs land megafauna' },
    peregrine_falcon: { tier: 3, blurb: '~1 kg falcon, fastest diving bird (320 km/h) but small and fragile' },
    harpy_eagle: { tier: 4, blurb: '~9 kg largest eagle, crushing talon grip, apex of the canopy — but no match for ground megafauna or mythic beasts' },
    barn_owl: { tier: 2, blurb: '~0.5 kg silent nocturnal hunter of rodents' },
    hornet: { tier: 1, blurb: '~5 g insect, painful venom; tiny' },
    dragonfly: { tier: 1, blurb: '~1 g insect with fast flight, minuscule combat presence' },
    albatross: { tier: 2, blurb: '~10 kg seabird with enormous wingspan, not a fighter' },
    pelican: { tier: 2, blurb: '~10 kg fish-scooping bird, not built for combat' },
    crow: { tier: 2, blurb: '~1 kg clever corvid, opportunist not fighter' },
    // ─── Insects / bugs ───
    army_ant: { tier: 1, blurb: '0.01 g individual; devastating only as a swarm' },
    bombardier_beetle: { tier: 1, blurb: '~1 g beetle with boiling chemical spray; tiny' },
    bullet_ant: { tier: 1, blurb: '~0.03 g ant with the most painful insect sting; tiny' },
    praying_mantis: { tier: 1, blurb: '~5 g ambush predator with spiked forelegs; tiny' },
    fire_ant: { tier: 1, blurb: '~0.005 g individual, dangerous only in swarms' },
    centipede: { tier: 1, blurb: '~30 g venomous arthropod; small combat scale' },
    wasp: { tier: 1, blurb: '~0.1 g stinging insect; tiny' },
    stag_beetle: { tier: 1, blurb: '~5 g beetle with jaw pincers; tiny' },
    // ─── Fantasy / mythic creatures ───
    dragon: { tier: 9, blurb: 'massive legendary fire-breathing winged reptile, armored scales — apex fantasy creature' },
    unicorn: { tier: 6, blurb: 'magical horned horse with enchanted horn and healing magic; combat-capable but not brutal' },
    griffin: { tier: 7, blurb: 'eagle-lion hybrid, lion-sized with eagle wings and talons — apex aerial-land hybrid' },
    kraken: { tier: 9, blurb: 'colossal legendary sea monster with ship-crushing tentacles — ocean-domain god' },
    minotaur: { tier: 6, blurb: 'bull-headed humanoid warrior with labyrinthine cunning and immense strength' },
    werewolf: { tier: 6, blurb: 'lycanthrope with enhanced strength, claws, regeneration — especially dangerous at night' },
    hydra: { tier: 9, blurb: 'massive multi-headed serpent with regenerating heads and venomous blood — a mortal-killer of legend' },
    phoenix: { tier: 8, blurb: 'immortal fire-bird that resurrects from its own ashes; firestorm breath' },
    kitsune: { tier: 6, blurb: 'nine-tailed fox spirit wielding illusion and elemental magic' },
    basilisk: { tier: 8, blurb: 'king of serpents, petrifying gaze and lethally venomous bite' },
    cerberus: { tier: 8, blurb: 'three-headed guardian hound of the underworld, unkillable by ordinary means' },
    leviathan: { tier: 9, blurb: 'biblical sea-serpent the size of a cruise ship, nigh-invincible' },
    // ─── Prehistoric ───
    t_rex: { tier: 8, blurb: '~7,000 kg apex Cretaceous predator with bone-shearing bite (6× a lion\'s)' },
    triceratops: { tier: 7, blurb: '~8,000 kg horned dinosaur with massive frill and charging horns' },
    velociraptor: { tier: 5, blurb: '~15 kg feathered pack hunter with hyperextended sickle claws; agile but small' },
    spinosaurus: { tier: 8, blurb: '~7,500 kg semi-aquatic theropod, longer than T-Rex, dominant in water and land' },
    megalodon: { tier: 9, blurb: '~50,000 kg prehistoric shark (3× great white), largest predatory fish ever' },
    woolly_mammoth: { tier: 7, blurb: '~6,000 kg ice-age proboscidean with huge curved tusks' },
    saber_tooth_tiger: { tier: 6, blurb: '~400 kg smilodon with 28 cm canines and powerful forelimbs' },
    ankylosaurus: { tier: 7, blurb: '~6,000 kg armored tank-dinosaur with a bone-crushing club tail' },
    pteranodon: { tier: 5, blurb: '~25 kg pterosaur with a 7 m wingspan, fragile close-range fighter' },
    pterodactyl: { tier: 3, blurb: '~5 kg small pterosaur, fragile' },
    dire_wolf: { tier: 5, blurb: '~80 kg prehistoric wolf, 25% larger than modern gray wolf' },
    therizinosaurus: { tier: 6, blurb: '~5,000 kg herbivorous theropod with 1 m scythe-claws' },
    dodo: { tier: 1, blurb: '~15 kg flightless bird famous for being defenseless' },
    // ─── Mythic (upper tier) ───
    thunderbird: { tier: 9, blurb: 'giant Native American myth-bird that commands lightning and storms' },
    manticore: { tier: 7, blurb: 'lion-bodied beast with human face, bat wings, and venomous scorpion tail' },
    sphinx: { tier: 7, blurb: 'winged lion-bodied riddler with human head; magical and strong' },
    chimera: { tier: 8, blurb: 'lion-goat-serpent fusion that breathes fire; apex Greek myth beast' },
    wyvern: { tier: 7, blurb: 'smaller dragon cousin — two-legged flying reptile with venomous tail' },
    kirin: { tier: 7, blurb: 'Eastern celestial chimera-deer with elemental magic and near-invincibility' },
    roc: { tier: 8, blurb: 'mountain-sized legendary bird that carries off elephants in its talons' },
    jackalope: { tier: 3, blurb: 'folk-hybrid rabbit with antlers; mostly mischievous, not a heavy hitter' },
    baku: { tier: 6, blurb: 'Japanese chimera that devours nightmares; bear-sized and magical' },
    nue: { tier: 7, blurb: 'yōkai chimera with monkey head, tiger body, snake tail — vengeful storm-summoner' },
    ammit: { tier: 7, blurb: 'Egyptian soul-devourer — crocodile head, lion torso, hippo rear — devourer of hearts' },
    peryton: { tier: 5, blurb: 'winged stag of ill omen, larger than a horse; competent combatant' },
};
// Returns an explicit profile line for the fighter, or falls back to a generic
// string for custom/unknown fighters so the model can still reason.
function getPowerProfile(id, name) {
    const p = POWER_PROFILES[id];
    if (p) {
        return `${name} — TIER ${p.tier}/10 — ${p.blurb}`;
    }
    if (DEITY_IDS.has(id)) {
        return `${name} — TIER 10/10 — Olympian god with divine powers; dominates all mortal creatures`;
    }
    return `${name} — tier unknown (custom/user-defined creature) — judge from your own knowledge of this creature\'s real-world or fictional abilities`;
}
// Mapping of animal IDs to human-readable display names
const ANIMAL_NAMES = {
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
    zeus: 'Zeus',
    poseidon: 'Poseidon',
    hades: 'Hades',
    ares: 'Ares',
    athena: 'Athena',
    apollo: 'Apollo',
    artemis: 'Artemis',
    hermes: 'Hermes',
    hephaestus: 'Hephaestus',
    hercules: 'Hercules',
    medusa: 'Medusa',
    kronos: 'Kronos',
};
const SYSTEM_PROMPT = 'You are the referee for "Who Would Win?" — a fun educational game for kids. ' +
    'When an ARENA is specified, it is an important factor — an animal fighting outside its element is disadvantaged. When NO arena is specified, ignore terrain entirely and judge fighters solely on their natural strengths. ' +
    'POWER TIERS: When a FIGHTER PROFILES section is provided, treat those tier numbers and blurbs as ground truth for size, weight, and capability. A 3-tier gap should be decisive — the higher-tier creature wins unless the arena strongly and specifically cripples it (e.g. a land mammal in deep open ocean vs a shark). A 4+ tier gap is almost never overcome by terrain alone. Never let a small raptor or small carnivore defeat a dragon, hydra, kraken, elephant, T-Rex, or Olympian god just because the arena is its home turf. Terrain can swing a close matchup; it cannot rewrite mass and lethality. ' +
    'For real animals, base decisions on biology: size, natural weapons, speed, venom, armor, hunting behavior — all adjusted for the arena conditions. ' +
    'For mythological and fantasy creatures, use their established legendary abilities from mythology and folklore. ' +
    'For figures from Greek mythology like Zeus, Poseidon, Hades, Ares, Athena, Apollo, Artemis, Hermes, Hephaestus, Kronos (Olympian gods), Hercules, and Medusa — these are legendary mythological figures with extraordinary powers; they should win convincingly against any ordinary animal or creature based on their mythological abilities. Two mythological gods fighting each other can result in a win for either side or a draw. ' +
    'Keep narration exciting and appropriate for children — like a myth retelling, not a graphic fight. ' +
    'Always respond with ONLY valid JSON matching the exact schema. No markdown, no explanation outside the JSON.';
const ENVIRONMENT_DESCRIPTIONS = {
    Grassland: 'open savanna with tall grass and a wide sky — neutral terrain with no water nearby',
    Ocean: 'deep open ocean, fully submerged underwater — there is NO land, no shore, only sea',
    Sky: 'high in the sky among the clouds — both fighters are airborne with no ground beneath them',
    Arctic: 'a frozen tundra of ice and snow — bitterly cold, slippery, no vegetation',
    Desert: 'a scorching hot desert with sand dunes and blazing sun — no water anywhere',
    Jungle: 'dense tropical rainforest with thick trees, vines, and undergrowth — tight quarters, plenty of cover',
    Volcano: 'the rocky rim of an erupting volcano surrounded by rivers of lava and falling ash — extreme heat',
    Night: 'a dark wilderness at night under a full moon — low visibility, shadows everywhere',
    Storm: 'a raging thunderstorm with lightning strikes, gale-force winds, and torrential rain',
};
// Animals that are native to each element — used for survival warnings
const SEA_ANIMALS = new Set([
    'great_white_shark', 'orca', 'giant_squid', 'piranha', 'octopus', 'barracuda',
    'electric_eel', 'hammerhead_shark', 'mantis_shrimp', 'blue_ringed_octopus',
    'swordfish', 'coelacanth', 'megalodon', 'kraken', 'leviathan',
]);
const AIR_ANIMALS = new Set([
    'bald_eagle', 'peregrine_falcon', 'harpy_eagle', 'barn_owl', 'pterodactyl',
    'hornet', 'dragonfly', 'albatross', 'pelican', 'crow', 'thunderbird', 'roc', 'pteranodon',
]);
const LAND_ANIMALS = new Set(Object.keys(ANIMAL_NAMES).filter(id => !SEA_ANIMALS.has(id) && !AIR_ANIMALS.has(id)));
function getSurvivalWarning(id, name, environmentName) {
    const isSea = SEA_ANIMALS.has(id);
    const isAir = AIR_ANIMALS.has(id);
    const isLand = LAND_ANIMALS.has(id);
    if (environmentName === 'Ocean') {
        if (isLand)
            return `⚠️ SURVIVAL WARNING: ${name} is a land animal — it cannot breathe underwater and will drown in minutes. It is at an extreme, near-certain disadvantage in this arena.\n`;
        if (isAir)
            return `⚠️ SURVIVAL WARNING: ${name} is an air animal — it cannot breathe underwater and will drown in minutes. It is at an extreme disadvantage in this arena.\n`;
    }
    if (environmentName === 'Sky') {
        if (isLand && !['dragon', 'griffin', 'wyvern', 'phoenix', 'thunderbird', 'roc'].includes(id))
            return `⚠️ SURVIVAL WARNING: ${name} cannot fly — it will fall and is helpless in this airborne arena.\n`;
        if (isSea)
            return `⚠️ SURVIVAL WARNING: ${name} is an aquatic animal — it cannot fly and is helpless in a sky arena.\n`;
    }
    if (environmentName === 'Desert') {
        if (isSea)
            return `⚠️ SURVIVAL WARNING: ${name} is an aquatic animal — it cannot survive out of water in a desert and will quickly die from dehydration.\n`;
    }
    if (environmentName === 'Arctic') {
        if (isSea && !['orca', 'great_white_shark', 'hammerhead_shark', 'megalodon'].includes(id))
            return `⚠️ NOTE: ${name} is a warm-water sea animal and will struggle in freezing arctic conditions.\n`;
    }
    return '';
}
function buildUserPrompt(fighter1Id, fighter2Id, fighter1Name, fighter2Name, environmentName, tournamentContext) {
    const name1 = fighter1Name ?? ANIMAL_NAMES[fighter1Id] ?? fighter1Id;
    const name2 = fighter2Name ?? ANIMAL_NAMES[fighter2Id] ?? fighter2Id;
    // Tournament context: prepended as a single line so the narrator builds drama
    // appropriate to the round (early rounds scrappier, finals epic). Optional.
    const tournamentLine = tournamentContext
        ? `TOURNAMENT CONTEXT: ${tournamentContext}\n\n`
        : '';
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
        : `There is NO arena environment for this battle. Judge each fighter purely on their natural strengths, biology, and abilities. Do NOT apply any terrain advantage or disadvantage — neither fighter has a home-environment bonus or penalty. Base the outcome entirely on the fighters themselves.\n\n`;
    const warn1 = environmentName ? getSurvivalWarning(fighter1Id, name1, environmentName) : '';
    const warn2 = environmentName ? getSurvivalWarning(fighter2Id, name2, environmentName) : '';
    // Tier profiles — ground truth on size and capability. Also compute the tier
    // gap and emit an explicit guidance line when the gap is wide, so the model
    // doesn't hand a kraken-vs-hawk matchup to the hawk just because it's in the sky.
    const profile1 = getPowerProfile(fighter1Id, name1);
    const profile2 = getPowerProfile(fighter2Id, name2);
    const tier1 = POWER_PROFILES[fighter1Id]?.tier ?? (DEITY_IDS.has(fighter1Id) ? 10 : null);
    const tier2 = POWER_PROFILES[fighter2Id]?.tier ?? (DEITY_IDS.has(fighter2Id) ? 10 : null);
    let tierGapLine = '';
    if (tier1 !== null && tier2 !== null) {
        const gap = Math.abs(tier1 - tier2);
        if (gap >= 4) {
            const stronger = tier1 > tier2 ? name1 : name2;
            tierGapLine = `TIER GAP: ${gap} tiers. ${stronger} is dramatically more powerful and should win decisively regardless of arena — terrain cannot overcome this gap.\n\n`;
        }
        else if (gap === 3) {
            const stronger = tier1 > tier2 ? name1 : name2;
            tierGapLine = `TIER GAP: 3 tiers. ${stronger} has a decisive size/power advantage and should win unless the arena is catastrophically lethal to it specifically.\n\n`;
        }
    }
    const profilesBlock = `FIGHTER PROFILES (use these as ground truth for size, weight, and combat capability — do NOT upgrade a small creature past its tier):\n` +
        `  • ${profile1}\n` +
        `  • ${profile2}\n\n` +
        tierGapLine;
    return (tournamentLine +
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
        `- Fun fact: accurate and interesting`);
}
function stripMarkdownFences(text) {
    // Remove ```json ... ``` or ``` ... ``` wrappers if present
    return text
        .replace(/^```(?:json)?\s*/i, '')
        .replace(/\s*```\s*$/, '')
        .trim();
}
function validateResult(data, fighter1Id, fighter2Id) {
    if (typeof data !== 'object' || data === null) {
        throw new Error('Response is not an object');
    }
    const obj = data;
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
        winner: winner,
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
function buildArenaPrefill(fighter1Id, fighter2Id, name1, name2, environmentName) {
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
async function callClaude(client, fighter1Id, fighter2Id, topP, fighter1Name, fighter2Name, environmentName, tournamentContext) {
    const name1 = fighter1Name ?? ANIMAL_NAMES[fighter1Id] ?? fighter1Id;
    const name2 = fighter2Name ?? ANIMAL_NAMES[fighter2Id] ?? fighter2Id;
    // Prefill: force Claude to commit to the arena assessment before writing JSON.
    // Claude cannot contradict its own prior turn, so this locks in the arena ruling.
    const prefill = environmentName
        ? buildArenaPrefill(fighter1Id, fighter2Id, name1, name2, environmentName)
        : null;
    const messages = [
        {
            role: 'user',
            content: buildUserPrompt(fighter1Id, fighter2Id, fighter1Name, fighter2Name, environmentName, tournamentContext),
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
    const parsed = JSON.parse(cleaned);
    return validateResult(parsed, fighter1Id, fighter2Id);
}
// ── Quick Battle ─────────────────────────────────────────────────────────────
// Lightweight prompt: just picks a winner using the same tier/profile logic.
// Uses much fewer tokens than a full battle — ideal for tournament quick mode.
function buildQuickUserPrompt(fighter1Id, fighter2Id, fighter1Name, fighter2Name, environmentName) {
    const name1 = fighter1Name ?? ANIMAL_NAMES[fighter1Id] ?? fighter1Id;
    const name2 = fighter2Name ?? ANIMAL_NAMES[fighter2Id] ?? fighter2Id;
    const profile1 = getPowerProfile(fighter1Id, name1);
    const profile2 = getPowerProfile(fighter2Id, name2);
    const tier1 = POWER_PROFILES[fighter1Id]?.tier ?? (DEITY_IDS.has(fighter1Id) ? 10 : null);
    const tier2 = POWER_PROFILES[fighter2Id]?.tier ?? (DEITY_IDS.has(fighter2Id) ? 10 : null);
    let tierGapLine = '';
    if (tier1 !== null && tier2 !== null) {
        const gap = Math.abs(tier1 - tier2);
        if (gap >= 3) {
            const stronger = tier1 > tier2 ? name1 : name2;
            tierGapLine = `TIER GAP: ${gap} — ${stronger} is dramatically more powerful and should win.\n\n`;
        }
    }
    const customNote1 = !DEITY_IDS.has(fighter1Id) && !(fighter1Id in ANIMAL_NAMES) && fighter1Name
        ? `Note: "${fighter1Name}" is a user-defined fighter — judge from your own knowledge of it.\n`
        : '';
    const customNote2 = !DEITY_IDS.has(fighter2Id) && !(fighter2Id in ANIMAL_NAMES) && fighter2Name
        ? `Note: "${fighter2Name}" is a user-defined fighter — judge from your own knowledge of it.\n`
        : '';
    const arenaDesc = environmentName && ENVIRONMENT_DESCRIPTIONS[environmentName]
        ? `ARENA: ${environmentName} — ${ENVIRONMENT_DESCRIPTIONS[environmentName]}.\n`
        : '';
    const warn1 = environmentName ? getSurvivalWarning(fighter1Id, name1, environmentName) : '';
    const warn2 = environmentName ? getSurvivalWarning(fighter2Id, name2, environmentName) : '';
    return (`Quick battle decision: ${name1} vs ${name2}.\n\n` +
        `FIGHTER PROFILES:\n  • ${profile1}\n  • ${profile2}\n\n` +
        tierGapLine +
        customNote1 +
        customNote2 +
        arenaDesc +
        warn1 + warn2 +
        `\nPick a winner. Respond with ONLY valid JSON — no markdown:\n` +
        `{"winner":"<${fighter1Id} or ${fighter2Id}>","narration":"<one punchy sentence about the outcome>","funFact":"<one cool fact about the winner>","winnerHealthPercent":<10-90>,"loserHealthPercent":<0-40>}`);
}
async function getQuickBattleResult(fighter1Id, fighter2Id, fighter1Name, fighter2Name, environmentName) {
    const client = new sdk_1.default({ apiKey: process.env.ANTHROPIC_API_KEY });
    const response = await client.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 220,
        top_p: 0.7,
        system: 'You are the referee for "Who Would Win?" — a fun educational game for kids. ' +
            'Use the fighter profiles and tier numbers as ground truth for power levels. ' +
            'Never return a draw — always pick a winner. ' +
            'Always respond with ONLY valid JSON. No markdown, no explanation outside the JSON.',
        messages: [{ role: 'user', content: buildQuickUserPrompt(fighter1Id, fighter2Id, fighter1Name, fighter2Name, environmentName) }],
    });
    const block = response.content[0];
    if (!block || block.type !== 'text') {
        throw new Error('Unexpected response format from Claude (quick)');
    }
    const cleaned = stripMarkdownFences(block.text);
    const parsed = JSON.parse(cleaned);
    const result = validateResult(parsed, fighter1Id, fighter2Id);
    // Quick battles must always have a winner — break any draw randomly.
    if (result.winner === 'draw') {
        const winnerId = Math.random() < 0.5 ? fighter1Id : fighter2Id;
        return {
            ...result,
            winner: winnerId,
            winnerHealthPercent: Math.max(result.winnerHealthPercent, 55),
            loserHealthPercent: Math.min(result.loserHealthPercent, 35),
        };
    }
    return result;
}
async function getBattleResult(fighter1Id, fighter2Id, fighter1Name, fighter2Name, environmentName, tournamentContext) {
    const client = new sdk_1.default({
        apiKey: process.env.ANTHROPIC_API_KEY,
    });
    // First attempt with top_p equivalent to temperature 0.8 (~0.95)
    try {
        return await callClaude(client, fighter1Id, fighter2Id, 0.95, fighter1Name, fighter2Name, environmentName, tournamentContext);
    }
    catch (firstError) {
        console.warn('First attempt failed, retrying with lower top_p:', firstError);
    }
    // Retry once with a more deterministic top_p equivalent to temperature 0.3 (~0.7)
    try {
        return await callClaude(client, fighter1Id, fighter2Id, 0.7, fighter1Name, fighter2Name, environmentName, tournamentContext);
    }
    catch (secondError) {
        console.error('Second attempt also failed:', secondError);
        throw new Error('Unable to generate a valid battle result after two attempts.');
    }
}
