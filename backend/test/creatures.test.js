// Master creature list + cross-platform sync. Runs against the compiled dist/.
delete process.env.DATABASE_URL;
delete process.env.DATABASE_PRIVATE_URL;

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const { CREATURES, displayName, envModifier, survivalWarning } = require('../dist/data/creatures');
const { storyProblem } = require('../dist/middleware/sanitize');

const repoRoot = path.join(__dirname, '..', '..');

test('master list has 143 complete, unique creatures', () => {
  assert.equal(CREATURES.length, 143);
  assert.equal(new Set(CREATURES.map(c => c.id)).size, 143);
  for (const c of CREATURES) {
    assert.ok(c.name && c.blurb, c.id);
    assert.ok(['land', 'sea', 'air', 'deity'].includes(c.habitat), c.id);
    assert.ok(Number.isInteger(c.tier) && c.tier >= 1 && c.tier <= 10, c.id);
  }
});

test('every built-in shows its real name, never an id', () => {
  assert.equal(displayName('tabby_cat'), 'Tabby Cat');
  assert.equal(displayName('great_dane', 'ignored client name'), 'Great Dane');
  assert.equal(displayName('3f1c-uuid', 'Gravedigger Beetle'), 'Gravedigger Beetle');
  for (const c of CREATURES) assert.ok(!displayName(c.id).includes('_'), c.id);
});

test('profile blurbs and verified facts follow the kid-safe story rules', () => {
  for (const c of CREATURES) {
    assert.equal(storyProblem(c.blurb, 'narration', [c.name]), null, `${c.id}: ${c.blurb}`);
    assert.equal(storyProblem(c.fact, 'fact', [c.name]), null, `${c.id}: ${c.fact}`);
  }
});

test('arena rules cover pets, farm and fantasy creatures', () => {
  assert.equal(envModifier('horse', 'Ocean'), 0.10);        // can't breathe underwater
  assert.equal(envModifier('goldfish', 'Grassland'), 0.05); // stranded on land
  assert.equal(envModifier('tabby_cat', 'Sky'), 0.05);      // can't fly
  assert.equal(envModifier('parakeet', 'Sky'), 1.0);
  assert.equal(envModifier('dragon', 'Sky'), 1.0);          // winged land creature
  assert.equal(envModifier('duck', 'Ocean'), 0.5);          // swims
  assert.equal(envModifier('zeus', 'Ocean'), 1.0);
  assert.equal(envModifier('lion', undefined), 1.0);
  assert.match(survivalWarning('horse', 'Horse', 'Ocean'), /not built for deep water.*paddles back to shore/);
  assert.match(survivalWarning('goldfish', 'Goldfish', 'Desert'), /water animal/);
  assert.equal(survivalWarning('orca', 'Orca', 'Ocean'), '');
});

const iosRoster = path.join(repoRoot, 'ios/WhoWouldWin/Data/Animals.swift');
test('iOS roster and OnDeviceTiers.swift match the master list', { skip: !fs.existsSync(iosRoster) }, () => {
  // Throws (non-zero exit) with a list of every mismatch.
  execFileSync(process.execPath, [path.join(repoRoot, 'scripts/sync_creatures.mjs'), '--check'], { stdio: 'pipe' });
});
