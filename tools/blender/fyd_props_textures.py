"""Fight Your Destiny - shared TILEABLE textures of the prop upgrade (docs/model_upgrade_brief.txt section 2).

Painted with numpy (Blender's bundled Python has it; no other library), written with a small built-in PNG
encoder, so the same file runs headless or from the Blender MCP:

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --factory-startup ^
        --python tools/blender/fyd_props_textures.py

Writes Blender/Props/textures/<family>_<map>.png (512 x 512, seamless on both axes), textures.json (file list,
ColorMap means used for the tint compensation, tile size) and Previews/Props/textures_sheet.png (each set tinted
with its family colour and lit by its own normal map, 2 x 2 tiles to show the seams).

Rules (Blender/Props/README.txt):
- ONE tile = 4 x 4 studs (MaterialVariant.StudsPerTile = 4; the prop meshes use world-scale UVs, 1 UV unit = 4 studs).
- ColorMaps are near-white NEUTRAL GRAYSCALE (mean about 0.90) so SurfaceAppearance.Color / BasePart.Color can
  tint them per part (the tint multiplies the map). Detail is mostly darker than white.
- NormalMaps are OpenGL tangent space (green = +V, the only format Roblox supports), gently scaled (stylised,
  not noisy). Roughness / Metalness are 8-bit single-channel.
- Everything is built from periodic noise and np.roll derivatives, so every map wraps without seams.
"""
import json
import math
import os
import struct
import zlib

import numpy as np

ROOT = r"C:\Users\benad\Desktop\Roblox Project\Fight Your Destiny"
OUT = os.path.join(ROOT, "Blender", "Props", "textures")
SHEET = os.path.join(ROOT, "Previews", "Props", "textures_sheet.png")
SIZE = 512
STUDS_PER_TILE = 4.0
COLOR_MEAN = 0.90


# ------------------------------------------------------------------------------------------------
# PNG writer (8-bit gray / RGB / RGBA, filter "Up" per row), rows top-first
# ------------------------------------------------------------------------------------------------
def write_png(path, arr):
    arr = np.ascontiguousarray(arr, dtype=np.uint8)
    h, w = arr.shape[:2]
    ch = 1 if arr.ndim == 2 else arr.shape[2]
    ctype = {1: 0, 3: 2, 4: 6}[ch]
    rows = arr.reshape(h, w * ch)
    up = rows.astype(np.int16)
    up[1:] = (up[1:] - up[:-1]) % 256
    raw = np.empty((h, w * ch + 1), np.uint8)
    raw[:, 0] = 2  # "Up" filter
    raw[0, 0] = 0
    raw[0, 1:] = rows[0]
    raw[1:, 1:] = up[1:].astype(np.uint8)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw.tobytes(), 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def to_u8(a):
    return np.clip(np.round(np.asarray(a) * 255.0), 0, 255).astype(np.uint8)


# ------------------------------------------------------------------------------------------------
# periodic noise (arrays are [row, col], row 0 = top of the image, col = U)
# ------------------------------------------------------------------------------------------------
def value_noise(h, w, cy, cx, rng):
    """Smooth value noise on a (cy x cx) random grid, smoothstep-interpolated, wraps on both axes."""
    grid = rng.random((cy, cx))
    y = np.arange(h) * cy / h
    x = np.arange(w) * cx / w
    y0 = np.floor(y).astype(int)
    x0 = np.floor(x).astype(int)
    fy, fx = y - y0, x - x0
    sy = (fy * fy * (3 - 2 * fy))[:, None]
    sx = (fx * fx * (3 - 2 * fx))[None, :]
    y1, x1 = (y0 + 1) % cy, (x0 + 1) % cx
    a, b = grid[y0][:, x0], grid[y0][:, x1]
    c, d = grid[y1][:, x0], grid[y1][:, x1]
    top = a + (b - a) * sx
    bottom = c + (d - c) * sx
    return top + (bottom - top) * sy


