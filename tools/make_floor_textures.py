"""Round 8 part 7: the tileable ground textures (256 px, soft shading, low-mid poly look). No external image, all drawn here.

  python tools/make_floor_textures.py          writes docs/floor_textures/*.png and docs/floor_textures/sheet.png (preview)
  python tools/make_floor_textures.py --cave   writes only the mine images of Round 9 part 3

Solid ground: drawn in their real colours (Texture.Color3 tints the variants). Fringe: a band with an uneven alpha, laid along a path
edge so grass / sand / moss / snow creeps over the path (alpha 0 on both long sides, so it never shows a seam). Overlays: alpha only.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "floor_textures")
S = 256


def hexrgb(text):
	return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
	return a + (b - a) * t


def mix(a, b, t):
	return tuple(lerp(x, y, t) for x, y in zip(a, b))


def noise(seed, cells):
	"""Periodic value noise, 0..1, as a list of rows."""
	rng = random.Random(seed)
	grid = [[rng.random() for _ in range(cells)] for _ in range(cells)]
	out = []
	for y in range(S):
		fy = y * cells / S
		iy = int(fy)
		ty = fy - iy
		ty = ty * ty * (3 - 2 * ty)
		row0, row1 = grid[iy % cells], grid[(iy + 1) % cells]
		row = []
		for x in range(S):
			fx = x * cells / S
			ix = int(fx)
			tx = fx - ix
			tx = tx * tx * (3 - 2 * tx)
			row.append(lerp(lerp(row0[ix % cells], row0[(ix + 1) % cells], tx), lerp(row1[ix % cells], row1[(ix + 1) % cells], tx), ty))
		out.append(row)
	return out


def fbm(seed, base=4, octaves=4):
	total = [[0.0] * S for _ in range(S)]
	amp, weight = 1.0, 0.0
	for o in range(octaves):
		layer = noise(seed + o * 17, base * 2 ** o)
		for y in range(S):
			row, add = total[y], layer[y]
			for x in range(S):
				row[x] += add[x] * amp
		weight += amp
		amp *= 0.5
	return [[v / weight for v in row] for row in total]


def stretch(field, low=0.0, high=1.0):
	lo = min(min(r) for r in field)
	hi = max(max(r) for r in field)
	return [[lerp(low, high, (v - lo) / (hi - lo)) for v in row] for row in field]


def image_from(fn):
	im = Image.new("RGB", (S, S))
	im.putdata([tuple(int(max(0, min(255, c))) for c in fn(x, y)) for y in range(S) for x in range(S)])
	return im


def wrap_draw(mask, draw_fn):
	"""draw_fn(draw, ox, oy) nine times, so shapes wrap around the tile."""
	draw = ImageDraw.Draw(mask)
	for ox in (-S, 0, S):
		for oy in (-S, 0, S):
			draw_fn(draw, ox, oy)


def blur_wrap(im, radius):
	"""Gaussian blur that keeps the tile seamless."""
	tiled = Image.new(im.mode, (S * 3, S * 3))
	for ox in range(3):
		for oy in range(3):
			tiled.paste(im, (ox * S, oy * S))
	return tiled.filter(ImageFilter.GaussianBlur(radius)).crop((S, S, S * 2, S * 2))


def base_ground(seed, low, high, grain=0.12):
	big = stretch(fbm(seed, 3, 3))
	fine = stretch(fbm(seed + 100, 24, 2))
	low, high = hexrgb(low), hexrgb(high)
	return image_from(lambda x, y: tuple(c * (1 + (fine[y][x] - 0.5) * grain) for c in mix(low, high, big[y][x])))


def speckle(im, seed, count, colors, size=(1, 3), alpha=0.8):
	"""Small soft pebbles or spots, wrapped."""
	rng = random.Random(seed)
	spots = [(rng.randrange(S), rng.randrange(S), rng.uniform(*size), rng.choice(colors)) for _ in range(count)]
	layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

	def paint(draw, ox, oy):
		for x, y, r, color in spots:
			draw.ellipse((x + ox - r, y + oy - r * 0.8, x + ox + r, y + oy + r * 0.8), fill=hexrgb(color) + (int(255 * alpha),))

	wrap_draw(layer, paint)
	out = im.convert("RGBA")
	out.alpha_composite(layer)
	return out.convert("RGB")


def blades(im, seed, count, colors, length=(5, 11)):
	rng = random.Random(seed)
	items = []
	for _ in range(count):
		x, y = rng.randrange(S), rng.randrange(S)
		a = rng.uniform(-0.6, 0.6)
		ln = rng.uniform(*length)
		items.append((x, y, x + math.sin(a) * ln, y - math.cos(a) * ln, rng.choice(colors)))
	layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

	def paint(draw, ox, oy):
		for x, y, x2, y2, color in items:
			draw.line((x + ox, y + oy, x2 + ox, y2 + oy), fill=hexrgb(color) + (150,), width=1)

	wrap_draw(layer, paint)
	out = im.convert("RGBA")
	out.alpha_composite(layer)
	return out.convert("RGB")


def stones(seed, per_side, joint, palette, relief=0.2, jitter=0.3, rows=None, offset=False, moss=0.0):
	"""Cobbles or slabs: a Voronoi cell per stone (Manhattan-free, wraps), soft bevel from the distance to the joint."""
	rng = random.Random(seed)
	rows = rows or per_side
	points = []
	for j in range(rows):
		for i in range(per_side):
			shift = 0.5 if offset and j % 2 else 0
			px = (i + shift + 0.5 + rng.uniform(-jitter, jitter)) * S / per_side
			py = (j + 0.5 + rng.uniform(-jitter, jitter)) * S / rows
			points.append((px, py, hexrgb(rng.choice(palette)), rng.uniform(0.92, 1.08)))
	stretch_y = per_side / rows
	warp_x = fbm(seed + 3, 8, 2)
	warp_y = fbm(seed + 5, 8, 2)
	grain = stretch(fbm(seed + 7, 16, 3))
	mossy = stretch(fbm(seed + 9, 4, 3))
	joint_color = hexrgb(joint)
	moss_color = hexrgb("5f8f3e")
	pixels = []
	bucket = S // per_side
	for y in range(S):
		for x in range(S):
			wx = x + (warp_x[y][x] - 0.5) * 16
			wy = y + (warp_y[y][x] - 0.5) * 16
			best, second, cell = 1e18, 1e18, None
			for p in points:
				dx = abs(wx - p[0]) % S
				dy = abs(wy - p[1]) % S
				dx = min(dx, S - dx)
				dy = min(dy, S - dy) * stretch_y
				if dx > bucket * 2.6 or dy > bucket * 2.6:
					continue
				d = dx * dx + dy * dy
				if d < best:
					best, second, cell = d, best, p
				elif d < second:
					second = d
			edge = (math.sqrt(second) - math.sqrt(best)) / 2
			t = min(1, edge / (S / per_side * 0.09))
			shade = (1 + relief * (min(1, edge / (S / per_side * 0.3)) - 0.6)) * cell[3]
			shade *= 1 + (grain[y][x] - 0.5) * 0.22
			color = tuple(c * shade for c in cell[2])
			if moss and t < 1 and mossy[y][x] > 1 - moss:
				color = mix(moss_color, color, t * 0.6)
			color = mix(joint_color, color, t)
			if moss and mossy[y][x] > 1 - moss * 0.55:
				color = mix(color, moss_color, min(0.7, (mossy[y][x] - (1 - moss * 0.55)) * 5) * (0.5 + grain[y][x] * 0.5))
			pixels.append(tuple(int(max(0, min(255, c))) for c in color))
	im = Image.new("RGB", (S, S))
	im.putdata(pixels)
	return im


def slabs(seed, rows, cols, joint, palette, relief=0.14):
	"""Rectangular cut slabs, staggered rows, lightly worn edges."""
	rng = random.Random(seed)
	colors = [[(hexrgb(rng.choice(palette)), rng.uniform(0.94, 1.06)) for _ in range(cols)] for _ in range(rows)]
	row_shift = [rng.uniform(0.2, 0.8) * (S / cols) if r % 2 else 0 for r in range(rows)]
	warp = fbm(seed + 3, 10, 2)
	grain = stretch(fbm(seed + 7, 16, 3))
	joint_color = hexrgb(joint)
	h, w = S / rows, S / cols
	pixels = []
	for y in range(S):
		for x in range(S):
			wob = (warp[y][x] - 0.5) * 7
			wy = (y + wob) % S
			r = int(wy // h) % rows
			wx = (x + wob + row_shift[r]) % S
			c = int(wx // w) % cols
			edge = min(wy % h, h - wy % h, wx % w, w - wx % w)
			t = min(1, edge / 2.6)
			base, tone = colors[r][c]
			shade = tone * (1 + relief * (min(1, edge / 16) - 0.7)) * (1 + (grain[y][x] - 0.5) * 0.2)
			pixels.append(tuple(int(max(0, min(255, q))) for q in mix(joint_color, tuple(v * shade for v in base), t)))
	im = Image.new("RGB", (S, S))
	im.putdata(pixels)
	return im


def fringe(texture, seed):
	"""The texture with an alpha band: 0 on the long sides (top and bottom rows of the image), uneven in between; tiles along X."""
	edge = stretch(fbm(seed, 6, 4))
	tuft = stretch(fbm(seed + 1, 20, 2))
	alpha = []
	for y in range(S):
		v = (y + 0.5) / S
		for x in range(S):
			# a bump in the middle of the band, pushed up and down by the noise
			band = 1 - abs(v - 0.5) / (0.2 + 0.3 * edge[int(v * 8) * 0 + 128][x])
			a = (band + (tuft[y][x] - 0.5) * 0.7) * 2.2
			alpha.append(int(max(0, min(1, a)) * 255))
	mask = Image.new("L", (S, S))
	mask.putdata(alpha)
	fade = Image.new("L", (S, S))
	fade.putdata([int(255 * min(1, min(y, S - 1 - y) / 36)) for y in range(S) for _ in range(S)])
	mask = Image.composite(mask, Image.new("L", (S, S), 0), fade)
	out = texture.convert("RGBA")
	out.putalpha(mask)
	return out


def overlay_macro(seed):
	"""A big soft blotch, black with alpha, laid over a ground at a long tile to hide its repetition."""
	field = stretch(fbm(seed, 2, 3))
	mask = Image.new("L", (S, S))
	mask.putdata([int(max(0, (v - 0.45)) * 170) for row in field for v in row])
	out = Image.new("RGBA", (S, S), (20, 18, 10, 255))
	out.putalpha(mask)
	return out


def overlay_cracks(seed):
	rng = random.Random(seed)
	lines = []
	for _ in range(5):
		x, y, a = rng.randrange(S), rng.randrange(S), rng.uniform(0, math.tau)
		points = [(x, y)]
		for _ in range(rng.randrange(5, 9)):
			a += rng.uniform(-0.7, 0.7)
			x, y = x + math.cos(a) * rng.uniform(10, 22), y + math.sin(a) * rng.uniform(10, 22)
			points.append((x, y))
		lines.append(points)
	mask = Image.new("L", (S, S), 0)

	def paint(draw, ox, oy):
		for points in lines:
			draw.line([(p[0] + ox, p[1] + oy) for p in points], fill=190, width=2)

	wrap_draw(mask, paint)
	mask = blur_wrap(mask, 0.6)
	out = Image.new("RGBA", (S, S), (30, 24, 20, 255))
	out.putalpha(mask)
	return out


def overlay_prints(seed):
	"""Footprint-like marks, along Y: a walked line. Tiles along X in the game (the part is turned along the path)."""
	rng = random.Random(seed)
	marks = []
	for i in range(8):
		x = (i + 0.5) * S / 8
		y = (S * 0.36 if i % 2 else S * 0.64) + rng.uniform(-10, 10)
		marks.append((x, y))
	mask = Image.new("L", (S, S), 0)

	def paint(draw, ox, oy):
		for x, y in marks:
			draw.ellipse((x + ox - 13, y + oy - 6, x + ox + 8, y + oy + 6), fill=150)
			draw.ellipse((x + ox + 10, y + oy - 5, x + ox + 19, y + oy + 5), fill=130)

	wrap_draw(mask, paint)
	mask = blur_wrap(mask, 1.6)
	out = Image.new("RGBA", (S, S), (150, 170, 200, 255))
	out.putalpha(mask)
	return out


def overlay_leaves(seed):
	rng = random.Random(seed)
	leaves = [(rng.randrange(S), rng.randrange(S), rng.uniform(0, math.tau), rng.uniform(4, 8), rng.choice(["7c8a34", "a08a38", "5c7a30", "8c6a2c"])) for _ in range(46)]
	layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

	def paint(draw, ox, oy):
		for x, y, a, r, color in leaves:
			c, s = math.cos(a), math.sin(a)
			shape = [(x + ox + c * r, y + oy + s * r), (x + ox - s * r * 0.45, y + oy + c * r * 0.45), (x + ox - c * r, y + oy - s * r), (x + ox + s * r * 0.45, y + oy - c * r * 0.45)]
			draw.polygon(shape, fill=hexrgb(color) + (235,))

	wrap_draw(layer, paint)
	return layer


def sand(seed, low, high):
	"""Sand with ripples along Y (the wind lines), soft."""
	big = stretch(fbm(seed, 3, 3))
	warp = stretch(fbm(seed + 2, 4, 3))
	fine = stretch(fbm(seed + 4, 32, 2))
	low, high = hexrgb(low), hexrgb(high)

	def pixel(x, y):
		ripple = 0.5 + 0.5 * math.sin((y / S * 9 + warp[y][x] * 2) * math.tau)
		t = big[y][x] * 0.55 + ripple * 0.45
		return tuple(c * (1 + (fine[y][x] - 0.5) * 0.08) for c in mix(low, high, t))

	return image_from(pixel)


def mine_dirt(seed):
	"""Round 9 part 3: packed dirt and gravel with embedded stones, warm brown-grey, low contrast, soft edges."""
	dirt = base_ground(seed, "6a5642", "8c755a", 0.14)
	rng = random.Random(seed + 1)
	stones_list = [(rng.randrange(S), rng.randrange(S), rng.uniform(5, 11), rng.uniform(0.55, 0.85), rng.uniform(0, 3.1), rng.choice(["7c6b58", "857460", "726250", "8c7a64"])) for _ in range(14)]
	shade = Image.new("L", (S, S), 0)
	top = Image.new("RGBA", (S, S), (125, 107, 86, 0))

	def blob(x, y, r, k, a, grow):
		"""An uneven flat stone, 9 corners."""
		wob = random.Random(int(x * 7 + y))
		points = []
		for i in range(9):
			t = i / 9 * math.tau
			q = (r + grow) * wob.uniform(0.82, 1.1)
			px, py = math.cos(t) * q, math.sin(t) * q * k
			points.append((x + px * math.cos(a) - py * math.sin(a), y + px * math.sin(a) + py * math.cos(a)))
		return points

	def paint_shade(draw, ox, oy):
		for x, y, r, k, a, _ in stones_list:
			draw.polygon(blob(x + ox, y + oy + 1.5, r, k, a, 0.4), fill=26)

	def paint_top(draw, ox, oy):
		for x, y, r, k, a, color in stones_list:
			draw.polygon(blob(x + ox, y + oy, r, k, a, 0), fill=hexrgb(color) + (255,))

	wrap_draw(shade, paint_shade)
	wrap_draw(top, paint_top)
	shade = blur_wrap(shade, 3)
	dark = Image.new("RGB", (S, S), (54, 42, 32))
	out = Image.composite(dark, dirt, shade)
	alpha = blur_wrap(top.getchannel("A"), 1.8)
	top.putalpha(alpha)
	out = out.convert("RGBA")
	out.alpha_composite(top)
	out = speckle(out.convert("RGB"), seed + 2, 150, ["5c4a38", "4e3e30", "a08a70", "8c7a64"], (0.8, 2), 0.7)
	return speckle(out, seed + 3, 34, ["6e6458", "827868", "564a3e"], (2, 3.6), 0.85)


def mine_rock_overlay(seed):
	"""Round 9 part 3: alpha only, over facets that keep their own strata colour: soft patches, cracks, little copper and gold flecks along a vein."""
	rng = random.Random(seed)
	field = stretch(fbm(seed + 1, 4, 3))
	layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	layer.putdata([(30, 24, 18, int(max(0, v - 0.55) * 110)) if v > 0.55 else (230, 214, 190, int(max(0, 0.42 - v) * 80)) for row in field for v in row])
	lines = []
	for _ in range(6):
		x, y, a = rng.randrange(S), rng.randrange(S), rng.uniform(0, math.tau)
		points = [(x, y)]
		for _ in range(rng.randrange(4, 8)):
			a += rng.uniform(-0.8, 0.8)
			x, y = x + math.cos(a) * rng.uniform(10, 24), y + math.sin(a) * rng.uniform(10, 24)
			points.append((x, y))
		lines.append((points, rng.choice((1, 2, 2, 3))))
	cracks = Image.new("L", (S, S), 0)

	def paint(draw, ox, oy):
		for points, width in lines:
			draw.line([(p[0] + ox, p[1] + oy) for p in points], fill=75, width=width)

	wrap_draw(cracks, paint)
	cracks = blur_wrap(cracks, 0.7)
	ink = Image.new("RGBA", (S, S), (26, 20, 16, 255))
	ink.putalpha(cracks)
	layer.alpha_composite(ink)
	veins = []
	for _ in range(2):
		x, y, a = rng.randrange(S), rng.randrange(S), rng.uniform(0, math.tau)
		for _ in range(30):
			a += rng.uniform(-0.25, 0.25)
			x, y = x + math.cos(a) * 5, y + math.sin(a) * 5
			if rng.random() < 0.7:
				veins.append((x + rng.uniform(-3, 3), y + rng.uniform(-3, 3), rng.uniform(1, 2.4), rng.choice(["c8843c", "b87434", "e8c050", "dca848"])))
	glints = Image.new("RGBA", (S, S), (0, 0, 0, 0))

	def paint_veins(draw, ox, oy):
		for x, y, r, color in veins:
			draw.ellipse((x + ox - r, y + oy - r, x + ox + r, y + oy + r), fill=hexrgb(color) + (255,))

	wrap_draw(glints, paint_veins)
	layer.alpha_composite(glints)
	return layer


def mine_puddle(seed):
	"""Round 9 part 3: one damp spot for a Decal, not tiled: dark wet ground, a soft uneven edge, a thin light rim."""
	rng = random.Random(seed)
	wobble = [rng.uniform(0.75, 1.05) for _ in range(9)]
	field = stretch(fbm(seed + 1, 6, 3))
	pixels = []
	for y in range(S):
		for x in range(S):
			dx, dy = (x - S / 2) / (S / 2), (y - S / 2) / (S / 2)
			t = (math.atan2(dy, dx) / math.tau + 0.5) * len(wobble)
			i = int(t) % len(wobble)
			f = t - int(t)
			f = f * f * (3 - 2 * f)
			rim = lerp(wobble[i], wobble[(i + 1) % len(wobble)], f)
			d = math.sqrt(dx * dx + dy * dy) / rim + (field[y][x] - 0.5) * 0.3
			alpha = min(1, max(0, (0.92 - d) / 0.22))
			wet = min(1, max(0, (0.62 - d) / 0.12))
			color = mix((70, 56, 44), (60, 58, 56), wet)
			color = mix(color, (130, 126, 116), 0.3 * max(0, 1 - abs(d - 0.6) / 0.04))
			pixels.append(tuple(int(c) for c in color) + (int(alpha * (120 + 70 * wet)),))
	im = Image.new("RGBA", (S, S))
	im.putdata(pixels)
	return im


def cave_set():
	"""The Round 9 part 3 images (the Round 8 set stays as uploaded)."""
	bed = base_ground(75, "3c3028", "54443a", 0.16)
	bed = speckle(bed, 76, 240, ["2c221c", "6a5a4c", "4a3c32", "7c6c5c"], (1, 3), 0.85)
	return {
		"mine_dirt": mine_dirt(72),
		"mine_rock": mine_rock_overlay(73),
		"mine_railbed": fringe(bed, 77),
		"mine_puddle": mine_puddle(74),
	}


def build():
	os.makedirs(OUT, exist_ok=True)
	out = {}
	# plains
	grass = base_ground(11, "4fa832", "7ccc45", 0.16)
	grass = blades(grass, 12, 900, ["3f9a2c", "8ad850", "66bc3a", "a0dc58"])
	out["grass"] = speckle(grass, 13, 24, ["e8e070", "f4f4e0"], (0.8, 1.4), 0.7)
	dirt = base_ground(21, "b08a58", "d8b47c", 0.2)
	dirt = speckle(dirt, 22, 170, ["8c6c44", "9c7a4e", "e8cc98"], (1, 2.6), 0.75)
	out["dirt"] = speckle(dirt, 23, 36, ["a8a090", "8f8878"], (2.4, 4.4), 0.9)
	# hub
	out["pavers"] = stones(31, 7, "7d6f60", ["c8bca8", "bdb09c", "d4c9b6", "b4a894", "cdbfa6"], relief=0.24, jitter=0.2, offset=True)
	# desert and beach (grey-free: Color3 tints the canyon)
	out["sand"] = sand(41, "e4c278", "f8e2a4")
	out["slabs"] = slabs(42, 4, 3, "a07c4c", ["e2c288", "d8b67a", "ecd096", "d0ac70"])
	# jungle
	soil = base_ground(51, "2e7a34", "4c9a3c", 0.2)
	soil = blades(soil, 52, 500, ["2a6e30", "5cac44", "3e8c38"], (4, 8))
	out["jungle_soil"] = speckle(soil, 53, 60, ["5a4a2c", "6c5a34"], (1, 2.4), 0.7)
	out["mossy_stone"] = stones(54, 5, "3e4a34", ["8c9484", "7c8676", "9aa090", "848c78"], relief=0.24, jitter=0.2, offset=True, moss=0.5)
	# tundra
	snow = base_ground(61, "dbe7f8", "fbfdff", 0.05)
	out["snow"] = speckle(snow, 62, 120, ["c6d6ee", "ffffff"], (1, 3), 0.5)
	out["frost_slabs"] = slabs(63, 4, 3, "9cb4d0", ["cfe0f2", "dcebf8", "c4d8ee", "e4f0fa"], 0.1)
	# Plains_4 cave
	out["cave_rock"] = stones(71, 6, "4a4654", ["757080", "6a6676", "7f7a8a", "625e6e"], relief=0.26, jitter=0.34)
	# fringes
	out["fringe_grass"] = fringe(out["grass"], 81)
	out["fringe_sand"] = fringe(out["sand"], 82)
	out["fringe_moss"] = fringe(out["jungle_soil"], 83)
	out["fringe_snow"] = fringe(out["snow"], 84)
	# overlays
	out["macro_blotch"] = overlay_macro(91)
	out["cracks"] = overlay_cracks(92)
	out["footprints"] = overlay_prints(93)
	out["leaf_litter"] = overlay_leaves(94)
	for name, im in out.items():
		im.save(os.path.join(OUT, name + ".png"), optimize=True)
	cols = 5
	rows = math.ceil(len(out) / cols)
	sheet = Image.new("RGB", (cols * (S + 6), rows * (S + 6)), (70, 110, 60))
	for i, (name, im) in enumerate(out.items()):
		sheet.paste(im.convert("RGB") if im.mode == "RGB" else im, (i % cols * (S + 6), i // cols * (S + 6)), None if im.mode == "RGB" else im)
	sheet.save(os.path.join(OUT, "sheet.png"))
	print(len(out), "textures in", OUT)


if __name__ == "__main__":
	if len(sys.argv) > 1 and sys.argv[1] == "--cave":
		os.makedirs(OUT, exist_ok=True)
		for name, im in cave_set().items():
			im.save(os.path.join(OUT, name + ".png"), optimize=True)
			print(name)
	else:
		build()
