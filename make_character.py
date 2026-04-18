#!/usr/bin/env python3
"""
Character builder for "Who Would Win?" iOS app.

Generates 3D claymation-style creature artwork with real transparent
backgrounds, matching the established visual style of the existing pack.

Technique:
  1. Prompt Gemini 3 Pro Image to render the creature on a flat magenta
     (#FF00FF) background. Magenta is a reliable chroma-key color because
     no creature in the app uses pure magenta.
  2. Chroma-key the magenta away to real alpha-0 pixels.
  3. Decontaminate edge fringes (pixels where magenta bled into the creature)
     by pulling R and B toward G, so we don't get pink halos.
  4. Feather the alpha edge by 1px and zero out RGB where alpha is 0 so
     mipmap filtering doesn't bleed the key color at small sizes.
  5. Save to Assets.xcassets/creature_<id>.imageset/ with a correct
     Contents.json.

Usage
-----
# Generate a single creature:
GEMINI_API_KEY=... python3 make_character.py tardigrade "a microscopic tardigrade water bear with 8 stubby legs and a segmented body"

# Generate several at once:
GEMINI_API_KEY=... python3 make_character.py \\
  tardigrade "a microscopic tardigrade water bear with 8 stubby legs and a segmented body" \\
  narwhal     "a narwhal whale with a long spiral tusk and a gray and white body"

Options
-------
--out-dir PATH   Where the final .imageset lives (default: iOS assets folder)
--raw-dir PATH   Where the unprocessed raw PNGs are cached (default: /tmp/creature_gen)
--no-install     Don't drop into the .imageset folder, just write to raw-dir
--model NAME     Gemini model (default: gemini-3-pro-image-preview)
--size N         Final PNG size (default: 512)

Prompt tuning
-------------
The PROMPT_TEMPLATE below is what gives us the consistent look. Keep it as-is
for style consistency with existing pack creatures (ankylosaurus, t-rex, etc.).
Only change the `subject` string per-creature.
"""
import argparse
import io
import os
import sys
import time

import numpy as np
from PIL import Image, ImageFilter
from google import genai


# -------- THE ACTUAL PROMPT TEMPLATE --------
# This is the character-builder prompt. Keep the style paragraph fixed;
# swap only the {subject} placeholder for each creature.
PROMPT_TEMPLATE = (
    "A cute 3D-rendered claymation-style character of {subject}. "
    "Chunky cartoonish proportions, friendly kid-friendly style, vibrant colors, "
    "soft rim lighting, glossy smooth surfaces. "
    "The background MUST be a solid flat pure magenta color (hex #FF00FF). "
    "The magenta fills the entire image except for the creature. "
    "Do NOT draw any scenery, pattern, checkerboard, ground, sky, water, or frame. "
    "Square image, centered creature, full creature visible."
)
BG_RGB = (255, 0, 255)

DEFAULT_ASSETS_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "ios/WhoWouldWin/Assets.xcassets",
)
DEFAULT_RAW_DIR = "/tmp/creature_gen"
DEFAULT_MODEL = "gemini-3-pro-image-preview"


def chroma_key(img: Image.Image, key=BG_RGB, tol=70, feather=1) -> Image.Image:
    """Turn a flat-`key`-background RGBA image into a real transparent PNG.

    Also applies spill suppression so anti-aliased fringe pixels don't keep
    a pink cast from the magenta key.
    """
    img = img.convert("RGBA")
    arr = np.array(img, dtype=np.int16)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    kr, kg, kb = key

    dist = np.sqrt((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2)
    magentaish = (r > 180) & (b > 180) & (g < 90)
    bg_mask = (dist < tol) | magentaish

    alpha = np.where(bg_mask, 0, 255).astype(np.uint8)

    if feather > 0:
        alpha = np.array(
            Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(feather))
        )

    out = arr.astype(np.uint8)
    zero = alpha == 0
    out[zero, 0] = 0
    out[zero, 1] = 0
    out[zero, 2] = 0

    # Spill suppression: where R and B sit much higher than G, pull them
    # down toward G level. Kills the magenta tint on edges.
    keep = alpha > 0
    spill = keep & (r > g + 40) & (b > g + 40)
    out[..., 0] = np.where(spill, np.minimum(r, g + 20), out[..., 0])
    out[..., 2] = np.where(spill, np.minimum(b, g + 20), out[..., 2])

    out_rgba = np.dstack([out[..., 0], out[..., 1], out[..., 2], alpha])
    return Image.fromarray(out_rgba.astype(np.uint8), "RGBA")


