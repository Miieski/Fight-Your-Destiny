"""Round 8 part 7: the tileable ground textures (256 px, soft shading, low-mid poly look). No external image, all drawn here.

  python tools/make_floor_textures.py          writes docs/floor_textures/*.png and docs/floor_textures/sheet.png (preview)
  python tools/make_floor_textures.py --cave   writes only the mine images of Round 9 part 3
  python tools/make_floor_textures.py --jungle writes only the jungle ground set of Round 9 part 9
  python tools/make_floor_textures.py --tundra writes only the frozen lake and ice ramp images of Round 9 parts 10 and 11
  python tools/make_floor_textures.py --hub    writes only the hub ground set of Round 9 part 13

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


def stones(seed, per_side, joint, palette, relief=0.2, jitter=0.3, rows=None, offset=False, moss=0.0, joint_width=0.09):
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
			t = min(1, edge / (S / per_side * joint_width))
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


def blob_points(x, y, r, k, a, seed, corners=9):
	"""An uneven flat stone."""
	wob = random.Random(seed)
	points = []
	for i in range(corners):
		t = i / corners * math.tau
		q = r * wob.uniform(0.82, 1.1)
		px, py = math.cos(t) * q, math.sin(t) * q * k
		points.append((x + px * math.cos(a) - py * math.sin(a), y + px * math.sin(a) + py * math.cos(a)))
	return points


def moss_wash(im, seed, amount, tones=("5f8f3e", "4a7a38"), strength=0.8):
	"""Round 9 part 9: large soft moss areas over a stone image, the same two greens everywhere, tileable."""
	field = stretch(fbm(seed, 3, 3))
	detail = stretch(fbm(seed + 1, 12, 2))
	a, b = hexrgb(tones[0]), hexrgb(tones[1])
	source = im.convert("RGB")
	limit = 1 - amount

	def pixel(x, y):
		base = source.getpixel((x, y))
		t = max(0, min(1, (field[y][x] + (detail[y][x] - 0.5) * 0.18 - limit) / 0.1))
		return mix(base, mix(a, b, detail[y][x]), t * strength)

	return image_from(pixel)


def soft_patch(seed, tones, edge=0.3, lobes=9, stretch_x=1.0, opacity=1.0):
	"""Round 9 part 9: one patch for a Decal, not tiled: 3 large tones, an irregular outline, a soft edge, alpha 0 well inside the square."""
	rng = random.Random(seed)
	wobble = [rng.uniform(0.62, 1.0) for _ in range(lobes)]
	warp = stretch(fbm(seed + 1, 5, 3))
	tone = stretch(fbm(seed + 2, 4, 2))
	fine = stretch(fbm(seed + 3, 24, 2))
	colors = [hexrgb(t) for t in tones]
	pixels = []
	for y in range(S):
		for x in range(S):
			dx, dy = (x - S / 2) / (S / 2) / stretch_x, (y - S / 2) / (S / 2)
			t = (math.atan2(dy, dx) / math.tau + 0.5) * lobes
			i = int(t) % lobes
			f = t - int(t)
			f = f * f * (3 - 2 * f)
			rim = lerp(wobble[i], wobble[(i + 1) % lobes], f) * 0.86
			d = math.sqrt(dx * dx + dy * dy) / rim + (warp[y][x] - 0.5) * 0.5 + (fine[y][x] - 0.5) * 0.12
			alpha = max(0, min(1, (1 - d) / edge))
			alpha *= max(0, min(1, (1 - max(abs(x - S / 2), abs(y - S / 2)) / (S / 2)) / 0.08))
			v = tone[y][x]
			color = colors[0] if v < 0.38 else (colors[1] if v < 0.64 else colors[2])
			if 0.33 < v < 0.43:
				color = mix(colors[0], colors[1], (v - 0.33) / 0.1)
			elif 0.59 < v < 0.69:
				color = mix(colors[1], colors[2], (v - 0.59) / 0.1)
			pixels.append(tuple(int(c) for c in color) + (int(alpha * 255 * opacity),))
	im = Image.new("RGBA", (S, S))
	im.putdata(pixels)
	return im


def cobble_fade(seed, palette, moss):
	"""Round 9 part 9: loose cobbles for a Decal across the end of a path: packed at the bottom of the image, thinning out to nothing at the top."""
	rng = random.Random(seed)
	cell = 44
	layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	shade = Image.new("L", (S, S), 0)
	stones_list = []
	for row in range(6):
		for col in range(7):
			x = (col + (0.5 if row % 2 else 0)) * cell + rng.uniform(-5, 5) + 6
			y = S - 14 - row * (cell - 8) + rng.uniform(-5, 5)
			keep = 1.35 - max(0, (S - y) / S) * 1.6
			side = min(x, S - x) / S
			if rng.random() < keep and side > 0.03:
				stones_list.append((x, y, rng.uniform(17, 23) * (0.72 + 0.28 * max(0, keep)), rng.uniform(0.72, 0.9), rng.uniform(0, 3.1), rng.choice(palette), rng.randrange(9999)))
	draw_s = ImageDraw.Draw(shade)
	draw_l = ImageDraw.Draw(layer)
	for x, y, r, k, a, color, sd in stones_list:
		draw_s.polygon(blob_points(x, y + 2.5, r * 1.04, k, a, sd), fill=120)
	shade = shade.filter(ImageFilter.GaussianBlur(3))
	for x, y, r, k, a, color, sd in stones_list:
		draw_l.polygon(blob_points(x, y, r, k, a, sd), fill=hexrgb(color) + (255,))
	alpha = layer.getchannel("A").filter(ImageFilter.GaussianBlur(1.3))
	rgb = layer.convert("RGB").filter(ImageFilter.GaussianBlur(1.3))
	mossy = stretch(fbm(seed + 2, 6, 3))
	rgb = Image.frombytes("RGB", (S, S), bytes(int(c) for q in [mix(rgb.getpixel((x, y)), hexrgb(moss), max(0, (mossy[y][x] - 0.66) * 2.2)) for y in range(S) for x in range(S)] for c in q))
	out = Image.new("RGBA", (S, S), (58, 44, 30, 0))
	out.paste((58, 44, 30, 255), mask=shade)
	top = rgb.convert("RGBA")
	top.putalpha(alpha)
	out.alpha_composite(top)
	return out


HUB_STONE = ["dccdae", "d3c3a2", "e3d6ba", "cbb998"]
HUB_JOINT = "b5a283"
HUB_MOSS = ("6fa84a", "5f8f3e", "7db858")


def smooth(t):
	t = max(0.0, min(1.0, t))
	return t * t * (3 - 2 * t)


def rounded_box(px, py, hx, hy, rad):
	"""Signed distance to a box with round corners: negative inside."""
	qx, qy = abs(px) - hx + rad, abs(py) - hy + rad
	return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - rad


def hub_paint(base, depth, jw, joint, gradient, soft):
	"""One pixel of a hub stone: flat tone, a very light slope across the stone, a soft rim, then the joint. No grain, no shadow."""
	color = tuple(c * (1 + gradient + (soft - 0.5) * 0.05 + 0.03 * (1 - smooth((depth - jw) / 7))) for c in base)
	return mix(joint, color, smooth(depth / jw))


def hub_courses(seed, rows, units, palette=HUB_STONE, joint=HUB_JOINT, radius=0.26, jw=3.4, sizes=(2, 2, 3, 1), wobble=5):
	"""Round 9 part 13: rows of big stones with round corners, each row cut into its own lengths, tileable. Fewer, larger shapes than stones()."""
	rng = random.Random(seed)
	row_h = S / rows
	unit = S / units
	layout = []
	for _ in range(rows):
		cuts, left = [], units
		while left > 0:
			piece = min(rng.choice(sizes), left)
			cuts.append(piece)
			left -= piece
		at, slabs_row = 0, []
		for piece in cuts:
			a = rng.uniform(0, math.tau)
			slabs_row.append((at * unit, (at + piece) * unit, hexrgb(rng.choice(palette)), math.cos(a), math.sin(a), rng.uniform(0.975, 1.025)))
			at += piece
		layout.append((rng.uniform(0, S), slabs_row))
	warp_x, warp_y = fbm(seed + 3, 5, 2), fbm(seed + 5, 5, 2)
	soft = stretch(fbm(seed + 7, 3, 2))
	joint_color = hexrgb(joint)
	pixels = []
	for y in range(S):
		for x in range(S):
			wy = (y + (warp_y[y][x] - 0.5) * wobble * 2) % S
			r = int(wy // row_h) % rows
			shift, slabs_row = layout[r]
			wx = (x + (warp_x[y][x] - 0.5) * wobble * 2 + shift) % S
			for a, b, base, gx, gy, tone in slabs_row:
				if wx < b:
					break
			hx, hy = (b - a) / 2, row_h / 2
			px, py = wx - (a + b) / 2, wy % row_h - hy
			depth = -rounded_box(px, py, hx, hy, min(hx, hy) * radius * 2)
			slope = (px * gx + py * gy) / max(hx, hy) * 0.035
			color = hub_paint(tuple(c * tone for c in base), depth, jw, joint_color, slope, soft[y][x])
			pixels.append(tuple(int(max(0, min(255, c))) for c in color))
	im = Image.new("RGB", (S, S))
	im.putdata(pixels)
	return im


def hub_diamonds(seed, n, palette=HUB_STONE, joint=HUB_JOINT, radius=0.24, jw=3.4):
	"""Round 9 part 13: the same stones laid on the diagonal, for the inner floor: told apart by the pattern, not by another look."""
	rng = random.Random(seed)
	s = S / n
	side = s / math.sqrt(2)
	table = [[(hexrgb(rng.choice(palette)), rng.uniform(0, math.tau), rng.uniform(0.975, 1.025)) for _ in range(2 * n)] for _ in range(2 * n)]
	warp_x, warp_y = fbm(seed + 3, 5, 2), fbm(seed + 5, 5, 2)
	soft = stretch(fbm(seed + 7, 3, 2))
	joint_color = hexrgb(joint)
	pixels = []
	for y in range(S):
		for x in range(S):
			wx, wy = x + (warp_x[y][x] - 0.5) * 8, y + (warp_y[y][x] - 0.5) * 8
			u, v = (wx + wy) / s, (wx - wy) / s
			i, j = math.floor(u), math.floor(v)
			base, a, tone = table[(i + j) % (2 * n)][(i - j) % (2 * n)]
			px, py = (u - i - 0.5) * side, (v - j - 0.5) * side
			depth = -rounded_box(px, py, side / 2, side / 2, side * radius)
			slope = (px * math.cos(a) + py * math.sin(a)) / (side / 2) * 0.035
			color = hub_paint(tuple(c * tone for c in base), depth, jw, joint_color, slope, soft[y][x])
			pixels.append(tuple(int(max(0, min(255, c))) for c in color))
	im = Image.new("RGB", (S, S))
	im.putdata(pixels)
	return im


def hub_rings(seed, courses, palette=HUB_STONE, joint=HUB_JOINT, jw=2.6):
	"""Round 9 part 13: one disc, laid once on the end of a cylinder (tile = diameter): courses of curved stones around the centre. courses = (inner, outer, stones), radius 1 = the rim."""
	rng = random.Random(seed)
	rows = []
	for inner, outer, count in courses:
		rows.append((inner, outer, count, rng.uniform(0, 1), [(hexrgb(rng.choice(palette)), rng.uniform(0.975, 1.025), rng.uniform(-1, 1)) for _ in range(count)]))
	soft = stretch(fbm(seed + 7, 3, 2))
	joint_color = hexrgb(joint)
	R = S / 2
	pixels = []
	for y in range(S):
		for x in range(S):
			dx, dy = x + 0.5 - R, y + 0.5 - R
			rr = math.hypot(dx, dy) / R
			row = next((c for c in rows if rr < c[1]), rows[-1])
			inner, outer, count, turn, stones_row = row
			f = ((math.atan2(dy, dx) / math.tau + 0.5) * count + turn) % count
			i = int(f)
			base, tone, slope = stones_row[i]
			arc = math.tau * max(rr, 0.05) * R / count
			px, py = (f - i - 0.5) * arc, (rr - (inner + outer) / 2) * R
			hx, hy = arc / 2, (outer - inner) * R / 2
			depth = -rounded_box(px, py, hx, hy, min(hx, hy) * 0.5)
			color = hub_paint(tuple(c * tone for c in base), depth, jw, joint_color, slope * 0.03 * py / hy, soft[y][x])
			pixels.append(tuple(int(max(0, min(255, c))) for c in color))
	im = Image.new("RGB", (S, S))
	im.putdata(pixels)
	return im


def hub_rim(seed, inner, count):
	"""Round 9 part 13: a ring of curved stones with an empty middle, laid once on a Transparency 1 disc. A full dark disc 0.06 under the floor beats the floor at a distance (depth precision):
	with nothing drawn in the middle there is nothing to lose to."""
	im = hub_rings(seed, ((0, inner, 3), (inner, 1.5, count))).convert("RGBA")
	R = S / 2
	mask = Image.new("L", (S, S))
	mask.putdata([int(255 * smooth((math.hypot(x + 0.5 - R, y + 0.5 - R) / R - inner + 0.012) / 0.012)) for y in range(S) for x in range(S)])
	im.putalpha(mask)
	return im


def hub_wear(im, seed, cracks, moss, pebbles, joint=HUB_JOINT):
	"""A few painted details: thin soft cracks, small moss in the joints, a few pebbles. Wrapped, so the tile stays seamless."""
	rng = random.Random(seed)
	lines = []
	for _ in range(cracks):
		x, y, a = rng.uniform(0, S), rng.uniform(0, S), rng.uniform(0, math.tau)
		points = [(x, y)]
		for _ in range(rng.randint(3, 5)):
			a += rng.uniform(-0.8, 0.8)
			x, y = x + math.cos(a) * rng.uniform(8, 15), y + math.sin(a) * rng.uniform(8, 15)
			points.append((x, y))
		lines.append(points)
	joint_rgb = hexrgb(joint)
	spots = [(x, y) for x in range(0, S, 2) for y in range(0, S, 2) if sum(abs(a - b) for a, b in zip(im.getpixel((x, y)), joint_rgb)) < 16]
	rng.shuffle(spots)
	tufts = []
	for cx, cy in spots[:moss]:
		for _ in range(5):
			tufts.append((cx + rng.uniform(-6, 6), cy + rng.uniform(-6, 6), rng.uniform(1.6, 3.4), rng.choice(HUB_MOSS)))
	stones_list = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(1.4, 2.6), rng.choice(("c8b694", "bcaa88", "e8dcc4"))) for _ in range(pebbles)]
	crack_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	moss_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

	def paint_cracks(draw, ox, oy):
		for points in lines:
			draw.line([(x + ox, y + oy) for x, y in points], fill=hexrgb("a39070") + (105,), width=1)

	def paint_moss(draw, ox, oy):
		for x, y, r, color in tufts:
			draw.ellipse((x + ox - r, y + oy - r * 0.8, x + ox + r, y + oy + r * 0.8), fill=hexrgb(color) + (150,))
		for x, y, r, color in stones_list:
			draw.ellipse((x + ox - r, y + oy - r * 0.8, x + ox + r, y + oy + r * 0.8), fill=hexrgb(color) + (235,))

	wrap_draw(crack_layer, paint_cracks)
	wrap_draw(moss_layer, paint_moss)
	out = im.convert("RGBA")
	out.alpha_composite(blur_wrap(crack_layer, 0.5))
	out.alpha_composite(blur_wrap(moss_layer, 0.9))
	return out.convert("RGB")


def hub_lane_fade(seed, palette=HUB_STONE, joint=HUB_JOINT):
	"""Round 9 part 13: a lane that wears out. 256 x 128 on a 20 x 10 stud part: packed round stones at the plaza end, thinning to nothing at the portal end, no hard end.
	The first stud at the plaza end stays empty: the lane overlaps the plaza border there, at the same height."""
	W, H, rows = S, S // 2, 3
	row_h = H / rows
	rng = random.Random(seed)
	soft = stretch(fbm(seed + 7, 3, 2))
	joint_color = hexrgb(joint)
	layout = []
	for r in range(rows):
		x, row = rng.uniform(-30, 0), []
		while x < W:
			long = rng.choice((38, 46, 54))
			t = (x + long / 2) / W
			keep = 1.75 - 1.95 * t - (0.3 * t if r != 1 else 0)
			if rng.random() < keep:
				row.append((x, x + long, hexrgb(rng.choice(palette)), rng.uniform(0.975, 1.025), rng.uniform(-1, 1)))
			x += long
		layout.append(row)
	pixels = []
	for y in range(H):
		for x in range(W):
			t = x / W
			side = 1 - abs(y + 0.5 - H / 2) / (H / 2)
			# the bed between the stones: joint colour, gone by 80 % of the length and at the sides
			bed = smooth(t / 0.1) * (1 - smooth((t - 0.38) / 0.42)) * smooth(side / (0.14 + 0.4 * t)) * 0.8
			color, alpha = joint_color, bed
			r = int(y // row_h)
			for a, b, base, tone, slope in layout[r]:
				if a <= x < b:
					hx, hy = (b - a) / 2, row_h / 2
					px, py = x - (a + b) / 2, y % row_h - hy
					depth = -rounded_box(px, py, hx, hy, min(hx, hy) * 0.5)
					if depth > 0:
						stone = hub_paint(tuple(c * tone for c in base), depth, 2.6, joint_color, slope * 0.03 * px / hx, soft[y][x])
						cover = smooth(depth / 2)
						color = mix(color, stone, cover) if alpha > 0 else stone
						alpha = max(alpha, cover)
			alpha *= smooth((x - 14) / 6)
			pixels.append(tuple(int(max(0, min(255, c))) for c in color) + (int(alpha * 255),))
	out = Image.new("RGBA", (W, H))
	out.putdata(pixels)
	return out.transpose(Image.FLIP_LEFT_RIGHT) # a Decal on Top shows the image left at the +X end of the part: +X is the portal side


def hub_set():
	"""The Round 9 part 13 images: one family for the whole hub, 4 stone tones, soft low joints (docs/prop_texture_guide.md "Hub ground")."""
	out = {}
	out["hub_slab"] = hub_wear(hub_courses(301, 4, 8), 311, 3, 2, 5)
	out["hub_diamond"] = hub_wear(hub_diamonds(302, 3), 312, 2, 2, 4)
	out["hub_cobble"] = hub_wear(hub_courses(303, 6, 12, sizes=(2, 2, 3), jw=3.0), 313, 2, 3, 6)
	out["hub_band"] = hub_courses(304, 4, 4, sizes=(2,), radius=0.3, jw=3.2, wobble=2)
	out["hub_ring"] = hub_rings(305, ((0, 0.3, 9), (0.3, 0.5, 16), (0.5, 0.68, 22), (0.68, 0.84, 28), (0.84, 1.5, 34)))
	out["hub_rim"] = hub_rim(310, 0.9, 40)
	out["hub_moss_a"] = soft_patch(306, HUB_MOSS, 0.32, 9)
	out["hub_moss_b"] = soft_patch(307, HUB_MOSS, 0.28, 13)
	out["hub_worn"] = soft_patch(308, ("c8b693", "bfae8c", "d0bf9c"), 0.5, 8, 1.0, 0.8)
	out["hub_lane_fade"] = hub_lane_fade(309)
	return out


JUNGLE_STONE = ["8a9678", "7e8a6e", "96a082", "76826a"]
JUNGLE_JOINT = "62705a"
JUNGLE_MOSS = ("5f8f3e", "4a7a38", "3f6e36")


def jungle_set():
	"""The Round 9 part 9 images: one set for the whole jungle, 3-5 tones, soft low joints, same greens and browns (docs/prop_texture_guide.md "Jungle ground")."""
	out = {}
	out["jungle_cobble"] = stones(201, 5, JUNGLE_JOINT, JUNGLE_STONE, relief=0.1, jitter=0.2, offset=True, moss=0.32, joint_width=0.15)
	out["jungle_slab"] = moss_wash(slabs(202, 3, 3, JUNGLE_JOINT, JUNGLE_STONE, 0.08), 212, 0.2)
	out["jungle_mossy"] = moss_wash(stones(203, 4, JUNGLE_JOINT, JUNGLE_STONE, relief=0.1, jitter=0.22, offset=True, moss=0.4, joint_width=0.15), 213, 0.42)
	dirt = base_ground(204, "7a5a3a", "967250", 0.12)
	dirt = speckle(dirt, 214, 110, ["6a4e34", "a8865c", "84643f"], (1, 2.6), 0.6)
	dirt = speckle(dirt, 224, 22, JUNGLE_STONE, (2.2, 4), 0.8)
	out["jungle_dirt"] = speckle(dirt, 234, 26, ["5f8f3e", "4a7a38"], (1.2, 2.6), 0.55)
	ground = base_ground(205, "2f7f3a", "4a9440", 0.08)
	ground = moss_wash(ground, 215, 0.3, ("3f8a3a", "357c38"), 0.7)
	ground = blades(ground, 225, 160, ["2f7436", "4f9c42", "3b8a3a"], (4, 7))
	out["jungle_moss"] = speckle(ground, 235, 18, ["6c5a34", "5a4a2c"], (0.9, 1.8), 0.5)
	out["jungle_moss_a"] = soft_patch(206, JUNGLE_MOSS, 0.3, 9)
	out["jungle_moss_b"] = soft_patch(207, JUNGLE_MOSS, 0.26, 13)
	out["jungle_dirt_patch"] = soft_patch(208, ("6a4e34", "7a5a3a", "8c6a46"), 0.42, 8, 1.0, 0.92)
	out["jungle_cobble_fade"] = cobble_fade(209, JUNGLE_STONE, "5f8f3e")
	return out


def voronoi_lines(seed, cells, warp_amount=10):
	"""Distance to the nearest cell border, in pixels, wrapped: 0 on a crack line."""
	rng = random.Random(seed)
	points = [(rng.uniform(0, S), rng.uniform(0, S)) for _ in range(cells)]
	warp_x = fbm(seed + 1, 6, 2)
	warp_y = fbm(seed + 2, 6, 2)
	out = []
	for y in range(S):
		row = []
		for x in range(S):
			wx = x + (warp_x[y][x] - 0.5) * warp_amount * 2
			wy = y + (warp_y[y][x] - 0.5) * warp_amount * 2
			a, b = 1e18, 1e18
			for px, py in points:
				dx = abs(wx - px) % S
				dy = abs(wy - py) % S
				dx = min(dx, S - dx)
				dy = min(dy, S - dy)
				d = dx * dx + dy * dy
				if d < a:
					a, b = d, a
				elif d < b:
					b = d
			row.append((math.sqrt(b) - math.sqrt(a)) / 2)
		out.append(row)
	return out


def lake_ice(seed):
	"""Round 9 part 10: one tile, alpha only, over the facets that hold the depth gradient: soft frost, deep cracks (a blue shadow), fine white cracks of 2 depths, trapped bubbles."""
	big = voronoi_lines(seed, 7, 12)
	small = voronoi_lines(seed + 10, 26, 7)
	mask = stretch(fbm(seed + 20, 4, 3))
	frost = stretch(fbm(seed + 21, 5, 4))
	pixels = []
	for y in range(S):
		for x in range(S):
			color, alpha = (232, 246, 255), 0.0
			# frost: pale, large, soft
			alpha = max(0, frost[y][x] - 0.6) * 0.7
			# deep crack: a wide blue shadow beside the line, under the ice
			sy, sx = (y + 3) % S, (x + 2) % S
			deep = max(0, 1 - big[sy][sx] / 6)
			if deep > 0:
				blue = (30, 84, 158)
				k = deep * deep * 0.55
				na = k + alpha * (1 - k)
				color = mix(color, blue, k / max(na, 0.001))
				alpha = na
			# fine lines, the second family only in places
			line = max(0, 1 - big[y][x] / 1.5)
			fine = max(0, 1 - small[y][x] / 1.1) * max(0, min(1, (mask[y][x] - 0.42) / 0.12)) * 0.6
			white = max(line * 0.9, fine)
			if white > 0:
				na = white + alpha * (1 - white)
				color = mix(color, (246, 252, 255), white / max(na, 0.001))
				alpha = na
			pixels.append(tuple(int(c) for c in color) + (int(min(1, alpha) * 255),))
	im = Image.new("RGBA", (S, S))
	im.putdata(pixels)
	# trapped bubbles, wrapped
	rng = random.Random(seed + 30)
	spots = []
	for _ in range(5):
		cx, cy = rng.randrange(S), rng.randrange(S)
		for _ in range(9):
			spots.append((cx + rng.gauss(0, 9), cy + rng.gauss(0, 9), rng.uniform(0.7, 1.9)))
	layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

	def paint(draw, ox, oy):
		for x, y, r in spots:
			draw.ellipse((x + ox - r, y + oy - r, x + ox + r, y + oy + r), fill=(240, 250, 255, 150))

	wrap_draw(layer, paint)
	im.alpha_composite(layer)
	return im


def bubbles(seed):
	"""Round 9 part 10: one cluster of air trapped in the ice, for a Decal: pale rings, soft, rising in a line."""
	rng = random.Random(seed)
	layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	for _ in range(26):
		a, q = rng.uniform(0, math.tau), rng.random() ** 0.7 * 92
		x, y = S / 2 + math.cos(a) * q, S / 2 + math.sin(a) * q * 0.7
		r = rng.uniform(3, 11) * (1 - q / 150)
		draw.ellipse((x - r, y - r, x + r, y + r), fill=(214, 238, 252, 110), outline=(246, 252, 255, 210), width=2)
		draw.ellipse((x - r * 0.5, y - r * 0.6, x - r * 0.1, y - r * 0.2), fill=(255, 255, 255, 220))
	return layer.filter(ImageFilter.GaussianBlur(0.8))


def ramp_packed(seed):
	"""Round 9 part 11: packed snow over ice, tiled on the slope: pale snow, blue worn tracks, low contrast."""
	base = base_ground(seed, "cfe0f4", "eaf3fc", 0.05)
	tracks = stretch(fbm(seed + 1, 4, 3))
	source = base.convert("RGB")
	ice = hexrgb("a8cdee")

	def pixel(x, y):
		t = max(0, min(1, (tracks[y][x] - 0.58) / 0.16)) * 0.65
		return mix(source.getpixel((x, y)), ice, t)

	return speckle(image_from(pixel), seed + 2, 90, ["c0d6ee", "ffffff"], (1, 2.6), 0.5)


def tundra_set():
	"""The Round 9 parts 10 and 11 images."""
	return {
		"lake_ice": lake_ice(301),
		"lake_frost": soft_patch(302, ("e4f2fc", "d4eafa", "f2f9ff"), 0.55, 11, 1.0, 0.85),
		"lake_slush": soft_patch(303, ("f4f8fe", "e2eefa", "cfe2f4"), 0.4, 13, 1.0, 0.95),
		"lake_bubbles": bubbles(304),
		"ramp_packed": ramp_packed(305),
	}


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
	if len(sys.argv) > 1 and sys.argv[1] in ("--cave", "--jungle", "--tundra", "--hub"):
		os.makedirs(OUT, exist_ok=True)
		for name, im in {"--cave": cave_set, "--jungle": jungle_set, "--tundra": tundra_set, "--hub": hub_set}[sys.argv[1]]().items():
			im.save(os.path.join(OUT, name + ".png"), optimize=True)
			print(name)
	else:
		build()
