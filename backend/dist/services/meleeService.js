"use strict";
/**
 * Melee Battle — N-vs-M team battle endpoint.
 *
 * Mirrors getQuickBattleResult but takes two teams instead of two fighters.
 * Uses the deterministic meleeResolver first; if the verdict is forced
 * (decisive power gap / deity asymmetry / fatal env), the AI is only asked
 * to narrate. If the verdict is open, the AI picks the winning team.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMeleeResult = getMeleeResult;
const sdk_1 = __importDefault(require("@anthropic-ai/sdk"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config({ override: true });
const meleeResolver_1 = require("./meleeResolver");
const claudeService_1 = require("./claudeService");
function profileLine(f) {
    const name = f.name ?? claudeService_1.ANIMAL_NAMES_EXPORT[f.id] ?? f.id;
    const prof = claudeService_1.POWER_PROFILES[f.id];
    if (prof)
        return `${name} (tier ${prof.tier}, ${prof.blurb})`;
    if (claudeService_1.DEITY_IDS.has(f.id))
        return `${name} (tier 10, Greek deity)`;
    return `${name} (custom fighter — judge from your own knowledge)`;
}
function teamBlock(label, team) {
    return `Team ${label} (${team.length} fighter${team.length === 1 ? '' : 's'}):\n` +
        team.map(f => `  • ${profileLine(f)}`).join('\n');
}
function buildMeleePrompt(args) {
    const verdictLine = (0, meleeResolver_1.meleeVerdictPromptLine)(args.verdict);
    const arenaLine = args.environmentName
        ? `ARENA: ${args.environmentName}. A creature that cannot survive this arena fights at a fraction of normal power.\n`
        : `NO ARENA — fight in a featureless neutral void. STRICT RULES:\n` +
            `  • Do NOT mention savanna, ocean, jungle, sky, land, water, or any terrain.\n` +
            `  • Do NOT use habitat-based descriptors like "ocean giant", "savanna king", "sky predator", "jungle hunter". Refer to fighters by their NAME ("the Tiger", "the Great White Shark"), not by their habitat.\n` +
            `  • Do NOT assume any fighter is "out of its element", "on land", "in water", "in the air", "stranded", "beached", or "in its home". Everyone is equally at home in the neutral arena.\n` +
            `  • There is NO environmental advantage or disadvantage for ANY fighter — judge purely on inherent biology, size, weapons, and team coordination.\n`;
    const aIds = args.teamA.map(f => f.id).join(', ');
    const bIds = args.teamB.map(f => f.id).join(', ');
    const aNames = args.teamA.map(f => f.name ?? f.id).join(', ');
    const bNames = args.teamB.map(f => f.name ?? f.id).join(', ');
    return (verdictLine +
        `Melee team battle.\n\n` +
        teamBlock('A', args.teamA) + `\n\n` +
        teamBlock('B', args.teamB) + `\n\n` +
        arenaLine +
        `Rules for picking the winning team:\n` +
        `• Sum up each side's effective combat power (tier, size, arena, weapons).\n` +
        `• A bigger team has the advantage of numbers, BUT coordination losses and ` +
        `friendly fire mean a single apex predator can beat 2-3 weaker fighters.\n` +
        `• Survival overrides everything: a sea creature on land is helpless even in a 3v1.\n` +
        `• Never give a wildly improbable upset just for drama.\n\n` +
        `Narration requirements — write it EPIC, like a cinematic sports highlight reel for kids:\n` +
        `• EXACTLY 3 vivid sentences in present tense. Do not exceed 3 sentences. Pack them with action.\n` +
        `• Use punchy verbs (charges, slams, vaults, gores, rips, soars, crashes) and sensory hits (dust kicks up, the ground shakes, a roar splits the air, water explodes).\n` +
        `• Mention EVERY fighter by name AT LEAST ONCE — Team A: ${aNames}. Team B: ${bNames}.\n` +
        `• Open with a dramatic moment — "the bell rings", "the ground shakes", "a war cry splits the air". Don't open with a bland intro.\n` +
        `• Describe how teammates work together OR get in each other's way — herd tactics, double-teams, friendly fire, distractions, covering each other. Make this a HUGE part of the drama.\n` +
        `• Name AT LEAST ONE signature move or weapon and give it a memorable beat — "a bone-shattering bite", "a swooping talon strike", "a 5-ton hip-check".\n` +
        `• Build to a climactic finishing blow, then end with a triumphant beat: "stands roaring over the arena", "lifts its head as the crowd erupts".\n` +
        `• Kid-friendly — no gore, no blood. Battles are decisive but PG.\n` +
        `• AVOID bland phrasing like "ultimately won", "proved too much", "couldn't keep up", "stood victorious", "fought bravely". These are forbidden.\n\n` +
        `Fun-fact requirements — make it a WHOA-DID-YOU-KNOW reveal, not a textbook analysis:\n` +
        `• 1–2 sentences. Hit kids with something they'll want to repeat to their friends.\n` +
        `• Connect the two teams: how did the winners' superpower hard-counter the losers' weakness? (Speed beat bulk. Wings beat ground. Venom beat armor. Pack tactics beat solo defense.)\n` +
        `• Drop a real, surprising biological/mythical number when you can ("Orcas are smart enough to teach hunting tactics to their pod!").\n` +
        `• AVOID jargon like "tier", "stat", "coordination losses". Speak like a kid is reading it.\n\n` +
        `Respond with ONLY JSON, no markdown:\n` +
        `{"winningTeam":"<A or B>","narration":"<4-6 sentences as described above>","funFact":"<1-2 sentences as described above>","mvp":"<id of MVP from winning team — one of: ${args.verdict.kind === 'forced' && args.verdict.winningTeam === 'A' ? aIds : args.verdict.kind === 'forced' && args.verdict.winningTeam === 'B' ? bIds : aIds + ', ' + bIds}>","teamAHealth":<10-90>,"teamBHealth":<10-90>}`);
}
function stripMarkdownFences(text) {
    return text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim();
}
function validateMeleeResult(data, teamA, teamB) {
    if (typeof data !== 'object' || data === null)
        throw new Error('Not an object');
    const obj = data;
    const winningTeam = obj.winningTeam;
    if (winningTeam !== 'A' && winningTeam !== 'B') {
        throw new Error(`Invalid winningTeam: ${JSON.stringify(winningTeam)}`);
    }
    const narration = obj.narration;
    if (typeof narration !== 'string' || !narration.trim())
        throw new Error('narration missing');
    const funFact = obj.funFact;
    if (typeof funFact !== 'string' || !funFact.trim())
        throw new Error('funFact missing');
    // mvp must be a fighter from the winning team
    const winningTeamFighters = winningTeam === 'A' ? teamA : teamB;
    let mvp = String(obj.mvp ?? '');
    if (!winningTeamFighters.some(f => f.id === mvp)) {
        mvp = winningTeamFighters[0].id;
    }
    const teamAHealth = Math.min(90, Math.max(10, Math.round(Number(obj.teamAHealth ?? 50))));
    const teamBHealth = Math.min(90, Math.max(10, Math.round(Number(obj.teamBHealth ?? 50))));
    return {
        winningTeam,
        narration: narration.trim(),
        funFact: funFact.trim(),
        mvp,
        teamAHealth,
        teamBHealth,
    };
}
function enforceMeleeVerdict(result, verdict, teamA, teamB) {
    if (verdict.kind !== 'forced')
        return result;
    if (result.winningTeam === verdict.winningTeam)
        return result;
    console.warn(JSON.stringify({
        event: 'melee_verdict_override',
        claudeWon: result.winningTeam,
        forcedWon: verdict.winningTeam,
        reason: verdict.reason,
    }));
    const winningTeamFighters = verdict.winningTeam === 'A' ? teamA : teamB;
    return {
        winningTeam: verdict.winningTeam,
        narration: `Team ${verdict.winningTeam} dominated the matchup — overwhelming size, power, and natural advantage carried the day. The other team fought hard but simply could not match what their opponents brought to the fight.`,
        funFact: result.funFact,
        mvp: winningTeamFighters[0].id,
        teamAHealth: verdict.winningTeam === 'A' ? Math.max(70, result.teamAHealth) : Math.min(25, result.teamAHealth),
        teamBHealth: verdict.winningTeam === 'B' ? Math.max(70, result.teamBHealth) : Math.min(25, result.teamBHealth),
    };
}
async function getMeleeResult(teamA, teamB, environmentName) {
    const client = new sdk_1.default({ apiKey: process.env.ANTHROPIC_API_KEY });
    const verdict = (0, meleeResolver_1.resolveMelee)({ teamA, teamB, environmentName });
    const response = await client.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 500,
        top_p: 0.9,
        system: 'You are the cinematic narrator for "Who Would Win? Melee" — write like a kids action movie trailer, not a textbook. ' +
            'ACCURACY OVER UPSETS: pick the realistic winner. ' +
            'NUMBERS MATTER but so does power tier — a single tier-9 monster can beat 3 tier-3 ones. ' +
            'SURVIVAL: any creature that cannot live in the arena is essentially out of the fight. ' +
            'EPIC NARRATION is non-negotiable. Every battle is a movie scene with stakes, sound, dust, and a hero moment. ' +
            'Respond with ONLY valid JSON.',
        messages: [
            { role: 'user', content: buildMeleePrompt({ teamA, teamB, environmentName, verdict }) },
        ],
    });
    const block = response.content[0];
    if (!block || block.type !== 'text')
        throw new Error('Unexpected response (melee)');
    const cleaned = stripMarkdownFences(block.text);
    const parsed = JSON.parse(cleaned);
    const raw = validateMeleeResult(parsed, teamA, teamB);
    return enforceMeleeVerdict(raw, verdict, teamA, teamB);
}
