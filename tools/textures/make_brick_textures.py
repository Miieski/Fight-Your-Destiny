"""Boss-room brick textures (round 6, task B): tileable low-poly brick images for the Desert and Jungle sub-zone 4
interiors and boss arenas. Colours are read from the zones' door / gate templates (docs/prop_texture_guide.md,
"Boss room brick"). Procedural and deterministic: python tools/textures/make_brick_textures.py

Layout of every tile: 256 x 256 px = 8 x 8 studs = 4 rows x 2 bricks (running bond), so StudsPerTileU = V = 8.
The overlay strips are 256 x 1024 px = 8 x 32 studs with only ONE brick row painted (alpha elsewhere): put them as a
second Texture on the same face with StudsPerTileV = 32 and OffsetStudsV to move the row (frieze near the top,
moss row near the bottom).
"""
import os
import random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
TILE, ROWS, PER_ROW = 256, 4, 2
BW, BH = TILE // PER_ROW, TILE // ROWS  # 128 x 64 px brick = 4 x 2 studs
JOINT = 4
BEVEL = 6


def hexrgb(h):
	h = h.lstrip("#")
	return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
	return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(c, k):
	return tuple(max(0, min(255, int(round(v * k)))) for v in c)


def brick(draw, x0, y0, w, h, base, rng, cracks=True):
	"""One bevelled brick at (x0, y0) (joint already around it): flat face with a soft top-to-bottom gradient,
	2-step bevels (light top / left, dark bottom / right), a chip or a crack sometimes."""
	x1, y1 = x0 + w - 1, y0 + h - 1
	for y in range(y0, y1 + 1):  # soft vertical gradient on the face
		t = (y - y0) / max(1, h - 1)
		draw.line([(x0, y), (x1, y)], fill=shade(base, 1.06 - 0.12 * t))
	hi1, hi2 = shade(base, 1.22), shade(base, 1.12)
	lo1, lo2 = shade(base, 0.70), shade(base, 0.84)
	half = BEVEL // 2
	for i in range(BEVEL):
		top = hi1 if i < half else hi2
		bot = lo1 if i < half else lo2
		draw.line([(x0 + i, y0 + i), (x1 - i, y0 + i)], fill=top)  # top
		draw.line([(x0 + i, y0 + i), (x0 + i, y1 - i)], fill=top)  # left
		draw.line([(x0 + i, y1 - i), (x1 - i, y1 - i)], fill=bot)  # bottom
		draw.line([(x1 - i, y0 + i), (x1 - i, y1 - i)], fill=bot)  # right
	r = rng.random()
	dark = shade(base, 0.55)
	if cracks and r < 0.18:  # a thin crack from an edge
		x, y = x0 + rng.randint(BEVEL + 4, w - BEVEL - 8), y0 + BEVEL
		pts = [(x, y)]
		for _ in range(rng.randint(3, 5)):
			x += rng.randint(-8, 8)
			y += rng.randint(5, 10)
			if y > y1 - BEVEL:
				break
			pts.append((x, y))
		draw.line(pts, fill=dark, width=2)
	elif r < 0.32:  # a chipped corner (joint colour triangle)
		cx = x0 if rng.random() < 0.5 else x1
		cy = y0 if rng.random() < 0.5 else y1
		s = rng.randint(7, 12)
		dx = s if cx == x0 else -s
		dy = s if cy == y0 else -s
		draw.polygon([(cx, cy), (cx + dx, cy), (cx, cy + dy)], fill=dark)


def bricks(path_name, palette, joint, seed, row_filter=None, size=(TILE, TILE), alpha=False, row_colour=None):
	"""Running bond. palette = list of brick colours (picked per brick with a little extra jitter).
	row_filter(row) -> paint this row? (None = all rows). row_colour(row, col, rng) overrides the colour."""
	rng = random.Random(seed)
	W, H = size
	img = Image.new("RGBA", size, (0, 0, 0, 0) if alpha else joint + (255,))
	draw = ImageDraw.Draw(img)
	rows = H // BH
	for row in range(rows):
		if row_filter and not row_filter(row):
			continue
		y0 = row * BH
		if alpha:
			draw.rectangle([0, y0, W - 1, y0 + BH - 1], fill=joint + (255,))
		off = (BW // 2) if row % 2 else 0
		for col in range(-1, W // BW + 1):
			c = row_colour(row, col, rng) if row_colour else rng.choice(palette)
			c = shade(c, 0.94 + rng.random() * 0.12)
			x0 = col * BW + off + JOINT // 2
			# wrap horizontally so the tile is seamless
			for shift in (-W, 0, W):
				xs = x0 + shift
				if xs + BW - JOINT < 0 or xs >= W:
					continue
				brick(draw, xs, y0 + JOINT // 2, BW - JOINT, BH - JOINT, c, random.Random(rng.random()))
	os.makedirs(OUT, exist_ok=True)
	img.save(os.path.join(OUT, path_name))
	return img


# ---- Desert: pylon_temple_gate sandstone (#9D7C53 / #9A7A52 / #8E714B / #B58E59), joints from its dark trim
# #703E26 (softened to #6A4A2E), frieze blue #2C5CC8 + gold #FFC93C from the gate / door panels.
DESERT = [hexrgb(h) for h in ("#9D7C53", "#9A7A52", "#8E714B", "#A6845A", "#B58E59")]
DESERT_JOINT = hexrgb("#6A4A2E")
FRIEZE = [hexrgb("#2C5CC8"), hexrgb("#FFC93C")]

# ---- Jungle: face_temple_gate / jungle_gate_boss_gate stone (#5C645C / #606960 / #686D62 / #71766A / #848A7C),
# joints darker green-grey #3E453E, moss #5B9C44 / #579441 mixed into the stone for the moss row.
JUNGLE = [hexrgb(h) for h in ("#5C645C", "#606960", "#686D62", "#71766A", "#6A7266")]
JUNGLE_JOINT = hexrgb("#3E453E")
MOSS = [hexrgb("#5B9C44"), hexrgb("#579441")]


def main():
	bricks("desert_brick.png", DESERT, DESERT_JOINT, 11)
	# frieze strip: one row of alternating blue / gold bricks (row 1 of 16 in an 8 x 32 stud strip)
	bricks("desert_frieze_strip.png", DESERT, DESERT_JOINT, 12, row_filter=lambda r: r == 1, size=(TILE, 1024), alpha=True,
		row_colour=lambda r, c, rng: FRIEZE[c % 2])
	bricks("jungle_brick.png", JUNGLE, JUNGLE_JOINT, 21)
	# moss strip: one row of moss-tinted stone (row 14 of 16, i.e. near the bottom of a 32-stud strip)
	bricks("jungle_moss_strip.png", JUNGLE, JUNGLE_JOINT, 22, row_filter=lambda r: r == 14, size=(TILE, 1024), alpha=True,
		row_colour=lambda r, c, rng: mix(rng.choice(JUNGLE), rng.choice(MOSS), 0.35 + rng.random() * 0.3))
	print("written to", OUT)


if __name__ == "__main__":
	main()