def fractal(h, w, cy, cx, rng, octaves=4, gain=0.5):
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += value_noise(h, w, cy * 2 ** o, cx * 2 ** o, rng) * amp
        norm += amp
        amp *= gain
    return total / norm


def norm01(a):
    lo, hi = float(a.min()), float(a.max())
    return (a - lo) / max(1e-9, hi - lo)


def worley(h, w, n, rng, grid=0, jitter=0.75):
    """Toroidal cellular noise: returns (F1, F2, cell id) in pixels, for n random feature points
    (or, with grid > 0, one point per cell of a grid x grid lattice, jittered: no tiny cells)."""
    if grid:
        gy, gx = np.mgrid[0:grid, 0:grid]
        cells = np.stack([gy.ravel(), gx.ravel()], axis=1).astype(np.float64)
        pts = (cells + 0.5 + (rng.random(cells.shape) - 0.5) * jitter) / grid * np.array([h, w])
    else:
        pts = rng.random((n, 2)) * np.array([h, w])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    f1 = np.full((h, w), 1e9, np.float32)
    f2 = np.full((h, w), 1e9, np.float32)
    cid = np.zeros((h, w), np.int32)
    for i, (py, px) in enumerate(pts):
        dy = np.abs(yy - py)
        dy = np.minimum(dy, h - dy)
        dx = np.abs(xx - px)
        dx = np.minimum(dx, w - dx)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, i, cid)
        f1 = np.where(closer, d, f1)
    return f1, f2, cid


def blur(a, r):
    """Box blur with wrap-around (keeps tiles seamless)."""
    if r <= 0:
        return a
    out = a.copy()
    for axis in (0, 1):
        acc = np.zeros_like(out)
        for k in range(-r, r + 1):
            acc += np.roll(out, k, axis=axis)
        out = acc / (2 * r + 1)
    return out


# ------------------------------------------------------------------------------------------------
# map helpers
# ------------------------------------------------------------------------------------------------
def normal_map(height, strength):
    """OpenGL tangent-space normal map from a height field in [0, 1] (row 0 = top, +V = up)."""
    dhdu = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dhdv = -(np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5  # moving down a row = -V
    nx, ny, nz = -dhdu * strength, -dhdv * strength, np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / length, ny / length, nz / length], axis=2) * 0.5 + 0.5


def color_from_darkness(dark, mean=COLOR_MEAN):
    """Near-white neutral gray: 1 - k * darkness, k chosen so the mean is exactly `mean`."""
    d = norm01(dark)
    k = (1.0 - mean) / max(1e-6, float(d.mean()))
    k = min(k, 0.45)
    c = 1.0 - k * d
    return np.clip(c, 0, 1)


def gray3(c):
    return np.stack([c, c, c], axis=2)


def line_mask(dist, width):
    """Soft line of half-width `width` pixels from a distance field."""
    return np.clip(1.0 - dist / np.maximum(1e-6, width), 0, 1)


def wrap_dist(a, b, period):
    d = np.abs(a - b) % period
    return np.minimum(d, period - d)


# ------------------------------------------------------------------------------------------------
# the families
# ------------------------------------------------------------------------------------------------
def grain_field(h, w, rng, bands=14, phase=0.0):
    """Long wood grain running along U (horizontal): sharp dark late-wood lines, warped, plus fine streaks."""
    v = np.arange(h)[:, None] / h * np.ones((1, w))
    warp = fractal(h, w, 5, 2, rng, 3) * 0.55 + fractal(h, w, 16, 3, rng, 2) * 0.08
    rings = 0.5 + 0.5 * np.sin(2 * math.pi * (v * bands + warp * 2.0 + phase))
    late = rings ** 12  # narrow dark late-wood lines
    streaks = fractal(h, w, 96, 3, rng, 3)
    pores = np.clip((fractal(h, w, 192, 24, rng, 2) - 0.6) * 5, 0, 1)
    return late, streaks, pores


