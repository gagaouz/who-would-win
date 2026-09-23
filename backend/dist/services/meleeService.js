"use strict";
/**
 * Melee Battle — N-vs-M team battle endpoint.
 *
 * Mirrors getQuickBattleResult but takes two teams instead of two fighters.
 * Uses the deterministic meleeResolver first; if the verdict is forced
 * (decisive power gap / deity asymmetry / fatal env), the AI is only asked
 * to narrate. If the verdict is open, the AI picks the winning team.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMeleeResult = getMeleeResult;
const anthropicClient_1 = require("./anthropicClient");
const sanitize_1 = require("../middleware/sanitize");
const creatures_1 = require("../data/creatures");
const storyRules_1 = require("./storyRules");
const meleeResolver_1 = require("./meleeResolver");
const claudeService_1 = require("./claudeService");
/** Estimate a real-scale tier for each CUSTOM fighter so melee verdicts are
 *  deterministic & realistic too (no gram-scale custom team beating apex
 *  predators). Known fighters pass through untouched. */
/// Estimates a tier for every custom fighter across BOTH teams, making exactly
/// one Haiku call per distinct creature name. Without this, three "Ladybug"
/// fighters (or the same name on both teams) would each fire a concurrent,
/// cache-missing estimate. Returns the two teams with `customTier` filled in.
async function withCustomTiers(teamA, teamB, signal) {
    // Map distinct lowercased name -> a representative display name.
    const distinct = new Map();
    for (const f of [...teamA, ...teamB]) {
        if (!(0, claudeService_1.isCustomFighter)(f.id))
            continue;
        const display = f.name ?? f.id;
        distinct.set(display.toLowerCase(), display);
    }
    // One estimate per distinct name, run concurrently.
    const tiers = new Map();
    await Promise.all([...distinct.entries()].map(async ([key, display]) => {
        const est = await (0, claudeService_1.estimateCustomTier)(display, signal);
        tiers.set(key, est?.tier ?? null);
    }));
    const fill = (team) => team.map(f => (0, claudeService_1.isCustomFighter)(f.id)
        ? { ...f, customTier: tiers.get((f.name ?? f.id).toLowerCase()) ?? null }
        : f);
    return [fill(teamA), fill(teamB)];
}
function fighterName(f) {
    return (0, creatures_1.displayName)(f.id, f.name);
}
function profileLine(f) {
    const name = fighterName(f);
    const c = (0, creatures_1.getCreature)(f.id);
    if (c)
        return `${name} (tier ${c.tier}, ${c.blurb}. Verified fact: ${c.fact})`;
    if (f.customTier != null)
        return `${name} (custom fighter, estimated tier ${f.customTier})`;
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
    const aNames = args.teamA.map(fighterName).join(', ');
    const bNames = args.teamB.map(fighterName).join(', ');
    return (verdictLine +
        `Melee team battle.\n\n` +
        teamBlock('A', args.teamA) + `\n\n` +
        teamBlock('B', args.teamB) + `\n\n` +
        arenaLine +
        `Rules for picking the winning team:\n` +
        `• Sum up each side's effective combat power (tier, size${args.environmentName ? ', arena' : ''}, weapons).\n` +
        `• A bigger team has the advantage of numbers, BUT coordination losses and ` +
        `friendly fire mean a single apex predator can beat 2-3 weaker fighters.\n` +
        // Survival only exists when there IS an arena — this bullet used to be
        // unconditional and directly contradicted the NO ARENA rules above it.
        (args.environmentName
            ? `• Survival overrides everything: a sea creature on land is helpless even in a 3v1.\n`
            : '') +
        `• Never give a wildly improbable upset just for drama.\n\n` +
        `Narration requirements — like a cinematic sports highlight reel for kids:\n` +
        `- EXACTLY 3 vivid sentences in present tense. Do not exceed 3 sentences.\n` +
        `- Use punchy verbs (charges, slams, vaults, soars, crashes, pounces, dodges) and sensory moments (dust kicks up, the ground shakes, a roar echoes, water explodes).\n` +
        `- Mention EVERY fighter by name AT LEAST ONCE — Team A: ${aNames}. Team B: ${bNames}.\n` +
        `- Open with a dramatic moment — "the bell rings", "the ground shakes". Don't open with a bland intro.\n` +
        `- Show how teammates work together OR get in each other's way — double-teams, distractions, covering each other. Make this a big part of the drama.\n` +
        storyRules_1.SIGNATURE_MOVE_RULE +
        `- Build to a final winning moment, then end with a triumphant beat: "stands tall over the arena", "the crowd erupts".\n` +
        storyRules_1.TONE_RULES + `\n` +
        `Fun-fact requirements — a WHOA-DID-YOU-KNOW reveal, not a textbook analysis:\n` +
        `- 1–2 sentences, ideally about how the winners' real ability countered the losers (speed beat bulk, wings beat ground, armor beat claws).\n` +
        storyRules_1.FACT_RULES + `\n` +
        `Respond with ONLY JSON, no markdown:\n` +
        `{"winningTeam":"<A or B>","narration":"<EXACTLY 3 sentences as described above>","funFact":"<1-2 sentences as described above>","mvp":"<id of MVP from winning team — one of: ${args.verdict.kind === 'forced' && args.verdict.winningTeam === 'A' ? aIds : args.verdict.kind === 'forced' && args.verdict.winningTeam === 'B' ? bIds : aIds + ', ' + bIds}>","teamAHealth":<10-90>,"teamBHealth":<10-90>}`);
}
function stripMarkdownFences(text) {
    return text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim();
}
function validateMeleeResult(data, teamA, teamB) {
    if (typeof data !== 'object' || data === null)
        throw new claudeService_1.StoryRejectedError('not an object');
    const obj = data;
    const winningTeam = obj.winningTeam;
    if (winningTeam !== 'A' && winningTeam !== 'B') {
        throw new claudeService_1.StoryRejectedError('invalid winningTeam');
    }
    const names = [...teamA, ...teamB].map(fighterName);
    // Strip emoji BEFORE the non-empty check so an all-emoji field is rejected
    // (retry/fallback) instead of shipping a blank card.
    if (typeof obj.narration !== 'string')
        throw new claudeService_1.StoryRejectedError('narration missing');
    const narrationText = (0, claudeService_1.stripEmoji)(obj.narration).slice(0, 1500);
    if (!narrationText.trim())
        throw new claudeService_1.StoryRejectedError('narration empty');
    const narration = (0, sanitize_1.repairStory)(narrationText, 'narration', names, 2);
    if (narration === null)
        throw new claudeService_1.StoryRejectedError(`narration ${(0, sanitize_1.storyProblem)(narrationText, 'narration', names)}`);
    if (typeof obj.funFact !== 'string')
        throw new claudeService_1.StoryRejectedError('funFact missing');
    const funFactText = (0, claudeService_1.stripEmoji)(obj.funFact).slice(0, 500);
    if (!funFactText.trim())
        throw new claudeService_1.StoryRejectedError('funFact empty');
    const funFact = (0, sanitize_1.repairStory)(funFactText, 'fact', names, 1);
    if (funFact === null)
        throw new claudeService_1.StoryRejectedError(`funFact ${(0, sanitize_1.storyProblem)(funFactText, 'fact', names)}`);
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
        narration, // already emoji-stripped + validated non-empty
        funFact, // already emoji-stripped + validated non-empty
        mvp,
        teamAHealth,
        teamBHealth,
    };
}
function enforceMeleeVerdict(result, verdict, teamA, teamB) {
    if (verdict.kind !== 'forced')
        return result;
    const winningTeamFighters = verdict.winningTeam === 'A' ? teamA : teamB;
    const agreed = result.winningTeam === verdict.winningTeam;
    if (!agreed) {
        console.warn(JSON.stringify({
            event: 'melee_verdict_override',
            claudeWon: result.winningTeam,
            forcedWon: verdict.winningTeam,
        }));
    }
    // A forced verdict means the resolver judged this a clearly dominant matchup.
    // Regardless of whether Claude picked the right winner, the health bars must
    // reflect that dominance — otherwise an agreed-on win can still render with a
    // deceptively close (or inverted) score. We keep Claude's narration/MVP when
    // it agreed, and only override the prose when it picked the wrong winner.
    const mvpOnWinningTeam = winningTeamFighters.some(f => f.id === result.mvp);
    return {
        winningTeam: verdict.winningTeam,
        narration: agreed
            ? result.narration
            : `${winningTeamFighters.map(fighterName).join(' and ')} take charge from the very first moment and never give up an inch. ` +
                `Size, speed and teamwork carry the day, and the crowd erupts as Team ${verdict.winningTeam} wins!`,
        funFact: result.funFact,
        mvp: agreed && mvpOnWinningTeam ? result.mvp : winningTeamFighters[0].id,
        teamAHealth: verdict.winningTeam === 'A' ? Math.max(70, result.teamAHealth) : Math.min(25, result.teamAHealth),
        teamBHealth: verdict.winningTeam === 'B' ? Math.max(70, result.teamBHealth) : Math.min(25, result.teamBHealth),
    };
}
async function getMeleeResult(teamA, teamB, environmentName, signal) {
    // Estimate tiers for any custom fighters first, so the resolver can force a
    // realistic verdict instead of deferring the whole melee to the AI.
    const [tA, tB] = await withCustomTiers(teamA, teamB, signal);
    const verdict = (0, meleeResolver_1.resolveMelee)({ teamA: tA, teamB: tB, environmentName });
    const prompt = buildMeleePrompt({ teamA: tA, teamB: tB, environmentName, verdict });
    const raw = await (0, claudeService_1.generateValidated)('melee', async (retryNote) => {
        const response = await (0, anthropicClient_1.createMessage)('melee', {
            max_tokens: 420,
            top_p: 0.9,
            system: 'You are the storyteller for "Who Would Win? Melee" — a team battle game for kids aged 6–12. Write like a kids action movie trailer, not a textbook. ' +
                'ACCURACY OVER UPSETS: pick the realistic winner. ' +
                'NUMBERS MATTER but so does power tier — a single tier-9 monster can beat 3 tier-3 ones. ' +
                'SURVIVAL: any creature that cannot live in the arena is essentially out of the fight. ' +
                'Every battle is an exciting scene with sound, dust, and a hero moment — follow the tone rules exactly. ' +
                'Respond with ONLY valid JSON.',
            messages: [{ role: 'user', content: prompt + (retryNote ?? '') }],
        }, signal);
        const block = response.content[0];
        if (!block || block.type !== 'text')
            throw new Error('Unexpected response (melee)');
        return block.text;
    }, text => validateMeleeResult(JSON.parse(stripMarkdownFences(text)), teamA, teamB));
    return enforceMeleeVerdict(raw, verdict, teamA, teamB);
}
