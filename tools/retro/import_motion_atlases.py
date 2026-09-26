#!/usr/bin/env python3
"""Register reviewed four-pose atlas cells without modifying raster pixels.

Metadata is an array of {key, path, ids}, with one creature per row and
idle/anticipation/attack/reaction in four columns. Measured connected alpha
bounds accommodate nonuniform generated spacing without altering pixels.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image
import numpy as np
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
POSES = ('idle', 'anticipation', 'attack', 'reaction')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('metadata', type=Path)
    args = parser.parse_args()
    manifest_path = ROOT / 'ios/WhoWouldWin/Retro/RetroSpriteManifest.json'
    manifest = json.loads(manifest_path.read_text())
    prepared = []
    for job in json.loads(args.metadata.read_text()):
        image = Image.open(job['path'])
        assert image.mode == 'RGBA', 'Real generated transparency is required'
        labels, count = ndimage.label(np.array(image)[:, :, 3] > 100)
        areas = np.bincount(labels.ravel())
        objects = ndimage.find_objects(labels)
        components = []
        for label in range(1, count + 1):
            if areas[label] > 1000:
                y, x = objects[label - 1]
                components.append((label, [x.start, y.start, x.stop, y.stop]))
        assert len(components) == len(job['ids']) * 4, (job['key'], 'missing or merged poses', len(components))
        components.sort(key=lambda part: part[1][3])
        ordered = []
        for row in range(len(job['ids'])):
            ordered.extend(sorted(components[row * 4:row * 4 + 4], key=lambda part: part[1][0]))
        entries = {}
        for row, aid in enumerate(job['ids']):
            assert aid in manifest['sprites'], aid
            frames = {}
            for col, pose in enumerate(POSES):
                label, (left, top, right, bottom) = ordered[row * 4 + col]
                assert min(left, top, image.width - right, image.height - bottom) >= 2, (aid, pose, 'clipped sheet')
                crop = labels[top - 1:bottom + 1, left - 1:right + 1]
                foreign = [int(value) for value in np.unique(crop)
                           if value not in (0, label) and areas[value] > 1000]
                assert not foreign, (aid, pose, 'neighboring creature pixels in crop', foreign)
                frames[pose] = [left - 1, top - 1, right - left + 2, bottom - top + 2]
            entries[aid] = {**manifest['sprites'][aid], 'asset': 'retro_' + job['key'], 'frames': frames}
        prepared.append((job, entries))
    # Validate every input before changing the checked-in manifest.
    for job, entries in prepared:
        folder = ROOT / 'ios/WhoWouldWin/Assets.xcassets' / ('retro_' + job['key'] + '.imageset')
        folder.mkdir(exist_ok=True)
        shutil.copyfile(job['path'], folder / 'sprites.png')
        (folder / 'Contents.json').write_text(json.dumps({
            'images': [{'filename': 'sprites.png', 'idiom': 'universal'}],
            'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
        manifest['sprites'].update(entries)
        print(json.dumps({'asset': job['key'], 'creatures': list(entries), 'poses': list(POSES),
                          'sha256': hashlib.sha256((folder / 'sprites.png').read_bytes()).hexdigest()}))
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
