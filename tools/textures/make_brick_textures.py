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


def bricks(path_name, palette, joint, seed, row_filter=None, size=(TILE, TILE), alpha=False, row_colour=None, cracks=True):
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
				brick(draw, xs, y0 + JOINT // 2, BW - JOINT, BH - JOINT, c, random.Random(rng.random()), cracks)
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


# ---- Desert, owner fix 2026-10-26 ("lighter, less orange-red"): the Desert_4 entrance gate's stone #9D7C53 lifted
# toward its own light carving / barrier / sand colours (#B58E59, #E2BE84, #F4D07C) and pulled toward yellow-beige.
DESERT_LIGHT = [hexrgb(h) for h in ("#CDB283", "#C6AA79", "#D4BA8C", "#BFA372", "#C9AE7E")]
DESERT_LIGHT_JOINT = hexrgb("#8C7350")

# ---- Desert marble floor: warm ivory / cream slabs with beige-gold veins, gold-bronze inlay lines, a few sand-brown
# slabs. Jungle flagstones: the jungle stone family with dark joints and moss in some joints / corners.
MARBLE = [hexrgb(h) for h in ("#EDE3CC", "#E8DCC1", "#F1E8D4", "#E4D6B8")]
MARBLE_DARK = [hexrgb("#BFA27A"), hexrgb("#B59873")]
MARBLE_VEIN = hexrgb("#CDB27E")
INLAY = hexrgb("#B08A3E")
FLAG = [hexrgb(h) for h in ("#626A60", "#686F65", "#5D655C", "#70776B", "#666E66")]
FLAG_JOINT = hexrgb("#2F352F")


def bevel_slab(draw, x0, y0, x1, y1, base, bev=5):
	"""A flat slab with a soft gradient and a 2-step bevel (the bricks' look, wider pieces)."""
	h = y1 - y0
	for y in range(y0, y1 + 1):
		t = (y - y0) / max(1, h)
		draw.line([(x0, y), (x1, y)], fill=shade(base, 1.04 - 0.08 * t))
	for i in range(bev):
		top = shade(base, 1.14 if i < bev // 2 else 1.07)
		bot = shade(base, 0.78 if i < bev // 2 else 0.88)
		draw.line([(x0 + i, y0 + i), (x1 - i, y0 + i)], fill=top)
		draw.line([(x0 + i, y0 + i), (x0 + i, y1 - i)], fill=top)
		draw.line([(x0 + i, y1 - i), (x1 - i, y1 - i)], fill=bot)
		draw.line([(x1 - i, y0 + i), (x1 - i, y1 - i)], fill=bot)


def marble(path_name, seed, n=4, size=512):
	"""size px = n x n slabs (512 px, 4 x 4 slabs -> 28 x 28 studs at 7 studs a slab). Slab = soft cream face with
	2-3 meandering beige-gold veins; 3 px gold-bronze inlay lines between slabs; 2 slabs in sand brown."""
	rng = random.Random(seed)
	img = Image.new("RGB", (size, size), INLAY)
	draw = ImageDraw.Draw(img)
	s = size // n
	dark = set(rng.sample(range(n * n), 2))
	for j in range(n):
		for i in range(n):
			base = rng.choice(MARBLE_DARK) if j * n + i in dark else rng.choice(MARBLE)
			x0, y0, x1, y1 = i * s + 2, j * s + 2, (i + 1) * s - 2, (j + 1) * s - 2
			bevel_slab(draw, x0, y0, x1, y1, base, bev=3)
			for _ in range(rng.randint(1, 2)):  # soft cloudy patches, a shade lighter
				cx, cy, r = rng.randint(x0 + 20, x1 - 20), rng.randint(y0 + 20, y1 - 20), rng.randint(14, 30)
				draw.ellipse([cx - r, cy - r // 2, cx + r, cy + r // 2], fill=shade(base, 1.03))
			vein = mix(base, MARBLE_VEIN, 0.4)
			for _ in range(rng.randint(1, 2)):  # veins: soft diagonal polylines that stay inside the slab
				x, y = x0 + rng.randint(4, s // 3), y0 + rng.randint(4, s // 3)
				pts = [(x, y)]
				while x < x1 - 8 and y < y1 - 8:
					x += rng.randint(8, 20)
					y += rng.randint(4, 18)
					pts.append((min(x, x1 - 4), min(y, y1 - 4)))
				draw.line(pts, fill=vein, width=rng.choice((1, 2, 2, 3)))
				if len(pts) > 3:  # a thinner branch
					bx, by = pts[len(pts) // 2]
					draw.line([(bx, by), (min(x1 - 4, bx + rng.randint(10, 24)), max(y0 + 4, by - rng.randint(8, 20)))], fill=mix(base, vein, 0.6), width=1)
	img.save(os.path.join(OUT, path_name))


def flagstones(path_name, seed, size=512, rows=4):
	"""Irregular-rectangle flagstones, tileable: rows of equal height, each row cut into slabs of random width
	(wrapping round the tile edge), 4 px dark joints, bevels, chips, a crack now and then, moss in some joints."""
	rng = random.Random(seed)
	img = Image.new("RGB", (size, size), FLAG_JOINT)
	draw = ImageDraw.Draw(img)
	rh = size // rows
	moss_spots = []
	for r in range(rows):
		y0, y1 = r * rh + 2, (r + 1) * rh - 3
		start = rng.randint(0, size // 4)
		widths, total = [], 0
		while total < size:
			w = rng.randint(int(rh * 0.8), int(rh * 1.4))
			if size - total - w < rh * 0.7:
				w = size - total
			widths.append(w)
			total += w
		x = start
		for w in widths:
			base = shade(rng.choice(FLAG), 0.95 + rng.random() * 0.1)
			for shift in (-size, 0):  # wrap at the right edge
				xa, xb = x + shift + 2, x + shift + w - 3
				if xb < 0 or xa >= size:
					continue
				bevel_slab(draw, xa, y0, xb, y1, base, bev=5)
				if rng.random() < 0.35:  # chip
					cx, cy = (xa, y0) if rng.random() < 0.5 else (xb, y1)
					d = rng.randint(6, 11) * (1 if cx == xa else -1)
					draw.polygon([(cx, cy), (cx + d, cy), (cx, cy + d)], fill=FLAG_JOINT)
				if rng.random() < 0.2:  # crack
					px, py = rng.randint(xa + 10, max(xa + 11, xb - 10)), y0 + 6
					pts = [(px, py)]
					for _ in range(4):
						px += rng.randint(-10, 10)
						py += rng.randint(8, 16)
						if py > y1 - 6:
							break
						pts.append((px, py))
					draw.line(pts, fill=shade(base, 0.55), width=2)
			moss_spots.append((x % size, y0))
			x += w
	for (mx, my) in rng.sample(moss_spots, max(1, len(moss_spots) // 2)):  # moss tufts in joints / corners
		my += rng.choice((0, rh - 4))
		col = mix(rng.choice(MOSS), FLAG_JOINT, 0.25)
		for k in range(rng.randint(5, 9)):
			ox, oy = mx + rng.randint(-14, 14), my + rng.randint(-6, 6)
			r = rng.randint(3, 7)
			for sx in (-size, 0, size):
				draw.ellipse([ox + sx - r, oy - r, ox + sx + r, oy + r], fill=col)
	img.save(os.path.join(OUT, path_name))


# ---- Tundra ice castle (round 7): the castle gate's ice blocks as built (PropsTundraGatesData "Gate4": Tower / Wall
# #54A0E8 x1.06 x tone 1 / 0.93 / 0.86 x height gradient), joints = the gate's deep core #2860AA. One tile for outside
# and inside; the interior walls take a darker Color3.
ICE = [hexrgb(h) for h in ("#4D93D5", "#4889C6", "#539EE5", "#4D93D5", "#4788C5", "#427EB7")]
ICE_JOINT = hexrgb("#2860AA")


def main():
	os.makedirs(OUT, exist_ok=True)
	bricks("desert_brick.png", DESERT, DESERT_JOINT, 11)
	# frieze strip: one row of alternating blue / gold bricks (row 1 of 16 in an 8 x 32 stud strip)
	bricks("desert_frieze_strip.png", DESERT, DESERT_JOINT, 12, row_filter=lambda r: r == 1, size=(TILE, 1024), alpha=True,
		row_colour=lambda r, c, rng: FRIEZE[c % 2])
	bricks("jungle_brick.png", JUNGLE, JUNGLE_JOINT, 21)
	# moss strip: one row of moss-tinted stone (row 14 of 16, i.e. near the bottom of a 32-stud strip)
	bricks("jungle_moss_strip.png", JUNGLE, JUNGLE_JOINT, 22, row_filter=lambda r: r == 14, size=(TILE, 1024), alpha=True,
		row_colour=lambda r, c, rng: mix(rng.choice(JUNGLE), rng.choice(MOSS), 0.35 + rng.random() * 0.3))
	# owner fix 2026-10-26: lighter desert walls (+ the frieze strip with the lighter joint), marble / flagstone floors
	bricks("desert_brick_light.png", DESERT_LIGHT, DESERT_LIGHT_JOINT, 13)
	bricks("desert_frieze_strip_light.png", DESERT_LIGHT, DESERT_LIGHT_JOINT, 14, row_filter=lambda r: r == 1,
		size=(TILE, 1024), alpha=True, row_colour=lambda r, c, rng: FRIEZE[c % 2])
	marble("desert_marble_floor.png", 31)
	flagstones("jungle_flagstone_floor.png", 41)
	bricks("tundra_ice_brick.png", ICE, ICE_JOINT, 51, cracks=False)  # ice: chips only, no dark cracks
	print("written to", OUT)


if __name__ == "__main__":
	main()
