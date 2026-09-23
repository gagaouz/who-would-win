// Winner-picking: deterministic, order-independent, and realistic.
delete process.env.DATABASE_URL;
delete process.env.DATABASE_PRIVATE_URL;

const test = require('node:test');
const assert = require('node:assert/strict');

const { CREATURES } = require('../dist/data/creatures');
const { resolveBattle } = require('../dist/services/battleResolver');
const { resolveMelee } = require('../dist/services/meleeResolver');

const ARENAS = [undefined, 'Grassland', 'Ocean', 'Sky', 'Arctic', 'Desert', 'Jungle', 'Volcano', 'Night', 'Storm'];
const ids = CREATURES.map(c => c.id);

function winner(a, b, env) {
  const v = resolveBattle({ fighter1Id: a, fighter2Id: b, environmentName: env });
  assert.equal(v.kind, 'forced', `${a} vs ${b} in ${env} should be decided by the referee`);
  return v.winnerId;
}

test('every built-in matchup in every arena has one fixed winner, whichever side it is on', () => {
  for (const env of ARENAS) {
    for (let i = 0; i < ids.length; i++) {
      for (let j = i + 1; j < ids.length; j++) {
        const w1 = winner(ids[i], ids[j], env);
        const w2 = winner(ids[j], ids[i], env);
        assert.equal(w1, w2, `${ids[i]} vs ${ids[j]} in ${env ?? 'no arena'}`);
      }
    }
  }
});

test('realistic outcomes', () => {
  const cases = [
    ['tiger', 'lion', undefined, 'tiger'],
    ['wolf', 'great_dane', undefined, 'wolf'],
    ['great_dane', 'beagle', undefined, 'great_dane'],
    ['elephant', 'great_dane', undefined, 'elephant'],
    ['tabby_cat', 'hamster', undefined, 'tabby_cat'],
    ['goldfish', 'horse', 'Ocean', 'goldfish'],        // the horse can't breathe underwater
    ['goldfish', 'hamster', 'Grassland', 'hamster'],   // the goldfish is stranded
    ['parakeet', 'tabby_cat', 'Sky', 'parakeet'],       // the cat can't fly
    ['dragon', 'chicken', 'Sky', 'dragon'],
    ['orca', 'lion', 'Ocean', 'orca'],
    ['lion', 'orca', 'Grassland', 'lion'],
    ['harpy_eagle', 'army_ant', undefined, 'harpy_eagle'],
    ['zeus', 'dragon', undefined, 'zeus'],
  ];
  for (const [a, b, env, expected] of cases) {
    assert.equal(winner(a, b, env), expected, `${a} vs ${b} in ${env ?? 'no arena'}`);
  }
});

test('Zeus beats every other god (ties used to go alphabetically, so Zeus lost to all of them)', () => {
  for (const god of ['kronos', 'poseidon', 'hades', 'athena', 'apollo', 'hercules', 'ares', 'artemis', 'hephaestus', 'hermes', 'medusa']) {
    assert.equal(winner('zeus', god), 'zeus', god);
  }
  assert.equal(winner('athena', 'ares'), 'athena');
  assert.equal(winner('hercules', 'ares'), 'hercules');
});

test('custom fighters: estimated tiers are decided, missing estimates go to the AI', () => {
  const decided = resolveBattle({ fighter1Id: 'wolf', fighter2Id: 'c0ffee00-0000-4000-8000-000000000000', customTier2: 1 });
  assert.equal(decided.kind, 'forced');
  assert.equal(decided.winnerId, 'wolf');
  const open = resolveBattle({ fighter1Id: 'wolf', fighter2Id: 'c0ffee00-0000-4000-8000-000000000000' });
  assert.equal(open.kind, 'open');
});

test('melee: swapping sides mirrors the result; a god wins; arena applies to pets', () => {
  const team = (...xs) => xs.map(id => ({ id }));
  for (const env of ARENAS) {
    const ab = resolveMelee({ teamA: team('lion', 'wolf'), teamB: team('grizzly_bear'), environmentName: env });
    const ba = resolveMelee({ teamA: team('grizzly_bear'), teamB: team('lion', 'wolf'), environmentName: env });
    assert.notEqual(ab.winningTeam, ba.winningTeam, `mirror in ${env}`);
  }
  assert.equal(resolveMelee({ teamA: team('hermes'), teamB: team('dragon', 'kraken') }).winningTeam, 'A');
  assert.equal(resolveMelee({ teamA: team('goldfish', 'betta_fish'), teamB: team('hamster'), environmentName: 'Desert' }).winningTeam, 'B');
});
