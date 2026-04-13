"""
Clash of Clans style: full-bleed illustrated battle art + bold text overlay.
No phone frame. Animals ARE the heroes. Text at bottom like a movie poster.
"""
import openai, requests, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
from io import BytesIO

client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])

W, H = 1290, 2796
OUT = "/Users/home/Desktop/BeastClash_Screenshots/marketing_v2"
os.makedirs(OUT, exist_ok=True)

IMPACT = "/System/Library/Fonts/Supplemental/Impact.ttf"
ARIAL_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

def font(path, size):
    try: return ImageFont.truetype(path, size)
    except: return ImageFont.load_default()

def draw_coc_text(draw, lines, center_x, y, font_obj, text_color=(255,255,255), stroke_color=(0,0,0), stroke=14):
    """Draw chunky CoC-style text: thick black outline, white fill."""
    lh = font_obj.getbbox("A")[3] + 20
    for line in lines:
        bbox = font_obj.getbbox(line)
        tw = bbox[2] - bbox[0]
        x = center_x - tw // 2
        # Thick outline in all directions
        for dx in range(-stroke, stroke+1):
            for dy in range(-stroke, stroke+1):
                if dx*dx + dy*dy <= stroke*stroke + stroke:
                    draw.text((x+dx, y+dy), line, font=font_obj, fill=stroke_color)
        draw.text((x, y), line, font=font_obj, fill=text_color)
        y += lh
    return y

def draw_sub(draw, text, center_x, y, font_obj, text_color, stroke_color=(0,0,0), stroke=6):
    bbox = font_obj.getbbox(text)
    tw = bbox[2] - bbox[0]
    x = center_x - tw // 2
    for dx in range(-stroke, stroke+1):
        for dy in range(-stroke, stroke+1):
            if dx*dx + dy*dy <= stroke*stroke:
                draw.text((x+dx, y+dy), text, font=font_obj, fill=stroke_color)
    draw.text((x, y), text, font=font_obj, fill=text_color)

def gen_art(prompt):
    print(f"  Generating: {prompt[:70]}...")
    resp = client.images.generate(
        model="dall-e-3",
        prompt=prompt,
        size="1024x1792",   # Portrait — closest to phone ratio
        quality="hd",
        n=1
    )
    data = requests.get(resp.data[0].url).content
    return Image.open(BytesIO(data)).convert("RGBA")

def darken_bottom(img, strength=0.85):
    """Add dark gradient at bottom so text pops."""
    overlay = Image.new("RGBA", img.size, (0,0,0,0))
    draw = ImageDraw.Draw(overlay)
    grad_start = int(img.height * 0.45)
    for y in range(grad_start, img.height):
        t = (y - grad_start) / (img.height - grad_start)
        a = int(t * 255 * strength)
        draw.line([(0,y),(img.width,y)], fill=(0,0,0,a))
    return Image.alpha_composite(img, overlay)

def darken_top(img, strength=0.6):
    """Subtle dark gradient at top for top text."""
    overlay = Image.new("RGBA", img.size, (0,0,0,0))
    draw = ImageDraw.Draw(overlay)
    grad_end = int(img.height * 0.28)
    for y in range(0, grad_end):
        t = 1 - (y / grad_end)
        a = int(t * 255 * strength)
        draw.line([(0,y),(img.width,y)], fill=(0,0,0,a))
    return Image.alpha_composite(img, overlay)

