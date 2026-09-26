#!/usr/bin/env python3
"""Import reviewed atlas PNGs unchanged and measure isolated alpha bounds.

Requires Pillow, numpy and scipy. Source metadata supplies ordered IDs and
optional archetypes; no raster pixels are rewritten by this tool.
"""
import argparse
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('metadata', type=Path)
parser.add_argument('--section', default='sprites', choices=['sprites', 'customBases'])
parser.add_argument('--skip', nargs='*', default=[])
args = parser.parse_args()
manifest_path = ROOT / 'ios/WhoWouldWin/Retro/RetroSpriteManifest.json'
manifest = json.loads(manifest_path.read_text())
target = manifest.setdefault(args.section, {})
for job in json.loads(args.metadata.read_text()):
    im = Image.open(job['path'])
    assert im.mode == 'RGBA'
    labels, count = ndimage.label(np.array(im)[:, :, 3] > 100)
    areas = np.bincount(labels.ravel())
    objects = ndimage.find_objects(labels)
    parts = []
    for label in range(1, count + 1):
        if areas[label] > 1000:
            y, x = objects[label - 1]
            parts.append((label, [x.start, y.start, x.stop, y.stop]))
    assert len(parts) == len(job['ids']), (job['key'], len(parts))
    parts.sort(key=lambda part: part[1][3])
    ordered = []
    columns = job.get('columns', 2)
    for i in range(0, len(parts), columns):
        ordered.extend(sorted(parts[i:i + columns], key=lambda part: part[1][0]))
    asset = 'retro_' + job['key']
    folder = ROOT / 'ios/WhoWouldWin/Assets.xcassets' / (asset + '.imageset')
    folder.mkdir(exist_ok=True)
    shutil.copyfile(job['path'], folder / 'sprites.png')
    (folder / 'Contents.json').write_text(json.dumps({
        'images': [{'filename': 'sprites.png', 'idiom': 'universal'}],
        'info': {'author': 'xcode', 'version': 1},
    }, indent=2) + '\n')
    for index, (aid, (label, bounds)) in enumerate(zip(job['ids'], ordered)):
        if aid in args.skip:
            continue
        x, y, right, bottom = bounds
        x, y = max(0, x - 1), max(0, y - 1)
        right, bottom = min(im.width, right + 1), min(im.height, bottom + 1)
        crop = labels[y:bottom, x:right]
        foreign = [int(value) for value in np.unique(crop)
                   if value not in (0, label) and areas[value] > 1000]
        assert not foreign, (aid, 'contains neighboring creature pixels', foreign)
        entry = target.get(aid, {})
        entry.update(asset=asset, frames={'idle': [x, y, right - x, bottom - y]})
        if 'archetypes' in job:
            entry['archetype'] = job['archetypes'][index]
        assert 'archetype' in entry, aid
        target[aid] = entry
        print(aid, entry['frames']['idle'])
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
