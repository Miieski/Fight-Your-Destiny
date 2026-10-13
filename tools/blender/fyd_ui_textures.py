"""Realistic wood textures for the UI (owner 2026-10-13: "keep our wood look but more realistic"). Painted with numpy
inside Blender (no external libraries) and saved as PNG in Icons/UiTex/:

    blender --background --factory-startup --python tools/blender/fyd_ui_textures.py

  WoodPanel.png   512 px seamless tile: dark walnut planks (window bodies, panels)
  WoodInset.png   512 px seamless tile: darker, finer grain (the content area inside a window)
  WoodLight.png   512 px seamless tile: lighter oak planks (title signs, cards)
  IronCorner.png  128 px, transparent: an iron corner bracket with rivets (top-left; rotated for the others)
Every tile wraps on both axes (periodic noise, seams and knots wrap around), so it can be repeated (ScaleType Tile).
Colors are written as sRGB values.
"""
import math
import os

import bpy
import numpy as np

ROOT = r"C:\Users\benad\Desktop\Roblox Project\Fight Your Destiny"
OUT = os.path.join(ROOT, "Icons", "UiTex")


def periodic_noise(h, w, cy, cx, rng):
    """Smooth value noise that wraps on both axes: a (cy x cx) random grid, smoothstep-interpolated."""
    grid = rng.random((cy, cx))
    y = np.arange(h) * cy / h
    x = np.arange(w) * cx / w
    y0 = np.floor(y).astype(int)
    x0 = np.floor(x).astype(int)
    fy = y - y0
    fx = x - x0
    sy = (fy * fy * (3 - 2 * fy))[:, None]
    sx = (fx * fx * (3 - 2 * fx))[None, :]
    y1 = (y0 + 1) % cy
    x1 = (x0 + 1) % cx
    a = grid[y0][:, x0]
    b = grid[y0][:, x1]
    c = grid[y1][:, x0]
    d = grid[y1][:, x1]
    top = a + (b - a) * sx
    bottom = c + (d - c) * sx
    return top + (bottom - top) * sy


