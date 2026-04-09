#!/usr/bin/env python3
"""
Remove white backgrounds from all creature_*.png assets.
Uses BFS flood-fill from all 4 corners with a colour tolerance.
Edges are then softened so the cutout blends like an emoji.
"""
import glob, os
from PIL import Image
import numpy as np
from collections import deque

TOLERANCE = 28       # how close to white a pixel must be to count as background
FEATHER   = 1        # pixels of edge-feather after removal (0 = hard edge)

def is_bg(pixel, tol):
    r, g, b = int(pixel[0]), int(pixel[1]), int(pixel[2])
    return r >= 255 - tol and g >= 255 - tol and b >= 255 - tol

def flood_fill_mask(arr, tol):
    """BFS from the four corners; returns a boolean mask of background pixels."""
    H, W = arr.shape[:2]
    visited = np.zeros((H, W), dtype=bool)
    q = deque()

    # Seed from every border pixel that qualifies as background
    for row in [0, H - 1]:
        for col in range(W):
            if not visited[row, col] and is_bg(arr[row, col], tol):
                visited[row, col] = True
                q.append((row, col))
    for col in [0, W - 1]:
        for row in range(H):
            if not visited[row, col] and is_bg(arr[row, col], tol):
                visited[row, col] = True
                q.append((row, col))

    # BFS
    while q:
        r, c = q.popleft()
        for dr, dc in ((-1,0),(1,0),(0,-1),(0,1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < H and 0 <= nc < W and not visited[nr, nc] and is_bg(arr[nr, nc], tol):
                visited[nr, nc] = True
                q.append((nr, nc))

    return visited

def remove_white_bg(path):
    img = Image.open(path).convert("RGBA")
    arr = np.array(img, dtype=np.uint8)

    mask = flood_fill_mask(arr, TOLERANCE)

    # Zero out alpha for background pixels
    arr[mask, 3] = 0

    # Light feather: reduce alpha near bg edges so hard fringing is minimised
    if FEATHER > 0:
        from PIL import ImageFilter
        alpha = Image.fromarray(arr[:, :, 3], mode="L")
        alpha = alpha.filter(ImageFilter.GaussianBlur(radius=FEATHER))
        arr[:, :, 3] = np.array(alpha)
        # Re-zero pixels the flood fill marked as fully transparent
        arr[mask, 3] = 0

    result = Image.fromarray(arr, "RGBA")
    result.save(path, "PNG")

# ── Run on all creature assets ────────────────────────────────────────────────
assets = glob.glob(
    "/Users/home/WWW/who-would-win/ios/WhoWouldWin/Assets.xcassets/creature_*.imageset/creature_*.png"
)
assets.sort()
print(f"Processing {len(assets)} images...")
for p in assets:
    remove_white_bg(p)
    name = os.path.basename(p)
    print(f"  ✓ {name}")

print("\nDone.")
