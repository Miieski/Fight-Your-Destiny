"""Soft light textures for the hatch screen's egg light (UI/EggLight).

White RGB with the light in the alpha channel, so ImageColor3 tints them and ImageTransparency dims them.
    glow.png   256 px  radial glow: a tight core and a long soft tail (no hard edge, 0 at the border)
    beams.png  512 px  god rays from the middle: soft beams that widen, taper and fade at their ends
    rim.png    256 px  egg-shaped glow: full inside an egg outline, soft falloff outside (rim light)
    spark.png   64 px  a small hot spark with a soft halo
    preview.png         all four tinted on the hatch panel's wood colour (for checking only)

Usage:  python Previews/EggLight/make_egg_light_textures.py
"""

import math
import os
import random

from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def save(name, size, alpha_at, dither=True):
    """alpha_at(nx, ny) -> 0..1 with nx, ny in -1..1 (y up)."""
    w, h = size
    img = Image.new("RGBA", (w, h))
    px = img.load()
    rng = random.Random(7)
    for j in range(h):
        ny = 1 - 2 * (j + 0.5) / h
        for i in range(w):
            nx = 2 * (i + 0.5) / w - 1
            a = max(0.0, min(1.0, alpha_at(nx, ny)))
            v = a * 255 + (rng.random() - 0.5 if dither and 0 < a < 1 else 0)
            px[i, j] = (255, 255, 255, int(max(0, min(255, round(v)))))
    img.save(os.path.join(OUT, name))
    return img


def glow(nx, ny):
    r = math.hypot(nx, ny)
    core = math.exp(-((r / 0.32) ** 2))
    tail = 1 / (1 + (r / 0.3) ** 2)
    a = 0.5 * core + 0.5 * tail
    return a * (1 - smoothstep(0.45, 1.0, r))


BEAMS = []
_rng = random.Random(42)
for k in range(11):
    BEAMS.append({
        "angle": (k / 11) * 2 * math.pi + _rng.uniform(-0.15, 0.15),
        "width": _rng.uniform(0.09, 0.17),  # radians (gaussian half-width)
        "length": _rng.uniform(0.75, 1.0),  # of the half-size
        "power": _rng.uniform(0.7, 1.0),
    })


def beams(nx, ny):
    r = math.hypot(nx, ny)
    if r < 1e-6:
        return 0.0
    theta = math.atan2(nx, ny)
    keep = 1.0
    for b in BEAMS:
        d = (theta - b["angle"] + math.pi) % (2 * math.pi) - math.pi
        across = math.exp(-((d / b["width"]) ** 2))
        along = max(0.0, 1 - r / b["length"]) ** 1.25
        a = b["power"] * across * along
        keep *= 1 - a
    a = 1 - keep
    # the beams start a little out of the middle (the egg hides it) and never reach the border
    return a * smoothstep(0.03, 0.22, r) * (1 - smoothstep(0.85, 1.0, r))


def rim(nx, ny):
    # egg outline: half-height B, half-width A at the middle, a bit wider low and narrower high
    A, B, K = 0.66, 0.66, 0.12
    widen = 1 - K * (ny / B)
    s = math.sqrt((nx / (A * widen)) ** 2 + (ny / B) ** 2)
    if s <= 1:
        a = 1.0
    else:
        a = math.exp(-(((s - 1) / 0.24) ** 2))
    r = math.hypot(nx, ny)
    return a * (1 - smoothstep(0.9, 1.0, max(abs(nx), abs(ny))))


def spark(nx, ny):
    r = math.hypot(nx, ny)
    a = math.exp(-((r / 0.16) ** 2)) + 0.38 * math.exp(-((r / 0.48) ** 2))
    return min(1.0, a) * (1 - smoothstep(0.7, 1.0, r))


def preview(textures):
    wood = (60, 39, 22)
    sheet = Image.new("RGBA", (4 * 300, 300), wood + (255,))
    tints = [(255, 170, 30), (170, 80, 255), (120, 240, 255), (255, 240, 200)]
    for k, (img, tint) in enumerate(zip(textures, tints)):
        tile = img.resize((260, 260), Image.LANCZOS)
        colored = Image.new("RGBA", tile.size, tint + (0,))
        colored.putalpha(tile.getchannel("A"))
        sheet.alpha_composite(colored, (20 + k * 300, 20))
    sheet.save(os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    made = [
        save("glow.png", (256, 256), glow),
        save("beams.png", (512, 512), beams),
        save("rim.png", (256, 256), rim),
        save("spark.png", (64, 64), spark),
    ]
    preview(made)
    print("written to", OUT)
