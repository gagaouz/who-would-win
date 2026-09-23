// Story safety checks, prompt wording, retries and rematch rotation.
delete process.env.DATABASE_URL;
delete process.env.DATABASE_PRIVATE_URL;

const test = require('node:test');
const assert = require('node:assert/strict');

const { storyProblem, sanitizeName } = require('../dist/middleware/sanitize');
const {
  validateResult, generateValidated, StoryRejectedError, buildUserPrompt, buildQuickUserPrompt,
} = require('../dist/services/claudeService');
const { nextStoryVariant } = require('../dist/services/responseStore');
const { resolveBattle } = require('../dist/services/battleResolver');

test('harmless story words are allowed (they used to throw the whole story away)', () => {
  for (const text of [
    'The Maine Coon pounces from the shadows!',
    'A loud crack of thunder echoes across the arena.',
    'The falcon comes shooting across the sky.',
    'The boar sniffs out mushrooms before charging.',
    'The owl cocks its head and dives.',
  ]) {
    assert.equal(storyProblem(text, 'narration'), null, text);
  }
});

test('injury and death words are refused in battle stories', () => {
  for (const text of [
    'The shark bites down and blood fills the water.',
    'The lion kills the zebra.',
    'A bone-crushing bite ends it.',
    'The wolf rips apart its rival.',
    'The bear mauls the moose.',
    'Seawater floods its lungs and it starts drowning.',
    'The ocean is instantly fatal to the lion.',
    'The tiny beetle has nowhere to hide from teeth that can crush bone.',
  ]) {
    assert.notEqual(storyProblem(text, 'narration'), null, text);
  }
});

test('fun facts may mention real biology like extinction or blood', () => {
  assert.equal(storyProblem('The dodo died out about 350 years ago.', 'fact'), null);
  assert.equal(storyProblem('Mosquitoes drink blood to lay their eggs.', 'fact'), null);
  assert.notEqual(storyProblem('What the hell was that?', 'fact'), null);
  assert.notEqual(storyProblem('Its bite is strong enough to snap through bone.', 'fact'), null);
  assert.notEqual(storyProblem('Strong enough to snap through the thickest bones.', 'fact'), null);
  assert.equal(storyProblem('Birds have hollow bones that make them light enough to fly.', 'fact'), null);
  assert.equal(storyProblem('A crack of thunder echoes as the bones of the old tree creak.', 'narration'), null);
  assert.equal(storyProblem('Killer whales are really the largest dolphins.', 'fact'), null);
});

test('game jargon never reaches kids', () => {
  assert.notEqual(storyProblem("The Grizzly Bear's tier-7 power wins.", 'fact'), null);
  assert.notEqual(storyProblem('Both are the same weight and tier.', 'narration'), null);
  assert.equal(storyProblem('The tiered cake of clouds parts as the Phoenix rises.', 'narration'), null);
});

test('a kid-typed name is allowed inside its own story', () => {
  assert.notEqual(storyProblem('The Death Adder strikes first!', 'narration'), null);
  assert.equal(storyProblem('The Death Adder strikes first!', 'narration', ['Death Adder']), null);
});

test('names: notorious people, hate groups and weapons are blocked; real animals are not', () => {
  for (const bad of ['Hitler', 'Nazi Wolf', 'Osama Bin Laden', 'Ku Klux Klan', 'Ted Bundy', 'AK-47', 'Machine Gun', 'Big Bomb']) {
    assert.equal(sanitizeName(bad).ok, false, bad);
  }
  for (const ok of ['Pistol Shrimp', 'Knife Fish', 'Isis', 'Bundy the Bear', 'Bombardier Beetle', 'Gunnar']) {
    assert.equal(sanitizeName(ok).ok, true, ok);
  }
});

test('names: "Maine Coon" is fine, the slur alone is not', () => {
  assert.equal(sanitizeName('Maine Coon').ok, true);
  assert.equal(sanitizeName('coon').ok, false);
});

const good = {
  winner: 'orca',
  narration: 'The Orca launches out of the deep with a thunderous splash. It dodges, spins and pins the Great White Shark with a huge body check. The crowd erupts as the Orca rises tall!',
  funFact: 'Orcas are actually the largest members of the dolphin family.',
  why: 'The Orca is five times heavier and much smarter.',
  winnerHealthPercent: 80,
  loserHealthPercent: 20,
};

test('validateResult keeps a good story and drops an unsafe "why"', () => {
  const ok = validateResult(good, 'orca', 'great_white_shark', ['Orca', 'Great White Shark']);
  assert.equal(ok.narration, good.narration);
  assert.equal(ok.why, good.why);
  const badWhy = validateResult({ ...good, why: 'Its deadly bite ends it.' }, 'orca', 'great_white_shark');
  assert.equal(badWhy.why, undefined);
});

test('validateResult rejects an injury story so it can be rewritten', () => {
  assert.throws(
    () => validateResult({ ...good, narration: 'The Orca tears into the shark and blood spreads.' }, 'orca', 'great_white_shark'),
    StoryRejectedError);
});

test('one bad sentence is dropped instead of throwing the whole story away', () => {
  const r = validateResult({
    ...good,
    narration: 'The Orca charges in with a huge splash. It lands a bone-crushing hit. The Orca dodges and pins the shark. The crowd erupts!',
    funFact: 'Orcas are the largest dolphins. Their bite can snap bones.',
  }, 'orca', 'great_white_shark');
  assert.equal(r.narration, 'The Orca charges in with a huge splash. The Orca dodges and pins the shark. The crowd erupts!');
  assert.equal(r.funFact, 'Orcas are the largest dolphins.');
});

test('an unsafe story is regenerated once; other errors are not retried', async () => {
  let calls = 0;
  let note;
  const value = await generateValidated('test', async (retryNote) => { note = retryNote; return ++calls === 1 ? 'bad' : 'good'; },
    text => { if (text === 'bad') throw new StoryRejectedError('narration word:blood'); return text; });
  assert.equal(value, 'good');
  assert.equal(calls, 2);
  assert.match(note, /rejected \(narration word:blood\)/);

  let apiCalls = 0;
  await assert.rejects(generateValidated('test', async () => { apiCalls++; throw new Error('API down'); }, t => t));
  assert.equal(apiCalls, 1);

  let rejects = 0;
  await assert.rejects(generateValidated('test', async () => { rejects++; return 'x'; },
    () => { throw new StoryRejectedError('still unsafe'); }), StoryRejectedError);
  assert.equal(rejects, 2);
});

test('prompts use real names, the solo rule and the new tone rules', () => {
  const verdict = resolveBattle({ fighter1Id: 'great_dane', fighter2Id: 'tabby_cat' });
  const full = buildUserPrompt('great_dane', 'tabby_cat', undefined, undefined, undefined, undefined, verdict);
  assert.match(full, /Great Dane vs Tabby Cat/);
  assert.match(full, /Great Dane WINS/);
  assert.doesNotMatch(full, /great_dane vs/);
  assert.match(full, /ONE-ON-ONE/);
  assert.doesNotMatch(full, /gores|rips,|bone-shattering bite"/);
  const quick = buildQuickUserPrompt('horse', 'goldfish', undefined, undefined, 'Ocean');
  assert.match(quick, /Horse is not built for deep water/);
});

test('rematches rotate through different stories', async () => {
  const key = { fighter1: 'lion', fighter2: 'tiger' };
  const slots = [];
  for (let i = 0; i < 4; i++) slots.push(await nextStoryVariant('test-rotation', key, 60_000));
  assert.deepEqual(slots, [0, 1, 2, 0]);
});
