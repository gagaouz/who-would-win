#!/usr/bin/env python3
"""Validate source rectangles and catalog coverage; never rewrites artwork."""
import argparse
import itertools
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--require-complete', action='store_true')
args = parser.parse_args()
roster = json.loads((ROOT / 'backend/src/data/creatures.json').read_text())
manifest = json.loads((ROOT / 'ios/WhoWouldWin/Retro/RetroSpriteManifest.json').read_text())
known = {a['id'] for a in roster}
assert len(known) == len(roster), 'duplicate catalog IDs'
assert manifest['styleVersion'] == 'retro-v1'
sprites = manifest['sprites']
assert not set(sprites) - known, f'Unknown sprite IDs: {set(sprites) - known}'
custom_bases = manifest.get('customBases', {})
expected_custom = {'robot', 'knight', 'wizard', 'superhero', 'slime', 'mushroom',
                   'tree', 'alien', 'wingedcat', 'rockgolem', 'seaserpent', 'ghost'}
if args.require_complete:
    assert set(custom_bases) == expected_custom, 'Incomplete local custom avatar kit'
assets = ROOT / 'ios/WhoWouldWin/Assets.xcassets'
opened = {}
rectangles = {}
authored_by_section = {'sprites': [], 'customBases': []}
for aid, entry in {**sprites, **{'custom:' + key: value for key, value in custom_bases.items()}}.items():
    assert entry['archetype'] in {'quadruped', 'primate', 'flyer', 'swimmer', 'serpentine', 'arthropod', 'biped'}, aid
    assert 'idle' in entry['frames'], f'{aid}: missing ready sprite'
    source = ROOT / 'ios/WhoWouldWin/Resources/RetroAtlases' / (entry['asset'] + '.png')
    if not source.exists():
        folder = assets / (entry['asset'] + '.imageset')
        metadata = json.loads((folder / 'Contents.json').read_text())
        source = folder / next(i['filename'] for i in metadata['images'] if 'filename' in i)
    if source not in opened:
        im = Image.open(source)
        assert im.mode == 'RGBA', f'{source}: needs real transparency'
        assert im.width <= 4096 and im.height <= 4096, source
        opened[source] = im
    im = opened[source]
    pose_pixels = []
    for pose, rect in entry['frames'].items():
        assert pose in {'idle', 'anticipation', 'attack', 'reaction'}, (aid, pose)
        assert len(rect) == 4 and all(type(n) is int for n in rect), (aid, pose)
        x, y, w, h = rect
        assert x >= 0 and y >= 0 and w > 0 and h > 0 and x + w <= im.width and y + h <= im.height, (aid, pose, rect)
        alpha = im.getchannel('A').crop((x, y, x+w, y+h))
        counts = alpha.histogram()
        assert sum(counts[128:]) > w*h*.03, f'{aid}/{pose}: blank crop'
        assert sum(counts[:16]) > w*h*.02, f'{aid}/{pose}: lacks transparent padding'
        trimmed = im.crop((x, y, x+w, y+h))
        trimmed = trimmed.crop(trimmed.getchannel('A').getbbox())
        pose_pixels.append((trimmed.size, hashlib.sha256(trimmed.tobytes()).hexdigest()))
        rectangles.setdefault(source, []).append((f'{aid}/{pose}', rect))
    if set(entry['frames']) == {'idle', 'anticipation', 'attack', 'reaction'} and len(set(pose_pixels)) == 4:
        authored_by_section['customBases' if aid.startswith('custom:') else 'sprites'].append(aid)
    elif args.require_complete:
        raise AssertionError(f'{aid}: all four distinct authored poses are required')
for source, entries in rectangles.items():
    alpha = opened[source].getchannel('A')
    for (name_a, a), (name_b, b) in itertools.combinations(entries, 2):
        x, y = max(a[0], b[0]), max(a[1], b[1])
        right, bottom = min(a[0] + a[2], b[0] + b[2]), min(a[1] + a[3], b[1] + b[3])
        if right > x and bottom > y:
            shared = sum(alpha.crop((x, y, right, bottom)).histogram()[128:])
            assert shared == 0, f'{name_a}/{name_b}: overlapping sprite crops include opaque pixels'
icon_folder = assets / 'AppIcon.appiconset'
icon_metadata = json.loads((icon_folder / 'Contents.json').read_text())
icon = Image.open(icon_folder / icon_metadata['images'][0]['filename'])
assert icon.size == (1024, 1024), 'App icon must be 1024 square'
assert icon.mode == 'RGB' or (icon.mode == 'RGBA' and icon.getchannel('A').getextrema() == (255, 255)), 'App icon must be opaque'
missing = sorted(known - set(sprites))
print(json.dumps({'catalog': len(known), 'covered': len(sprites), 'customBases': len(custom_bases),
                  'atlases': len(opened), 'authoredPoseSets': len(authored_by_section['sprites']),
                  'authoredCustomPoseSets': len(authored_by_section['customBases']), 'missing': missing}, indent=2))
if args.require_complete and missing:
    raise SystemExit('Release blocked: incomplete retro artwork')
