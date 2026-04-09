#!/usr/bin/env python3
"""
Add rounded carnivore teeth (teardrop/canine style) to the AVA app icon.
Matches the reference: large outer curved canines + smaller round-tipped inner teeth.
"""
from PIL import Image, ImageDraw
import shutil

ICON   = "/Users/home/WWW/who-would-win/ios/WhoWouldWin/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
BACKUP = ICON.replace(".png", "_backup_teeth.png")

shutil.copy2(ICON, BACKUP)
print("Backed up to", BACKUP)

img = Image.open(ICON).convert("RGBA")
W, H = 1024, 1024

layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)

# ── Colors ────────────────────────────────────────────────────────────────────
GUM      = (150, 18, 35, 255)
GUM_RIM  = ( 90,  6, 16, 255)
GUM_TOP  = (195, 45, 65, 255)
IVORY    = (232, 218, 180, 255)
IVORY_HI = (252, 244, 212, 255)

GUM_H = 72   # gum band height

# ── Tooth shape helpers ───────────────────────────────────────────────────────

def tooth_down(d, cx, base_y, w, h, lean=0):
    """
    Rounded canine pointing DOWN.
    Body tapers from base → belly (widest) → rounded oval tip.
    lean: tip shifts this many px left/right.
    """
    top_hw  = w * 0.55   # half-width at gum line
    belly_hw = w * 0.58  # half-width at widest point (belly)
    belly_y = base_y + h * 0.40

    # tip ellipse
    tip_rx = w * 0.42
    tip_ry = w * 0.50
    tip_cx = cx + lean
    tip_cy = base_y + h - tip_ry

    # polygon: left side base → belly → down to tip ellipse edge
    pts = [
        (cx - top_hw,  base_y),
        (cx + top_hw,  base_y),
        (cx + belly_hw, belly_y),
        (tip_cx + tip_rx, tip_cy),
        (tip_cx - tip_rx, tip_cy),
        (cx - belly_hw, belly_y),
    ]
    d.polygon(pts, fill=IVORY)
    # rounded tip
    d.ellipse([tip_cx - tip_rx, tip_cy - tip_ry,
               tip_cx + tip_rx, tip_cy + tip_ry], fill=IVORY)

    # subtle highlight stripe (left of center, contained well inside)
    hi_x = cx - w * 0.20
    hi_hw = w * 0.11
    hi = [
        (hi_x - hi_hw, base_y + h * 0.06),
        (hi_x + hi_hw, base_y + h * 0.06),
        (hi_x + hi_hw * 0.5 + lean * 0.5, base_y + h * 0.62),
        (hi_x - hi_hw * 0.5 + lean * 0.5, base_y + h * 0.62),
    ]
    d.polygon(hi, fill=IVORY_HI)


def tooth_up(d, cx, base_y, w, h, lean=0):
    """
    Rounded canine pointing UP (bottom jaw).
    """
    top_hw   = w * 0.55
    belly_hw = w * 0.58
    belly_y  = base_y - h * 0.40

    tip_rx = w * 0.42
    tip_ry = w * 0.50
    tip_cx = cx + lean
    tip_cy = base_y - h + tip_ry

    pts = [
        (cx - top_hw,  base_y),
        (cx + top_hw,  base_y),
        (cx + belly_hw, belly_y),
        (tip_cx + tip_rx, tip_cy),
        (tip_cx - tip_rx, tip_cy),
        (cx - belly_hw, belly_y),
    ]
    d.polygon(pts, fill=IVORY)
    d.ellipse([tip_cx - tip_rx, tip_cy - tip_ry,
               tip_cx + tip_rx, tip_cy + tip_ry], fill=IVORY)

    hi_x = cx - w * 0.20
    hi_hw = w * 0.11
    hi = [
        (hi_x - hi_hw, base_y - h * 0.06),
        (hi_x + hi_hw, base_y - h * 0.06),
        (hi_x + hi_hw * 0.5 + lean * 0.5, base_y - h * 0.62),
        (hi_x - hi_hw * 0.5 + lean * 0.5, base_y - h * 0.62),
    ]
    d.polygon(hi, fill=IVORY_HI)


# ── Top gum band ──────────────────────────────────────────────────────────────
d.rectangle([0,      0,      W, GUM_H],       fill=GUM)
d.rectangle([0,      0,      W, 18],           fill=GUM_TOP)   # lighter lip top
d.rectangle([0, GUM_H-16,    W, GUM_H],        fill=GUM_RIM)   # dark rim at base

# ── Top teeth ─────────────────────────────────────────────────────────────────
# 2 big outer canines + 5 smaller round teeth inside (from reference)
# (cx, width, height, lean)
top = [
    (  88,  96, 260,  14),   # BIG outer-left canine (leans right)
    ( 222,  72, 165,   5),
    ( 318,  65, 148,   3),
    ( 404,  58, 132,   1),
    ( 512,  54, 120,   0),   # center
    ( 620,  58, 132,  -1),
    ( 706,  65, 148,  -3),
    ( 802,  72, 165,  -5),
    ( 936,  96, 260, -14),   # BIG outer-right canine (leans left)
]
for cx, w, h, lean in top:
    tooth_down(d, cx, GUM_H, w, h, lean)

# ── Bottom gum band ───────────────────────────────────────────────────────────
bot_y = H - GUM_H
d.rectangle([0, bot_y,   W, H],        fill=GUM)
d.rectangle([0, H - 18,  W, H],        fill=GUM_TOP)
d.rectangle([0, bot_y,   W, bot_y+16], fill=GUM_RIM)

# ── Bottom teeth ──────────────────────────────────────────────────────────────
# Reference: 2 medium canines near edges + 2 small center teeth + gap in middle
bot = [
    ( 172,  85, 210,  10),   # left canine
    ( 310,  62, 148,   4),   # inner left
    ( 448,  52, 122,   2),   # center-left small
    ( 576,  52, 122,  -2),   # center-right small
    ( 714,  62, 148,  -4),   # inner right
    ( 852,  85, 210, -10),   # right canine
]
for cx, w, h, lean in bot:
    tooth_up(d, cx, bot_y, w, h, lean)

# ── Composite & save ──────────────────────────────────────────────────────────
result = Image.alpha_composite(img, layer)
result.save(ICON)
print("Saved to", ICON)