def fractal(h, w, cy, cx, rng, octaves=4):
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += periodic_noise(h, w, cy * 2 ** o, cx * 2 ** o, rng) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def planks(size, planks_count, dark, light, seam, seed, grain_freq=9.0, streak=0.45, knots=2, tint=0.12):
    """Horizontal planks with wavy grain, fine streaks, plank seams, one butt joint per plank and a few knots."""
    rng = np.random.default_rng(seed)
    h = w = size
    ph = h // planks_count
    yy, xx = np.mgrid[0:h, 0:w]
    plank = np.minimum(yy // ph, planks_count - 1)
    local = (yy % ph) / ph
    # irregular grain lines along x: the line spacing itself wanders (noise on the frequency), then a strong warp
    warp = fractal(h, w, 8, 4, rng, 4)
    spacing = 0.75 + 0.5 * fractal(h, w, 4, 2, rng, 2)
    grain = 0.5 + 0.5 * np.sin(2 * math.pi * (local * grain_freq * spacing + warp * 3.2 + plank * 0.37))
    grain = grain ** 2.2
    # fine streaks (noise stretched along x) and pores (very fine, short dark dashes)
    streaks = fractal(h, w, 128, 6, rng, 4)
    pores = np.clip((fractal(h, w, 256, 24, rng, 2) - 0.62) * 4, 0, 1)
    v = (1 - streak) * grain + streak * streaks
    v = v * (1 - 0.45 * pores)
    # knots (wrap around the tile)
    for _ in range(knots):
        ky, kx = rng.integers(0, h), rng.integers(0, w)
        dy = (yy - ky + h / 2) % h - h / 2
        dx = (xx - kx + w / 2) % w - w / 2
        d = np.sqrt((dx / 2.6) ** 2 + dy ** 2)
        ring = 0.5 + 0.5 * np.cos(d * 0.9)
        mask = np.clip(1 - d / 14, 0, 1)
        v = v * (1 - mask * 0.75) + ring * mask * 0.35
    v = np.clip(v, 0, 1)
    color = dark[None, None, :] * (1 - v[..., None]) + light[None, None, :] * v[..., None]
    # per-plank tint and edge shading (each plank slightly rounded)
    tints = 1 + (rng.random(planks_count) - 0.5) * 2 * tint
    color *= tints[plank][..., None]
    edge = np.minimum(local, 1 - local) * ph
    color *= (0.78 + 0.22 * np.clip(edge / 6, 0, 1))[..., None]
    # seams between planks (dark line + light line under it)
    seam_mask = (yy % ph) < 2
    color[seam_mask] = seam
    hi = (yy % ph) == 2
    color[hi] = np.clip(color[hi] * 1.25, 0, 1)
    # one butt joint per plank, at a random x (wraps)
    for p in range(planks_count):
        jx = rng.integers(0, w)
        rows = slice(p * ph, (p + 1) * ph)
        for off, col in ((0, seam), (1, seam)):
            color[rows, (jx + off) % w] = col
        color[rows, (jx + 2) % w] = np.clip(color[rows, (jx + 2) % w] * 1.2, 0, 1)
    return np.clip(color, 0, 1)


def save(name, rgb, alpha=None):
    h, w = rgb.shape[:2]
    a = np.ones((h, w)) if alpha is None else alpha
    px = np.concatenate([rgb, a[..., None]], axis=2)[::-1]  # Blender rows go bottom-up
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(px.astype(np.float32).ravel())
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def iron_corner(size=128, ss=4):
    """An L-shaped iron bracket at the top-left with three rivets; supersampled for smooth edges."""
    n = size * ss
    yy, xx = np.mgrid[0:n, 0:n] / ss  # in output pixels
    arm = 30.0
    length = 112.0
    rx = 10.0  # rounded ends
    in_h = (yy < arm) & (xx < length - rx) | ((xx - (length - rx)) ** 2 + (yy - arm / 2) ** 2 < (arm / 2) ** 2)
    in_v = (xx < arm) & (yy < length - rx) | ((yy - (length - rx)) ** 2 + (xx - arm / 2) ** 2 < (arm / 2) ** 2)
    shape = (in_h | in_v).astype(float)
    rng = np.random.default_rng(7)
    base = hexrgb("#3c3f45")
    hammer = periodic_noise(n, n, 40, 40, rng) * 0.12 - 0.06
    color = np.broadcast_to(base, (n, n, 3)).copy() * (1 + hammer[..., None])
    # bevel: light on the top-left edges, dark on the bottom-right edges of each arm
    edge_top = np.clip(1 - yy / 4, 0, 1) + np.clip(1 - xx / 4, 0, 1)
    dist_bottom_h = np.where(xx > arm, np.clip(1 - (arm - yy) / 4, 0, 1), 0)
    dist_right_v = np.where(yy > arm, np.clip(1 - (arm - xx) / 4, 0, 1), 0)
    color += np.clip(edge_top, 0, 1)[..., None] * 0.22
    color -= np.clip(dist_bottom_h + dist_right_v, 0, 1)[..., None] * 0.18
    # rivets
    for cx, cy in ((arm / 2, arm / 2), (length - 22, arm / 2), (arm / 2, length - 22)):
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        r = 6.5
        inside = d < r
        lit = np.clip(1 - np.sqrt((xx - cx + 2) ** 2 + (yy - cy + 2) ** 2) / r, 0, 1)
        rivet = hexrgb("#6b6f78") * 0.7 + lit[..., None] * 0.55
        color = np.where(inside[..., None], rivet, color)
        ring = (d >= r) & (d < r + 1.6)
        color = np.where(ring[..., None], color * 0.55, color)
    # dark outline around the shape
    out = shape.copy()
    pad = 2 * ss
    padded = np.pad(shape, pad)
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            out = np.maximum(out, padded[pad + dy * ss:pad + dy * ss + n, pad + dx * ss:pad + dx * ss + n])
    outline = (out > 0) & (shape == 0)
    color = np.where(outline[..., None], hexrgb("#150d07"), color)
    alpha = out
    # downsample
    color = color.reshape(size, ss, size, ss, 3).mean(axis=(1, 3))
    alpha = alpha.reshape(size, ss, size, ss).mean(axis=(1, 3))
    return np.clip(color, 0, 1), alpha


def main():
    paths = []
    paths.append(save("WoodPanel", planks(512, 4, hexrgb("#2f1d10"), hexrgb("#6e4526"), hexrgb("#160c05"), seed=11,
                                          grain_freq=14.0, streak=0.5)))
    paths.append(save("WoodInset", planks(512, 8, hexrgb("#1c1108"), hexrgb("#40291a"), hexrgb("#0c0603"), seed=23,
                                          grain_freq=18.0, streak=0.6, knots=1, tint=0.08)))
    paths.append(save("WoodLight", planks(512, 4, hexrgb("#7a4f2b"), hexrgb("#c48a52"), hexrgb("#3a2414"), seed=37,
                                          grain_freq=11.0, streak=0.5, knots=2, tint=0.1)))
    rgb, a = iron_corner()
    paths.append(save("IronCorner", rgb, a))
    print("RUN_RESULTS", paths)


main()