def knot(h, w, rng, radius):
    """A small knot (wraps): concentric dark rings in an ellipse; returns (darkness, height)."""
    ky, kx = rng.random() * h, rng.random() * w
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dy, dx = wrap_dist(yy, ky, h), wrap_dist(xx, kx, w) * 0.45
    d = np.sqrt(dx * dx + dy * dy) / radius
    ring = (0.5 + 0.5 * np.cos(d * 9.0)) * np.clip(1.6 - d, 0, 1)
    core = np.clip(1.0 - d * 2.2, 0, 1)
    return np.clip(ring * 0.6 + core, 0, 1), -core * 0.5


def tex_wood_grain(rng):
    late, streaks, pores = grain_field(SIZE, SIZE, rng, bands=12)
    k1d, k1h = knot(SIZE, SIZE, rng, 16)
    dark = 0.40 * late + 0.40 * streaks + 0.12 * pores + 0.35 * k1d
    height = 0.6 - 0.2 * late - 0.12 * streaks - 0.15 * pores + k1h * 0.6
    color = color_from_darkness(dark)
    rough = 0.68 + 0.14 * norm01(dark)
    return {"color": gray3(color), "normal": normal_map(height, 3.0), "roughness": rough}


def tex_wood_planks(rng):
    h = w = SIZE
    n_planks = 4  # one plank = 1 stud wide (tile = 4 studs)
    ph = h // n_planks
    late, streaks, pores = grain_field(h, w, rng, bands=18)
    rows = np.arange(h)[:, None] * np.ones((1, w))
    cols = np.ones((h, 1)) * np.arange(w)[None, :]
    plank = (rows // ph).astype(int)
    local = rows - plank * ph
    # per-plank tone and grain phase
    tone = rng.uniform(0.0, 0.10, n_planks)[plank]
    shift = rng.integers(0, w, n_planks)
    late2 = np.zeros_like(late)
    for i in range(n_planks):
        sel = plank == i
        late2[sel] = np.roll(late, int(shift[i]), axis=1)[sel]
    # plank seams (gap at the plank boundary) and one butt joint per plank
    seam_d = np.minimum(local, ph - local)
    seam = line_mask(seam_d, 3.0)
    butt = np.zeros_like(seam)
    nails = np.zeros_like(seam)
    for i in range(n_planks):
        bx = rng.uniform(0, w)
        sel = plank == i
        bd = wrap_dist(cols, bx, w)
        butt[sel] = np.maximum(butt[sel], line_mask(bd, 1.6)[sel])
        for nyf in (0.28, 0.72):  # two nails each side of the joint
            for side in (-9.0, 9.0):
                ndist = np.sqrt(wrap_dist(cols, (bx + side) % w, w) ** 2 + (rows - (i * ph + nyf * ph)) ** 2)
                nails = np.maximum(nails, line_mask(ndist, 3.2))
    edge = line_mask(seam_d, 8.0) * 0.5  # slightly rounded plank edges
    dark = 0.45 * late2 + 0.2 * streaks + 0.1 * pores + tone * 2.0 + 1.6 * seam + 1.3 * butt + 0.9 * nails + 0.15 * edge
    height = 0.7 - 0.2 * late2 - 0.1 * pores - 0.6 * seam - 0.5 * butt - 0.25 * edge + 0.15 * nails
    color = color_from_darkness(dark)
    rough = np.clip(0.7 + 0.12 * norm01(dark) - 0.25 * nails, 0, 1)
    return {"color": gray3(color), "normal": normal_map(height, 3.0), "roughness": rough}


def _metal_base(rng, dent_cells=110):
    h = w = SIZE
    mott = fractal(h, w, 4, 4, rng, 4)
    f1, f2, _ = worley(h, w, dent_cells, rng)
    dents = norm01(f1) ** 1.5  # shallow dimples (low at the dent centers)
    scratches = np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for _ in range(14):
        cy, cx = rng.random() * h, rng.random() * w
        ang = rng.uniform(0, math.pi)
        length = rng.uniform(40, 140)
        dy, dx = yy - cy, xx - cx
        dy = (dy + h / 2) % h - h / 2
        dx = (dx + w / 2) % w - w / 2
        along = dx * math.cos(ang) + dy * math.sin(ang)
        across = -dx * math.sin(ang) + dy * math.cos(ang)
        m = line_mask(np.abs(across), 0.9) * (np.abs(along) < length / 2)
        scratches = np.maximum(scratches, m * rng.uniform(0.4, 1.0))
    dirt = blur(np.clip((fractal(h, w, 5, 5, rng, 3) - 0.62) * 2.5, 0, 1), 3)
    mott = 0.6 * mott + 0.4 * fractal(h, w, 16, 16, rng, 2)
    return mott, dents, scratches, dirt


def tex_metal_iron(rng):
    mott, dents, scratches, dirt = _metal_base(rng)
    dark = 0.35 * mott + 0.35 * (1 - dents) + 0.3 * dirt - 0.3 * scratches
    height = 0.5 + 0.25 * dents - 0.05 * scratches + 0.05 * dirt
    color = color_from_darkness(dark, mean=0.88)
    rough = np.clip(0.52 + 0.12 * (mott - 0.5) + 0.25 * dirt - 0.18 * scratches, 0, 1)
    metal = np.clip(1.0 - 0.55 * dirt, 0, 1)
    polished = np.clip(0.26 + 0.08 * (mott - 0.5) + 0.3 * dirt - 0.1 * scratches, 0, 1)
    return {"color": gray3(color), "normal": normal_map(height, 2.0), "roughness": rough, "metalness": metal,
            "_polished": polished}


def tex_metal_riveted(rng):
    """Sheet iron: 2 x 2 plates per tile (2-stud plates), a row of rivets along each seam, rust streaks
    running DOWN (toward +row) from some rivets."""
    h = w = SIZE
    mott, dents, scratches, dirt = _metal_base(rng, dent_cells=40)
    rows = np.arange(h, dtype=np.float32)[:, None] * np.ones((1, w), np.float32)
    cols = np.ones((h, 1), np.float32) * np.arange(w, dtype=np.float32)[None, :]
    half = SIZE / 2
    seam_v = np.minimum(wrap_dist(cols, 0, w), wrap_dist(cols, half, w))  # vertical seams
    seam_h = np.minimum(wrap_dist(rows, 0, h), wrap_dist(rows, half, h))  # horizontal seams
    seam = np.maximum(line_mask(seam_v, 1.6), line_mask(seam_h, 1.6))
    lap = np.maximum(line_mask(seam_v, 6.0), line_mask(seam_h, 6.0)) * 0.4  # overlapping plate edge
    rivets = np.zeros((h, w), np.float32)
    streak = np.zeros((h, w), np.float32)
    spacing = SIZE / 16  # 1/4 stud
    off = 14.0
    centers = []
    for k in range(16):
        t = (k + 0.5) * spacing
        for sx in (0.0, half):
            for side in (-off, off):
                centers.append((t, (sx + side) % w))  # along vertical seams
        for sy in (0.0, half):
            for side in (-off, off):
                centers.append(((sy + side) % h, t))  # along horizontal seams
    for (cy, cx) in centers:
        d = np.sqrt(wrap_dist(rows, cy, h) ** 2 + wrap_dist(cols, cx, w) ** 2)
        dome = np.clip(1 - (d / 5.0) ** 2, 0, 1)
        rivets = np.maximum(rivets, np.sqrt(dome))
        if rng.random() < 0.22:  # rust streak running down from this rivet
            length = rng.uniform(40, 120)
            down = (rows - cy) % h
            width = 3.0 + down * 0.02
            m = line_mask(wrap_dist(cols, cx, w), width) * (down < length) * np.clip(1 - down / length, 0, 1)
            streak = np.maximum(streak, m)
    streak = blur(streak, 2)
    dark = 0.35 * mott + 0.15 * (1 - dents) + 1.2 * seam + 0.25 * lap + 0.8 * streak + 0.35 * dirt - 0.35 * rivets
    height = 0.5 + 0.08 * dents - 0.5 * seam + 0.12 * lap + 0.55 * rivets
    color = color_from_darkness(dark, mean=0.88)
    rough = np.clip(0.55 + 0.1 * (mott - 0.5) + 0.3 * streak + 0.2 * dirt - 0.2 * rivets, 0, 1)
    metal = np.clip(1.0 - 0.6 * streak - 0.4 * dirt, 0, 1)
    return {"color": gray3(color), "normal": normal_map(height, 3.0), "roughness": rough, "metalness": metal}


def _stone_detail(rng):
    h = w = SIZE
    big = fractal(h, w, 6, 6, rng, 5)
    f1, f2, _ = worley(h, w, 70, rng)
    facets = norm01(f2 - f1)  # broken-plane facets, low on the cell borders
    pits = np.clip((fractal(h, w, 96, 96, rng, 2) - 0.66) * 6, 0, 1)
    speck = fractal(h, w, 256, 256, rng, 1) - 0.5
    return big, facets, pits, speck


def tex_stone_rough(rng):
    big, facets, pits, speck = _stone_detail(rng)
    dark = 0.55 * (1 - big) + 0.15 * (1 - facets) + 0.3 * pits + 0.25 * speck
    height = 0.45 * big + 0.2 * facets - 0.15 * pits
    color = color_from_darkness(dark, mean=0.88)
    rough = np.clip(0.86 + 0.08 * norm01(dark), 0, 1)
    return {"color": gray3(color), "normal": normal_map(height, 4.0), "roughness": rough}


def tex_stone_blocks(rng):
    """Cut stone, 4 courses of 1 stud, blocks 1.5-2.5 studs long in a running bond, recessed mortar,
    chipped block edges, per-block tone."""
    h = w = SIZE
    big, facets, pits, speck = _stone_detail(rng)
    rows = np.arange(h, dtype=np.float32)[:, None] * np.ones((1, w), np.float32)
    cols = np.ones((h, 1), np.float32) * np.arange(w, dtype=np.float32)[None, :]
    course_h = SIZE // 4
    course = (rows // course_h).astype(int)
    edge_d = np.minimum(rows - course * course_h, (course + 1) * course_h - rows)
    tone = np.zeros((h, w), np.float32)
    bump = np.zeros((h, w), np.float32)
    for c in range(4):
        # split the 512 px course into blocks (wrap-aware, widths 192/256/320 px variants)
        widths = [256, 256] if c % 2 == 0 else [192, 320]
        if rng.random() < 0.5:
            widths = widths[::-1]
        start = rng.uniform(0, w)
        sel = course == c
        x = start
        joints = []
        for bw in widths:
            joints.append(x % w)
            x += bw
        jd = np.full((h, w), 1e9, np.float32)
        for jx in joints:
            jd = np.minimum(jd, wrap_dist(cols, jx, w))
        ed = np.minimum(edge_d, jd)
        # block index per pixel: count joints passed since `start`
        rel = (cols - start) % w
        bidx = np.zeros_like(rel, dtype=int)
        acc = 0
        for i, bw in enumerate(widths):
            bidx = np.where((rel >= acc) & (rel < acc + bw), i, bidx)
            acc += bw
        tones = rng.uniform(0.0, 0.14, len(widths))
        tone = np.where(sel, tones[bidx], tone)
        bump = np.where(sel, ed, bump)
    chip = fractal(h, w, 48, 48, rng, 2) * 6.0  # ragged edges
    mortar = np.clip(1.0 - (bump - chip * 0.5) / 4.0, 0, 1)
    pillow = np.clip((bump - 3.0) / 10.0, 0, 1) ** 0.5
    dark = 0.35 * (1 - big) + 0.15 * (1 - facets) + 0.4 * pits + 0.2 * speck + tone * 2.2 + 1.5 * mortar
    height = 0.25 + 0.5 * pillow + 0.15 * big + 0.1 * facets - 0.2 * pits - 0.3 * mortar
    color = color_from_darkness(dark, mean=0.88)
    rough = np.clip(0.85 + 0.1 * norm01(dark), 0, 1)
    return {"color": gray3(color), "normal": normal_map(height, 4.0), "roughness": rough}


def _weave(h, w, threads, rng, flat=0.45):
    """Plain over-under weave height field: `threads` threads per tile in each direction."""
    cell = SIZE / threads
    rows = np.arange(h, dtype=np.float32)[:, None] * np.ones((1, w), np.float32)
    cols = np.ones((h, 1), np.float32) * np.arange(w, dtype=np.float32)[None, :]
    i, j = (cols // cell).astype(int), (rows // cell).astype(int)
    fu, fv = (cols % cell) / cell, (rows % cell) / cell
    slub_u = 0.8 + 0.4 * fractal(h, w, 4, threads, rng, 2)  # thickness wander of the vertical threads
    slub_v = 0.8 + 0.4 * fractal(h, w, threads, 4, rng, 2)
    prof_warp = np.clip(np.sin(math.pi * fu), 0, 1) ** flat * slub_u  # thread across U (vertical thread)
    prof_weft = np.clip(np.sin(math.pi * fv), 0, 1) ** flat * slub_v
    over = ((i + j) % 2 == 0)
    # the thread on top bulges along its length too (it dips where it goes under)
    along_warp = 0.6 + 0.4 * np.sin(math.pi * fv)
    along_weft = 0.6 + 0.4 * np.sin(math.pi * fu)
    hw = prof_warp * np.where(over, along_warp, 0.55)
    hf = prof_weft * np.where(over, 0.55, along_weft)
    return np.maximum(hw, hf), over


def tex_cloth_canvas(rng):
    h = w = SIZE
    weave, _ = _weave(h, w, 64, rng)
    mott = fractal(h, w, 5, 5, rng, 4)
    dark = 0.6 * (1 - weave) + 0.35 * (1 - mott)
    height = 0.6 * weave + 0.1 * mott
    color = color_from_darkness(dark, mean=0.90)
    rough = np.clip(0.86 + 0.08 * (1 - weave), 0, 1)
    return {"color": gray3(color), "normal": normal_map(height, 2.5), "roughness": rough}


def tex_straw_woven(rng):
    """Woven straw strips (32 per tile = 1/8 stud each), fibres along each strip, darker gaps, per-strip tone."""
    h = w = SIZE
    strips = 32
    cell = SIZE / strips
    rows = np.arange(h, dtype=np.float32)[:, None] * np.ones((1, w), np.float32)
    cols = np.ones((h, 1), np.float32) * np.arange(w, dtype=np.float32)[None, :]
    i, j = (cols // cell).astype(int), (rows // cell).astype(int)
    fu, fv = (cols % cell) / cell, (rows % cell) / cell
    over = ((i // 1 + j // 1) % 2 == 0)
    fib_v = fractal(h, w, 8, 128, rng, 2)  # fibres along V (vertical strips)
    fib_u = fractal(h, w, 128, 8, rng, 2)  # fibres along U
    gap_u = np.minimum(fu, 1 - fu)
    gap_v = np.minimum(fv, 1 - fv)
    tone_v = rng.uniform(0, 0.25, strips)[i % strips]
    tone_u = rng.uniform(0, 0.25, strips)[j % strips]
    # on each cell either the vertical or the horizontal strip is visible
    gap = np.where(over, line_mask(gap_u * cell, 1.4), line_mask(gap_v * cell, 1.4))
    fib = np.where(over, fib_v, fib_u)
    tone = np.where(over, tone_v, tone_u)
    curve = np.where(over, np.sin(math.pi * fv), np.sin(math.pi * fu))  # strip dips under its neighbour
    dark = 0.55 * fib + tone * 1.8 + 1.4 * gap + 0.35 * (1 - curve)
    height = 0.35 + 0.45 * curve - 0.15 * fib - 0.5 * gap
    color = color_from_darkness(dark, mean=0.88)
    rough = np.clip(0.78 + 0.12 * norm01(dark), 0, 1)
    return {"color": gray3(color), "normal": normal_map(height, 3.0), "roughness": rough}


def tex_bone_ivory(rng):
    h = w = SIZE
    mott = fractal(h, w, 4, 4, rng, 5)
    pores = np.clip((fractal(h, w, 160, 160, rng, 2) - 0.68) * 6, 0, 1)
    f1, f2, _ = worley(h, w, 18, rng)
    gate = fractal(h, w, 6, 6, rng, 2) > 0.6
    crack = line_mask(f2 - f1, 1.1) * gate
    dark = 0.6 * (1 - mott) + 0.4 * pores + 1.4 * crack
    height = 0.5 + 0.15 * mott - 0.25 * pores - 0.45 * crack
    color = color_from_darkness(dark, mean=0.92)
    rough = np.clip(0.55 + 0.12 * norm01(dark), 0, 1)
    return {"color": gray3(color), "normal": normal_map(height, 2.0), "roughness": rough}


def tex_water_ripple(rng):
    """RGBA overlay for a scrolling Texture on water surfaces: white caustic lines, alpha 0..0.6."""
    f1, f2, _ = worley(SIZE, SIZE, 0, rng, grid=7)
    lines = line_mask(f2 - f1, 2.2)
    soft = blur(lines, 2)
    a = np.clip(0.55 * soft + 0.25 * lines, 0, 0.6)
    rgb = np.ones((SIZE, SIZE, 3))
    return {"color_rgba": np.concatenate([rgb, a[..., None]], axis=2)}


# family -> (generator, seed, maps written, tint used on the preview sheet)
SETS = {
    "wood_grain": (tex_wood_grain, 11, "#C46C35"),
    "wood_planks": (tex_wood_planks, 12, "#8E4524"),
    "metal_iron": (tex_metal_iron, 13, "#5C626E"),
    "metal_riveted": (tex_metal_riveted, 14, "#55607F"),
    "stone_rough": (tex_stone_rough, 15, "#8D9CAC"),
    "stone_blocks": (tex_stone_blocks, 16, "#B4BABC"),
    "cloth_canvas": (tex_cloth_canvas, 17, "#C42329"),
    "straw_woven": (tex_straw_woven, 18, "#D2C46C"),
    "bone_ivory": (tex_bone_ivory, 19, "#E6E3D3"),
    "water_ripple": (tex_water_ripple, 20, "#34D6EC"),
}


def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def _seam_error(a):
    """Largest jump across the wrap edge relative to the 99th percentile of jumps inside the image."""
    a = np.asarray(a, np.float32)
    inner = np.abs(np.diff(a, axis=1)).reshape(-1)
    edge = np.abs(a[:, 0] - a[:, -1]).reshape(-1)
    inner_v = np.abs(np.diff(a, axis=0)).reshape(-1)
    edge_v = np.abs(a[0] - a[-1]).reshape(-1)
    return round(float(max(np.percentile(edge, 99) / max(1e-6, np.percentile(inner, 99)),
                           np.percentile(edge_v, 99) / max(1e-6, np.percentile(inner_v, 99)))), 2)


def _sheet_cell(maps, tint, cell=256):
    """2 x 2 tiles of the set at half size, tinted and lit by its own normal map (light from the top-left)."""
    if "color_rgba" in maps:
        rgba = maps["color_rgba"]
        base = np.ones((SIZE, SIZE, 3)) * _hex(tint)
        rgb = base * (1 - rgba[..., 3:4]) + rgba[..., :3] * rgba[..., 3:4]
    else:
        n = maps["normal"] * 2 - 1
        light = np.array([-0.45, 0.55, 0.70])
        light = light / np.linalg.norm(light)
        lit = np.clip((n * light).sum(axis=2), 0, 1)
        rgb = maps["color"] * _hex(tint) * (0.45 + 0.75 * lit)[..., None]
        if "metalness" in maps:
            rgb = rgb * (0.85 + 0.3 * (1 - maps["roughness"]))[..., None]
    tile = np.tile(np.clip(rgb, 0, 1), (2, 2, 1))
    f = tile.shape[0] // cell
    return tile.reshape(cell, f, cell, f, 3).mean(axis=(1, 3))


def generate():
    os.makedirs(OUT, exist_ok=True)
    info = {"size": SIZE, "studsPerTile": STUDS_PER_TILE, "normalFormat": "OpenGL tangent space (+Y = +V)",
            "note": "ColorMaps are neutral gray; tint = target colour / colorMean (SurfaceAppearance.Color multiplies)",
            "sets": {}}
    cells = []
    for name, (fn, seed, tint) in SETS.items():
        rng = np.random.default_rng(seed)
        maps = fn(rng)
        files, entry = {}, {}
        if "color_rgba" in maps:
            path = os.path.join(OUT, f"{name}_color.png")
            write_png(path, to_u8(maps["color_rgba"]))
            files["ColorMap"] = os.path.basename(path)
            entry["alphaMean"] = round(float(maps["color_rgba"][..., 3].mean()), 3)
            entry["seam"] = _seam_error(maps["color_rgba"][..., 3])
        else:
            write_png(os.path.join(OUT, f"{name}_color.png"), to_u8(maps["color"]))
            write_png(os.path.join(OUT, f"{name}_normal.png"), to_u8(maps["normal"]))
            write_png(os.path.join(OUT, f"{name}_roughness.png"), to_u8(maps["roughness"]))
            files["ColorMap"] = f"{name}_color.png"
            files["NormalMap"] = f"{name}_normal.png"
            files["RoughnessMap"] = f"{name}_roughness.png"
            if "metalness" in maps:
                write_png(os.path.join(OUT, f"{name}_metalness.png"), to_u8(maps["metalness"]))
                files["MetalnessMap"] = f"{name}_metalness.png"
            if "_polished" in maps:
                write_png(os.path.join(OUT, "metal_polished_roughness.png"), to_u8(maps["_polished"]))
                files["PolishedRoughnessMap"] = "metal_polished_roughness.png"
            entry["colorMean"] = round(float(maps["color"][..., 0].mean()), 4)
            entry["colorMin"] = round(float(maps["color"][..., 0].min()), 3)
            entry["roughnessMean"] = round(float(maps["roughness"].mean()), 3)
            entry["seam"] = _seam_error(maps["color"][..., 0])
        entry["files"] = files
        info["sets"][name] = entry
        cells.append(_sheet_cell(maps, tint))
    # keep the uploaded asset ids of an earlier run (re-generating the pixels does not change the ids;
    # re-upload and replace them when a map really changes)
    path = os.path.join(OUT, "textures.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            old = json.load(f)
        for key in ("assetIds", "uploaded"):
            if key in old:
                info[key] = old[key]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(info, f, indent=1)
    # contact sheet: 5 columns
    cols = 5
    rows_n = (len(cells) + cols - 1) // cols
    cell = cells[0].shape[0]
    pad = 8
    sheet = np.ones((rows_n * (cell + pad) + pad, cols * (cell + pad) + pad, 3)) * 0.86
    for k, c in enumerate(cells):
        r, q = divmod(k, cols)
        y0, x0 = pad + r * (cell + pad), pad + q * (cell + pad)
        sheet[y0:y0 + cell, x0:x0 + cell] = c
    write_png(SHEET, to_u8(sheet))
    return info


if __name__ == "__main__":
    result = generate()
    print("TEXTURES " + json.dumps({k: {kk: vv for kk, vv in v.items() if kk != "files"} for k, v in result["sets"].items()}))