SCREENS = [
    {
        "out": "1_who_would_win.png",
        "headline": ["WHO WOULD", "WIN?"],
        "sub": "AI-POWERED ANIMAL BATTLES",
        "sub_color": (255, 200, 0),
        "text_pos": "bottom",
        "art_prompt": (
            "Epic cartoon-illustrated style like Clash of Clans, a massive powerful lion "
            "and a fierce tiger facing off, roaring at each other, lightning crackling between them, "
            "dramatic arena with crowd of animals watching, rich warm orange and purple sky, "
            "dynamic action pose, vibrant colors, thick outlines, no text, no letters, "
            "cinematic lighting, highly detailed illustration"
        ),
    },
    {
        "out": "2_ai_decides.png",
        "headline": ["AI DECIDES", "THE WINNER"],
        "sub": "REAL SCIENCE. EPIC BATTLES.",
        "sub_color": (0, 220, 255),
        "text_pos": "bottom",
        "art_prompt": (
            "Epic cartoon-illustrated style like Clash of Clans, a massive great white shark "
            "leaping out of the ocean toward a saltwater crocodile on a rock, enormous splash, "
            "dramatic stormy ocean, lightning in dark sky, glowing energy aura around both animals, "
            "vibrant blue teal colors, thick outlines, dynamic action, no text, no letters, "
            "ultra detailed cinematic illustration"
        ),
    },
    {
        "out": "3_prehistoric.png",
        "headline": ["PREHISTORIC", "LEGENDS"],
        "sub": "T-REX • MEGALODON • MAMMOTH & MORE",
        "sub_color": (150, 255, 100),
        "text_pos": "bottom",
        "art_prompt": (
            "Epic cartoon-illustrated style like Clash of Clans, a massive Tyrannosaurus Rex "
            "roaring with mouth wide open, dramatic prehistoric jungle background with volcanoes, "
            "lava glow, stormy sky, smaller dinosaurs fleeing in background, "
            "rich green and orange colors, thick outlines, highly detailed, no text, no letters, "
            "action pose, cinematic lighting"
        ),
    },
    {
        "out": "4_fantasy.png",
        "headline": ["UNLOCK THE", "FANTASY REALM"],
        "sub": "DRAGON • KRAKEN • GRIFFIN & MORE",
        "sub_color": (220, 100, 255),
        "text_pos": "bottom",
        "art_prompt": (
            "Epic cartoon-illustrated style like Clash of Clans, a magnificent dragon breathing "
            "fire facing off against a unicorn charging with glowing horn, "
            "magical fantasy world background with floating islands, aurora sky, "
            "epic purple and gold colors, thick outlines, vibrant, highly detailed, "
            "no text, no letters, cinematic fantasy art"
        ),
    },
    {
        "out": "5_gods.png",
        "headline": ["EVEN THE", "GODS BATTLE"],
        "sub": "ZEUS • POSEIDON • HADES & MORE",
        "sub_color": (255, 215, 0),
        "text_pos": "bottom",
        "art_prompt": (
            "Epic cartoon-illustrated style like Clash of Clans, Zeus the Greek god hurling "
            "a massive lightning bolt downward, dramatic Olympus clouds parting around him, "
            "golden armor gleaming, thunderstorm swirling below, epic scale, "
            "rich gold and dark blue colors, thick outlines, highly detailed, "
            "no text, no letters, action pose, cinematic divine lighting"
        ),
    },
]

f_headline = font(IMPACT, 210)
f_sub      = font(ARIAL_BOLD, 62)

for s in SCREENS:
    print(f"\n=== {s['out']} ===")

    # Generate art at 1024x1792, scale to canvas
    art = gen_art(s["art_prompt"])
    art = art.resize((W, H), Image.LANCZOS)

    # Boost saturation/contrast slightly
    art_rgb = art.convert("RGB")
    art_rgb = ImageEnhance.Color(art_rgb).enhance(1.3)
    art_rgb = ImageEnhance.Contrast(art_rgb).enhance(1.1)
    art = art_rgb.convert("RGBA")

    # Dark gradients so text is always readable
    art = darken_bottom(art, strength=0.9)
    art = darken_top(art, strength=0.5)

    draw = ImageDraw.Draw(art)

    # Text layout at bottom
    text_bottom_margin = 110
    sub_h = f_sub.getbbox("A")[3] + 30
    headline_lh = f_headline.getbbox("A")[3] + 24
    total_text_h = len(s["headline"]) * headline_lh + sub_h + 30
    text_y = H - total_text_h - text_bottom_margin

    # Headline
    text_y = draw_coc_text(draw, s["headline"], W//2, text_y, f_headline,
                           text_color=(255,255,255), stroke_color=(0,0,0), stroke=14)

    # Sub
    text_y += 20
    draw_sub(draw, s["sub"], W//2, text_y, f_sub,
             text_color=s["sub_color"], stroke_color=(0,0,0), stroke=6)

    out_path = f"{OUT}/{s['out']}"
    art.convert("RGB").save(out_path, "PNG")
    print(f"  ✓ Saved → {out_path}")

print("\n✅ Done! Check:", OUT)
