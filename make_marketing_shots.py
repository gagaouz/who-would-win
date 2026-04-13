"""
Clash of Clans style marketing screenshots for AvA.
- DALL-E 3 generates dramatic background art
- PIL composites with app screenshot in phone frame + bold headline
"""
import openai, requests, os, textwrap
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from io import BytesIO

client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])

# Canvas: 1290x2796 (iPhone 6.7" App Store)
W, H = 1290, 2796
OUT = "/Users/home/Desktop/BeastClash_Screenshots/marketing"
SHOTS = "/Users/home/Desktop/BeastClash_Screenshots/upload_ordered"
os.makedirs(OUT, exist_ok=True)

FONT_IMPACT = "/System/Library/Fonts/Supplemental/Impact.ttf"
FONT_BOLD   = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

def load_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except:
        return ImageFont.load_default()

def draw_text_outlined(draw, text, pos, font, fill, outline, stroke=6, align="center", max_width=None):
    """Draw text with a thick outline (CoC style)."""
    x, y = pos
    lines = []
    if max_width:
        words = text.split()
        line = ""
        for word in words:
            test = (line + " " + word).strip()
            bbox = font.getbbox(test)
            if bbox[2] - bbox[0] > max_width and line:
                lines.append(line)
                line = word
            else:
                line = test
        if line:
            lines.append(line)
    else:
        lines = text.split("\n")

    line_height = font.getbbox("A")[3] + 12
    total_h = len(lines) * line_height
    cur_y = y - total_h // 2

    for line in lines:
        bbox = font.getbbox(line)
        tw = bbox[2] - bbox[0]
        if align == "center":
            tx = x - tw // 2
        else:
            tx = x
        # Outline
        for dx in range(-stroke, stroke+1):
            for dy in range(-stroke, stroke+1):
                if dx*dx + dy*dy <= stroke*stroke:
                    draw.text((tx+dx, cur_y+dy), line, font=font, fill=outline)
        draw.text((tx, cur_y), line, font=font, fill=fill)
        cur_y += line_height

    return cur_y

