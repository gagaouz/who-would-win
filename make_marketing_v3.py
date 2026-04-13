"""
Professional CoC-style marketing screenshots — v3
- REUSES existing DALL-E art from marketing_v2 (no new API calls)
- Luckiest Guy font for headlines (pro game font)
- Bebas Neue for sub-text
- Semi-transparent dark pill/panel behind text
- 3–5 words per headline max
- Thick yellow stroke on white text = CoC signature look
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
import os

W, H = 1290, 2796

SRC  = "/Users/home/Desktop/BeastClash_Screenshots/marketing_v2"
OUT  = "/Users/home/Desktop/BeastClash_Screenshots/marketing_v3"
os.makedirs(OUT, exist_ok=True)

# ── Fonts ────────────────────────────────────────────────────────────────────
LUCKIEST   = "/tmp/LuckiestGuy.ttf"
BEBAS      = "/tmp/BebasNeue.ttf"

def fnt(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception as e:
        print(f"  ⚠ Font load failed ({e}), using default")
        return ImageFont.load_default()

# ── Text helpers ──────────────────────────────────────────────────────────────

def text_size(font, text):
    bb = font.getbbox(text)
    return bb[2] - bb[0], bb[3] - bb[1]

def draw_headline(img, lines, cy, font,
                  text_color=(255, 255, 255),
                  stroke_color=(20, 10, 0),
                  stroke=18,
                  panel=True,
                  panel_color=(0, 0, 0, 160)):
    """
    Draw CoC-style headline centred at vertical position cy.
    Optionally draws a rounded-rect dark panel behind the text first.
    Returns the bottom y of the drawn block.
    """
    draw = ImageDraw.Draw(img)
    lh = font.getbbox("Ag")[3] + 28
    total_h = len(lines) * lh

    # Build panel if requested
    if panel:
        max_w = max(text_size(font, l)[0] for l in lines)
        pad_x, pad_y = 60, 30
        px1 = W // 2 - max_w // 2 - pad_x
        py1 = cy - pad_y
        px2 = W // 2 + max_w // 2 + pad_x
        py2 = cy + total_h + pad_y

        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.rounded_rectangle([px1, py1, px2, py2],
                              radius=40, fill=panel_color)
        img = Image.alpha_composite(img, overlay)
        draw = ImageDraw.Draw(img)

    y = cy
    for line in lines:
        tw, _ = text_size(font, line)
        x = W // 2 - tw // 2
        # Thick stroke
        for dx in range(-stroke, stroke + 1):
            for dy in range(-stroke, stroke + 1):
                if dx * dx + dy * dy <= stroke * stroke + stroke:
                    draw.text((x + dx, y + dy), line, font=font, fill=stroke_color)
        draw.text((x, y), line, font=font, fill=text_color)
        y += lh

    return img, y


def draw_sub(img, text, cy, font,
             text_color=(255, 210, 0),
             stroke_color=(0, 0, 0),
             stroke=7):
    draw = ImageDraw.Draw(img)
    tw, _ = text_size(font, text)
    x = W // 2 - tw // 2
    for dx in range(-stroke, stroke + 1):
        for dy in range(-stroke, stroke + 1):
            if dx * dx + dy * dy <= stroke * stroke:
                draw.text((x + dx, cy + dy), text, font=font, fill=stroke_color)
    draw.text((x, cy), text, font=font, fill=text_color)
    return img


# ── Screen definitions ───────────────────────────────────────────────────────
# src: filename in marketing_v2  (already generated DALL-E art)

SCREENS = [
    {
        "src": "1_who_would_win.png",
        "out": "1_who_would_win.png",
        "headline": ["WHO WOULD", "WIN?"],
        "sub": "AI-POWERED ANIMAL BATTLES",
        "sub_color": (255, 220, 0),
        "panel_color": (10, 5, 40, 175),
    },
    {
        "src": "2_ai_decides.png",
        "out": "2_ai_decides.png",
        "headline": ["AI DECIDES", "THE WINNER"],
        "sub": "REAL SCIENCE. EPIC BATTLES.",
        "sub_color": (0, 230, 255),
        "panel_color": (0, 20, 40, 175),
    },
    {
        "src": "3_prehistoric.png",
        "out": "3_prehistoric.png",
        "headline": ["PREHISTORIC", "LEGENDS"],
        "sub": "T-REX · MEGALODON · MAMMOTH",
        "sub_color": (150, 255, 80),
        "panel_color": (10, 25, 5, 175),
    },
    {
        "src": "4_fantasy.png",
        "out": "4_fantasy.png",
        "headline": ["UNLOCK THE", "FANTASY REALM"],
        "sub": "DRAGON · KRAKEN · GRIFFIN",
        "sub_color": (220, 100, 255),
        "panel_color": (25, 5, 40, 175),
    },
    {
        "src": "5_gods.png",
        "out": "5_gods.png",
        "headline": ["EVEN THE", "GODS BATTLE"],
        "sub": "ZEUS · POSEIDON · HADES",
        "sub_color": (255, 215, 0),
        "panel_color": (30, 20, 0, 175),
    },
]

f_head = fnt(LUCKIEST, 220)
f_sub  = fnt(BEBAS, 80)

for s in SCREENS:
    src_path = f"{SRC}/{s['src']}"
    if not os.path.exists(src_path):
        print(f"  ⚠ Missing source: {src_path} — skipping")
        continue

    print(f"\n=== {s['out']} ===")
    img = Image.open(src_path).convert("RGBA")

    # Ensure correct canvas size
    if img.size != (W, H):
        img = img.resize((W, H), Image.LANCZOS)

    # Slightly boost saturation on the reused art
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(1.15)
    img = rgb.convert("RGBA")

    # ── Re-apply bottom gradient so text panel sits on dark base ──
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    grad_start = int(H * 0.52)
    for y in range(grad_start, H):
        t = (y - grad_start) / (H - grad_start)
        a = int(t * 255 * 0.82)
        od.line([(0, y), (W, y)], fill=(0, 0, 0, a))
    img = Image.alpha_composite(img, overlay)

    # ── Text block: vertically anchored near bottom ──────────────
    lh         = f_head.getbbox("Ag")[3] + 28
    sub_h      = f_sub.getbbox("Ag")[3] + 20
    n_lines    = len(s["headline"])
    block_h    = n_lines * lh + 24 + sub_h   # headline + gap + sub
    bottom_margin = 130
    text_top   = H - block_h - bottom_margin

    img, headline_bottom = draw_headline(
        img,
        s["headline"],
        text_top,
        f_head,
        text_color=(255, 255, 255),
        stroke_color=(15, 8, 0),
        stroke=20,
        panel=True,
        panel_color=s["panel_color"],
    )

    sub_y = headline_bottom + 24
    img = draw_sub(img, s["sub"], sub_y, f_sub,
                   text_color=s["sub_color"],
                   stroke_color=(0, 0, 0),
                   stroke=8)

    out_path = f"{OUT}/{s['out']}"
    img.convert("RGB").save(out_path, "PNG")
    print(f"  ✓ Saved → {out_path}")

print("\n✅ Done! Check:", OUT)