def gemini_generate(client: genai.Client, prompt: str, model: str) -> Image.Image:
    resp = client.models.generate_content(model=model, contents=prompt)
    for cand in resp.candidates or []:
        for part in (cand.content.parts if cand.content else []):
            inline = getattr(part, "inline_data", None)
            if inline and inline.data:
                return Image.open(io.BytesIO(inline.data)).convert("RGBA")
    raise RuntimeError("no image in Gemini response")


def install_imageset(assets_dir: str, creature_id: str, png_path: str) -> str:
    """Copy final PNG into creature_<id>.imageset/ with correct Contents.json."""
    imageset = os.path.join(assets_dir, f"creature_{creature_id}.imageset")
    os.makedirs(imageset, exist_ok=True)
    dst = os.path.join(imageset, f"creature_{creature_id}.png")
    Image.open(png_path).save(dst)
    contents_path = os.path.join(imageset, "Contents.json")
    with open(contents_path, "w") as f:
        f.write(
            f"""{{
  "images": [
    {{
      "filename": "creature_{creature_id}.png",
      "idiom": "universal",
      "scale": "1x"
    }}
  ],
  "info": {{
    "author": "xcode",
    "version": 1
  }}
}}
"""
        )
    return dst


def build_one(
    client: genai.Client,
    creature_id: str,
    subject: str,
    *,
    model: str,
    size: int,
    raw_dir: str,
    assets_dir: str,
    install: bool,
) -> str:
    os.makedirs(raw_dir, exist_ok=True)
    prompt = PROMPT_TEMPLATE.format(subject=subject)
    print(f"→ generating {creature_id}")

    raw = gemini_generate(client, prompt, model).resize((size, size), Image.LANCZOS)
    raw_path = os.path.join(raw_dir, f"raw_{creature_id}.png")
    raw.save(raw_path)

    keyed = chroma_key(raw)
    final_path = os.path.join(raw_dir, f"creature_{creature_id}.png")
    keyed.save(final_path)

    arr = np.array(keyed)
    opaque = (arr[..., 3] > 250).mean() * 100
    transp = (arr[..., 3] == 0).mean() * 100
    print(f"  keyed: {opaque:.1f}% opaque, {transp:.1f}% transparent")

    if install:
        installed = install_imageset(assets_dir, creature_id, final_path)
        print(f"  installed → {installed}")
        return installed
    return final_path


def main():
    ap = argparse.ArgumentParser(
        description="Generate on-brand creature artwork for Who Would Win? with transparent backgrounds."
    )
    ap.add_argument(
        "pairs",
        nargs="+",
        help="Alternating creature_id subject pairs. Example: "
             "tardigrade 'a microscopic water bear with eight legs' narwhal 'a narwhal with a spiral tusk'",
    )
    ap.add_argument("--out-dir", default=DEFAULT_ASSETS_DIR, help="Assets.xcassets path")
    ap.add_argument("--raw-dir", default=DEFAULT_RAW_DIR, help="Working dir for raw PNGs")
    ap.add_argument("--no-install", action="store_true", help="Skip imageset install")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--size", type=int, default=512)
    args = ap.parse_args()

    if len(args.pairs) % 2 != 0:
        ap.error("pairs must be alternating creature_id / subject strings")

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        sys.exit("Set GEMINI_API_KEY environment variable.")
    client = genai.Client(api_key=api_key)

    for i in range(0, len(args.pairs), 2):
        creature_id, subject = args.pairs[i], args.pairs[i + 1]
        try:
            build_one(
                client,
                creature_id,
                subject,
                model=args.model,
                size=args.size,
                raw_dir=args.raw_dir,
                assets_dir=args.out_dir,
                install=not args.no_install,
            )
        except Exception as e:
            print(f"  !! error on {creature_id}: {e}")
        time.sleep(1)


if __name__ == "__main__":
    main()
