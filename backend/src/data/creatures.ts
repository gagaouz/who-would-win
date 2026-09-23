/**
 * Master creature list — the ONE source of truth for every built-in fighter.
 *
 * `creatures.json` holds each creature's display name, habitat, power tier and
 * a short kid-safe profile. The server's resolvers and prompts read it here;
 * the iOS app's OnDeviceTiers.swift is GENERATED from the same file by
 * `scripts/sync_creatures.mjs` (which also checks the iOS roster matches).
 * Add or change a creature in the JSON, never in code.
 */
import raw from './creatures.json';

export type Habitat = 'land' | 'sea' | 'air' | 'deity';

export interface Creature {
  id: string;
  name: string;
  /** Picker group, mirrors the iOS `AnimalCategory`. */
  group: string;
  habitat: Habitat;
  /** 1 = tiny bug … 10 = god. */
  tier: number;
  /** Fractional realism nudge within a tier (|adjust| < 1). */
  adjust?: number;
  /** A land creature with working wings (dragon, griffin…). */
  flies?: boolean;
  /** A land/air creature that also swims well (hippo, crocodile, duck…). */
  swims?: boolean;
  /** Adapted to snow and ice. */
  arctic?: boolean;
  /** Size + standout real ability, written for the prompt. Kid-safe wording. */
  blurb: string;
  /** One hand-checked, kid-friendly fact (the same text as the app's
   *  AnimalFacts.swift coolFact — sync_creatures.mjs checks they match). */
  fact: string;
}

const HABITATS: ReadonlySet<string> = new Set(['land', 'sea', 'air', 'deity']);

function load(entries: unknown): readonly Creature[] {
  if (!Array.isArray(entries)) throw new Error('creatures.json must be an array');
  const seen = new Set<string>();
  for (const c of entries as Creature[]) {
    if (!/^[a-z0-9_]+$/.test(c.id) || seen.has(c.id)) throw new Error(`creatures.json: bad or duplicate id "${c.id}"`);
    if (!c.name || !c.blurb || !c.fact || !HABITATS.has(c.habitat)) throw new Error(`creatures.json: incomplete entry "${c.id}"`);
    if (!Number.isInteger(c.tier) || c.tier < 1 || c.tier > 10) throw new Error(`creatures.json: bad tier for "${c.id}"`);
    if (c.adjust !== undefined && Math.abs(c.adjust) >= 1) throw new Error(`creatures.json: adjust must be < 1 for "${c.id}"`);
    seen.add(c.id);
  }
  return entries as Creature[];
}

export const CREATURES: readonly Creature[] = load(raw);

const BY_ID = new Map(CREATURES.map(c => [c.id, c]));

export function getCreature(id: string): Creature | undefined {
  return BY_ID.get(id);
}

/** True for any of the app's built-in fighters (custom creatures use UUID ids). */
export function isBuiltIn(id: string): boolean {
  return BY_ID.has(id);
}

export const DEITY_IDS: ReadonlySet<string> = new Set(
  CREATURES.filter(c => c.habitat === 'deity').map(c => c.id));

export function isDeity(id: string): boolean {
  return DEITY_IDS.has(id);
}

/** The name kids see. Built-ins always use the master name; anything else uses
 *  the supplied (already sanitized) name, never a raw id. */
export function displayName(id: string, suppliedName?: string): string {
  return BY_ID.get(id)?.name ?? suppliedName ?? id.replace(/_/g, ' ');
}

/** Tier + realism nudge, or null for a custom/unknown fighter. */
export function effectiveTier(id: string): number | null {
  const c = BY_ID.get(id);
  return c ? c.tier + (c.adjust ?? 0) : null;
}

const LAND_ARENAS: ReadonlySet<string> = new Set(['Grassland', 'Jungle', 'Volcano', 'Desert', 'Arctic']);

export function isLandArena(environmentName: string | undefined): boolean {
  return environmentName !== undefined && LAND_ARENAS.has(environmentName);
}

/**
 * Arena effectiveness (0 = can't function, 1 = home turf). The ONLY copy on the
 * server — both resolvers call this, and the iOS OnDeviceResolver mirrors it.
 *   Ocean (fully underwater): sea 1.0 · swimmers 0.5 · everyone else drowns 0.10
 *   Sky: air creatures and winged land creatures 1.0 · everyone else falls 0.05
 *   Land arenas: land 1.0 · air 0.85 · sea creatures are beached 0.05
 *   Night / Storm / no arena: 1.0
 * Custom creatures (unknown habitat) get mild, neutral-ish values.
 */
export function envModifier(id: string, environmentName: string | undefined): number {
  if (!environmentName) return 1.0;
  const c = BY_ID.get(id);
  if (c?.habitat === 'deity') return 1.0;
  if (!c) {
    if (environmentName === 'Ocean') return 0.6;
    if (environmentName === 'Sky') return 0.5;
    if (LAND_ARENAS.has(environmentName)) return 0.9;
    return 1.0;
  }
  if (environmentName === 'Ocean') {
    if (c.habitat === 'sea') return 1.0;
    if (c.swims) return 0.5;
    return 0.10;
  }
  if (environmentName === 'Sky') {
    if (c.habitat === 'air' || c.flies) return 1.0;
    return 0.05;
  }
  if (LAND_ARENAS.has(environmentName)) {
    if (c.habitat === 'sea') return 0.05;
    if (c.habitat === 'air') return 0.85;
    return 1.0;
  }
  return 1.0;
}

/** Prompt note describing how the arena affects this fighter ('' = no issue).
 *  Mirrors envModifier so the story never contradicts the referee. */
export function survivalWarning(id: string, name: string, environmentName: string): string {
  const c = BY_ID.get(id);
  if (!c || c.habitat === 'deity') return '';
  if (environmentName === 'Ocean' && c.habitat !== 'sea') {
    return c.swims
      ? `NOTE: ${name} can swim, but deep open ocean is not its home — it is much slower and weaker here.\n`
      : `SURVIVAL WARNING: ${name} is not built for deep water and cannot keep up here — a near-certain loss. Keep it safe in the story: it paddles back to shore.\n`;
  }
  if (environmentName === 'Sky' && c.habitat !== 'air' && !c.flies) {
    return `SURVIVAL WARNING: ${name} cannot fly, so it can't keep up in a sky battle — a near-certain loss. Keep it safe in the story: it drifts gently down to a soft landing.\n`;
  }
  if (isLandArena(environmentName) && c.habitat === 'sea') {
    return `SURVIVAL WARNING: ${name} is a water animal — on land it can barely move, a near-certain loss. Keep it safe in the story: it wriggles back to the water.\n`;
  }
  if (environmentName === 'Arctic' && c.habitat === 'land' && !c.arctic) {
    return `NOTE: ${name} is not built for snow and ice and will struggle with the cold.\n`;
  }
  return '';
}
