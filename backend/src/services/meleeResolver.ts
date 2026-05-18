/**
 * Melee Team Battle Resolver
 *
 * Decides the winning TEAM of an N-vs-M melee. Mirrors battleResolver.ts but
 * works on team rosters: sums each side's effective power, applies a small
 * coordination bonus to the smaller team, and forces a verdict when the
 * power ratio is decisive (≥8×). Close calls fall through to the AI.
 *
 * Why teams need their own resolver
 * ──────────────────────────────────
 * In a 3v1, the larger team has 3 fighters' worth of mass to bring to bear,
 * but it also has coordination/friendly-fire issues. A pure sum gives the
 * 3-team too much credit (3× any single fighter); a pure average gives them
 * not enough (a single fighter beats a smaller-team average). The right
 * model is sum-with-mild-coordination-penalty: the larger team's total power
 * is multiplied by 0.92^(K-1), so 3 fighters get ~85% efficiency, 4 get ~78%.
 * That keeps a single tier-9 dragon competitive against three tier-3
 * monsters without making a 4v1 swing meaningless.
 */

import {
  DEITY_IDS,
  POWER_PROFILES,
  SEA_ANIMALS,
  AIR_ANIMALS,
  LAND_ANIMALS,
} from './claudeService';

export interface MeleeFighter {
  id: string;
  name?: string;
}

export interface MeleeArgs {
  teamA: MeleeFighter[];
  teamB: MeleeFighter[];
  environmentName?: string;
}

export type MeleeVerdict =
  | {
      kind: 'forced';
      winningTeam: 'A' | 'B';
      reason: string;
    }
  | {
      kind: 'open';
      predictedWinningTeam?: 'A' | 'B';
      reason: string;
    };

const SEMI_AQUATIC = new Set(['hippopotamus', 'alligator', 'crocodile']);

function isKnown(id: string): boolean {
  return id in POWER_PROFILES || DEITY_IDS.has(id);
}
function getTier(id: string): number | null {
  if (DEITY_IDS.has(id)) return 10;
  return POWER_PROFILES[id]?.tier ?? null;
}

function envModifier(id: string, env: string | undefined): number {
  if (!env) return 1.0;
  const isSea  = SEA_ANIMALS.has(id);
  const isAir  = AIR_ANIMALS.has(id);
  const isLand = LAND_ANIMALS.has(id);
  const semi   = SEMI_AQUATIC.has(id);
  if (DEITY_IDS.has(id)) return 1.0;
  if (env === 'Ocean') {
    if (isSea) return 1.0;
    if (semi)  return 0.5;
    return 0.10;
  }
  if (env === 'Sky') {
    if (isAir) return 1.0;
    return 0.05;
  }
  if (['Grassland','Jungle','Volcano','Desert','Arctic'].includes(env)) {
    if (isSea && !semi) return 0.05;
    if (isLand) return 1.0;
    if (isAir)  return 0.85;
    return 0.9;
  }
  return 1.0;
}

/** 2^tier × envModifier — same as 1v1 resolver. */
function fighterPower(id: string, env: string | undefined): number {
  const t = getTier(id);
  if (t === null) return 0;
  return Math.pow(2, t) * envModifier(id, env);
}

/**
 * Team power = sum(fighter powers) × coordination factor.
 * Coordination factor decays slightly per extra fighter so a 4-team isn't
 * worth a full 4× a 1-team: 1 → 1.00, 2 → 0.96, 3 → 0.88, 4 → 0.78.
 * A single high-tier fighter can still beat a team of weaker ones.
 */
function teamPower(team: MeleeFighter[], env: string | undefined): number {
  if (team.length === 0) return 0;
  const sum = team.reduce((acc, f) => acc + fighterPower(f.id, env), 0);
  const coord = Math.pow(0.92, team.length - 1);
  return sum * coord;
}

export function resolveMelee(args: MeleeArgs): MeleeVerdict {
  const { teamA, teamB, environmentName } = args;

  if (teamA.length === 0 || teamB.length === 0) {
    return { kind: 'open', reason: 'empty team — AI decides' };
  }

  // Any custom/unknown fighter on either side → defer to AI.
  // Resolver only forces verdicts when EVERY fighter is in the tier table.
  const allKnown =
    teamA.every(f => isKnown(f.id)) && teamB.every(f => isKnown(f.id));
  if (!allKnown) {
    return { kind: 'open', reason: 'custom-or-unknown fighter on one team' };
  }

  // Deity asymmetry: a team with a deity beats a team without one outright,
  // unless the opposing team also has a deity.
  const aHasDeity = teamA.some(f => DEITY_IDS.has(f.id));
  const bHasDeity = teamB.some(f => DEITY_IDS.has(f.id));
  if (aHasDeity && !bHasDeity) {
    return { kind: 'forced', winningTeam: 'A', reason: 'team A has a deity' };
  }
  if (bHasDeity && !aHasDeity) {
    return { kind: 'forced', winningTeam: 'B', reason: 'team B has a deity' };
  }

  const pA = teamPower(teamA, environmentName);
  const pB = teamPower(teamB, environmentName);

  if (pA === 0 || pB === 0) {
    return { kind: 'open', reason: 'zero-power side — AI decides' };
  }

  // Catastrophic env: if a team's average per-fighter env mod ≤ 0.10 AND
  // the other team's is ≥ 0.5, force the loss (e.g. orcas-on-grass vs eagles).
  const avgEnv = (team: MeleeFighter[]) =>
    team.reduce((a, f) => a + envModifier(f.id, environmentName), 0) / team.length;
  const envA = avgEnv(teamA);
  const envB = avgEnv(teamB);
  if (envA <= 0.10 && envB >= 0.5) {
    return { kind: 'forced', winningTeam: 'B', reason: `team A cannot survive ${environmentName}` };
  }
  if (envB <= 0.10 && envA >= 0.5) {
    return { kind: 'forced', winningTeam: 'A', reason: `team B cannot survive ${environmentName}` };
  }

  const ratio = pA / pB;
  if (ratio >= 8) {
    return { kind: 'forced', winningTeam: 'A', reason: `team A power ${ratio.toFixed(1)}× team B` };
  }
  if (ratio <= 1 / 8) {
    return { kind: 'forced', winningTeam: 'B', reason: `team B power ${(1 / ratio).toFixed(1)}× team A` };
  }

  return {
    kind: 'open',
    predictedWinningTeam: pA >= pB ? 'A' : 'B',
    reason: `close matchup, ratio ${(pA >= pB ? ratio : 1 / ratio).toFixed(2)}×`,
  };
}

export function meleeVerdictPromptLine(v: MeleeVerdict): string {
  if (v.kind !== 'forced') return '';
  return (
    `\n🔒 OUTCOME ALREADY DECIDED: Team ${v.winningTeam} WINS (${v.reason}).\n` +
    `This verdict is FINAL — the referee has already ruled. Your job is to write ` +
    `the narration explaining WHY team ${v.winningTeam} won, citing real biology, ` +
    `size differences, or arena conditions. The JSON's "winningTeam" field MUST be ` +
    `"${v.winningTeam}".\n\n`
  );
}