def phone_frame(screenshot_path, target_w, target_h):
    """Returns an image of the app screenshot inside a sleek phone frame."""
    screen = Image.open(screenshot_path).convert("RGBA")
    # Phone outer dimensions
    ph_w, ph_h = target_w, target_h
    radius = int(ph_w * 0.12)
    frame_thick = int(ph_w * 0.028)

    # Draw phone body
    phone = Image.new("RGBA", (ph_w, ph_h), (0,0,0,0))
    draw = ImageDraw.Draw(phone)

    # Outer rounded rect (dark frame)
    draw.rounded_rectangle([0, 0, ph_w-1, ph_h-1], radius=radius, fill=(20,20,30,255))
    # Inner screen area
    sx, sy = frame_thick, frame_thick
    sw, sh = ph_w - frame_thick*2, ph_h - frame_thick*2
    screen_resized = screen.resize((sw, sh), Image.LANCZOS)
    phone.paste(screen_resized, (sx, sy))

    # Notch/pill at top
    notch_w, notch_h = int(ph_w * 0.28), int(ph_h * 0.025)
    nx = (ph_w - notch_w) // 2
    ny = frame_thick + 4
    draw.rounded_rectangle([nx, ny, nx+notch_w, ny+notch_h], radius=notch_h//2, fill=(10,10,15,230))

    # Subtle glare on frame
    for i in range(3):
        alpha = 40 - i*12
        draw.rounded_rectangle([i, i, ph_w-1-i, ph_h//3], radius=radius-i, outline=(255,255,255,alpha), width=1)

    return phone

def generate_bg(prompt):
    """Generate a 1024x1024 background via DALL-E 3, return PIL Image."""
    print(f"  Generating background: {prompt[:60]}...")
    resp = client.images.generate(
        model="dall-e-3",
        prompt=prompt,
        size="1024x1024",
        quality="hd",
        n=1
    )
    img_url = resp.data[0].url
    img_data = requests.get(img_url).content
    return Image.open(BytesIO(img_data)).convert("RGBA")

def add_gradient_overlay(img, top_color, bottom_color, top_alpha=180, bottom_alpha=220):
    """Add a gradient color wash over the image."""
    overlay = Image.new("RGBA", img.size, (0,0,0,0))
    draw = ImageDraw.Draw(overlay)
    for y in range(img.height):
        t = y / img.height
        r = int(top_color[0]*(1-t) + bottom_color[0]*t)
        g = int(top_color[1]*(1-t) + bottom_color[1]*t)
        b = int(top_color[2]*(1-t) + bottom_color[2]*t)
        a = int(top_alpha*(1-t) + bottom_alpha*t)
        draw.line([(0,y),(img.width,y)], fill=(r,g,b,a))
    return Image.alpha_composite(img, overlay)

# ─── Screenshot definitions ─────────────────────────────────────────────────

SCREENS = [
    {
        "out": "1_home_marketing.png",
        "shot": f"{SHOTS}/1_home.png",
        "headline": "WHO WOULD\nWIN?",
        "sub": "AI-powered animal battles",
        "bg_prompt": "Epic cinematic battle arena scene, two massive wild animals facing off in a glowing lightning storm arena, dramatic spotlight lighting, dark purple and orange sky, no text, ultra detailed, photorealistic fantasy art, wide establishing shot",
        "top_color": (80, 10, 120),
        "bot_color": (10, 5, 40),
        "accent": (255, 160, 0),
    },
    {
        "out": "2_picker_marketing.png",
        "shot": f"{SHOTS}/2_picker.png",
        "headline": "PICK YOUR\nFIGHTERS",
        "sub": "70+ creatures across 5 categories",
        "bg_prompt": "Grid of powerful wild animals, dramatic wildlife photography collage, lion, shark, eagle, gorilla, crocodile, elephant, dramatic dark background, cinematic lighting, no text, ultra detailed",
        "top_color": (10, 40, 80),
        "bot_color": (5, 10, 40),
        "accent": (0, 200, 255),
    },
    {
        "out": "3_battle_marketing.png",
        "shot": f"{SHOTS}/3_result.png",
        "headline": "AI DECIDES\nWHO WINS",
        "sub": "Real biology. Real science. Epic results.",
        "bg_prompt": "Dramatic AI brain lightning neural network with wild animal silhouettes, glowing energy beams, dark background, cinematic, photorealistic digital art, no text",
        "top_color": (20, 80, 20),
        "bot_color": (5, 20, 5),
        "accent": (0, 230, 100),
    },
    {
        "out": "4_fantasy_marketing.png",
        "shot": f"{SHOTS}/4_settings.png",
        "headline": "UNLOCK\nLEGENDS",
        "sub": "Fantasy • Prehistoric • Mythic • Gods",
        "bg_prompt": "Epic fantasy art with dragon, mythological creatures, ancient gods Zeus with lightning bolt, prehistoric T-Rex, all in a dramatic stormy sky vortex, dark purple gold atmosphere, cinematic, no text",
        "top_color": (80, 30, 0),
        "bot_color": (40, 5, 60),
        "accent": (255, 215, 0),
    },
    {
        "out": "5_gods_marketing.png",
        "shot": f"{SHOTS}/5_premium.png",
        "headline": "EVEN THE\nGODS BATTLE",
        "sub": "Zeus vs T-Rex? Now you can find out.",
        "bg_prompt": "Mount Olympus dramatic scene, Greek gods Zeus Poseidon Hades with lightning bolts and tridents, epic stormy clouds, golden divine light rays, dark and dramatic, cinematic fantasy art, no text",
        "top_color": (60, 40, 0),
        "bot_color": (20, 5, 50),
        "accent": (255, 200, 50),
    },
]

for s in SCREENS:
    print(f"\n=== {s['out']} ===")

    # 1. Generate background
    bg_raw = generate_bg(s["bg_prompt"])

    # 2. Scale background to canvas
    bg = bg_raw.resize((W, H), Image.LANCZOS)
    bg = bg.filter(ImageFilter.GaussianBlur(2))
    bg = add_gradient_overlay(bg, s["top_color"], s["bot_color"])

    canvas = bg.copy()
    draw = ImageDraw.Draw(canvas)

    # 3. Top zone: headline text  (top ~32% of canvas)
    font_headline = load_font(FONT_IMPACT, 175)
    font_sub      = load_font(FONT_BOLD, 64)

    headline_y = int(H * 0.16)
    draw_text_outlined(draw, s["headline"], (W//2, headline_y),
                       font_headline, fill=(255,255,255), outline=(0,0,0),
                       stroke=10, align="center", max_width=W-80)

    sub_y = int(H * 0.31)
    draw_text_outlined(draw, s["sub"], (W//2, sub_y),
                       font_sub, fill=s["accent"], outline=(0,0,0),
                       stroke=5, align="center")

    # 4. Phone frame in lower portion
    phone_w = int(W * 0.78)
    phone_h = int(phone_w * 2.165)  # ~iPhone aspect ratio
    phone_x = (W - phone_w) // 2
    phone_y = int(H * 0.36)

    phone_img = phone_frame(s["shot"], phone_w, phone_h)

    # Drop shadow for phone
    shadow = Image.new("RGBA", canvas.size, (0,0,0,0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        [phone_x+12, phone_y+18, phone_x+phone_w+12, phone_y+phone_h+18],
        radius=int(phone_w*0.12), fill=(0,0,0,120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(20))
    canvas = Image.alpha_composite(canvas, shadow)

    canvas.paste(phone_img, (phone_x, phone_y), phone_img)

    # 5. Bottom accent strip
    draw = ImageDraw.Draw(canvas)
    strip_y = phone_y + phone_h + 30
    if strip_y < H - 60:
        font_badge = load_font(FONT_BOLD, 52)
        draw_text_outlined(draw, "FREE ON THE APP STORE", (W//2, strip_y + 30),
                           font_badge, fill=s["accent"], outline=(0,0,0),
                           stroke=4, align="center")

    # 6. Save
    out_path = f"{OUT}/{s['out']}"
    canvas.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"  Saved → {out_path}")

print("\n✅ All marketing screenshots done!")
print(f"Find them in: {OUT}")
