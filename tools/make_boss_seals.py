"""Round 9 part 5: the carved floor seals of the boss rooms (512 px, alpha outside the circle, a Decal on a flat part). No external image, all drawn here.

  python tools/make_boss_seals.py          writes docs/floor_textures/seal_*.png

Same look as the grounds: 3-5 tones, soft shading, low contrast, worn edges. A seal is a list of rings, then a band of glyphs, a motif, dust in the grooves.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "floor_textures")
S = 512
BIG = S * 2


def hexrgb(text):
	return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
	return tuple(x + (y - x) * t for x, y in zip(a, b))


def soft_noise(seed, cells, size=S):
	"""Smooth noise 0..255 as an L image; not tiled, a seal is seen once."""
	rng = random.Random(seed)
	small = Image.new("L", (cells, cells))
	small.putdata([rng.randrange(256) for _ in range(cells * cells)])
	return small.resize((size, size), Image.BICUBIC)


def fbm(seed):
	layers = [soft_noise(seed + i, 6 * 2 ** i) for i in range(4)]
	out = layers[0]
	for i, layer in enumerate(layers[1:], 1):
		out = Image.blend(out, layer, 0.5 ** i * 0.8)
	return out


def polar(x, y):
	dx, dy = x - S / 2, y - S / 2
	return math.sqrt(dx * dx + dy * dy) / (S / 2), math.atan2(dy, dx)


GLYPHS = [
	[[(-0.7, 0), (-0.3, -0.45), (0.3, -0.45), (0.7, 0), (0.3, 0.45), (-0.3, 0.45), (-0.7, 0)], [(0, -0.15), (0.15, 0), (0, 0.15), (-0.15, 0), (0, -0.15)]],  # eye
	[[(0, -0.2), (-0.35, -0.5), (0, -0.85), (0.35, -0.5), (0, -0.2)], [(0, -0.2), (0, 0.85)], [(-0.5, 0.1), (0.5, 0.1)]],  # ankh
	[[(0, -0.85), (0, 0.85)], [(0, -0.4), (0.5, -0.75)], [(0, 0), (-0.5, -0.35)], [(0, 0.4), (0.5, 0.05)]],  # reed
	[[(-0.8, -0.3), (-0.4, 0), (0, -0.3), (0.4, 0), (0.8, -0.3)], [(-0.8, 0.3), (-0.4, 0.6), (0, 0.3), (0.4, 0.6), (0.8, 0.3)]],  # water
	[[(-0.6, 0.7), (0, -0.8), (0.6, 0.7), (-0.6, 0.7)], [(-0.25, 0.1), (0.25, 0.1)]],  # pyramid
	[[(-0.5, -0.7), (0.5, -0.7), (0, 0), (0.5, 0.7), (-0.5, 0.7), (0, 0), (-0.5, -0.7)]],  # hourglass rune
	[[(0, -0.85), (0, 0.85)], [(-0.6, -0.5), (0.6, 0.5)], [(0.6, -0.5), (-0.6, 0.5)]],  # star rune
]


def glyph_band(draw, r0, r1, count, color, width, seed):
	"""A glyph per sector, turned to face the centre (scale 2 canvas)."""
	rng = random.Random(seed)
	mid = (r0 + r1) / 2 * BIG / 2
	size = (r1 - r0) / 2 * BIG / 2 * 0.72
	for i in range(count):
		a = i / count * math.tau
		c, s = math.cos(a), math.sin(a)
		cx, cy = BIG / 2 + c * mid, BIG / 2 + s * mid
		for line in rng.choice(GLYPHS):
			points = []
			for px, py in line:
				# local x along the ring, local y along the radius
				points.append((cx + (-s) * px * size + c * py * size, cy + c * px * size + s * py * size))
			draw.line(points, fill=color + (255,), width=width, joint="curve")


def ring_line(draw, r, width, color):
	d = r * BIG / 2
	draw.ellipse((BIG / 2 - d, BIG / 2 - d, BIG / 2 + d, BIG / 2 + d), outline=color + (255,), width=width)


def spokes(draw, count, r0, r1, width, color, turn=0.0):
	for i in range(count):
		a = i / count * math.tau + turn
		c, s = math.cos(a), math.sin(a)
		draw.line((BIG / 2 + c * r0 * BIG / 2, BIG / 2 + s * r0 * BIG / 2, BIG / 2 + c * r1 * BIG / 2, BIG / 2 + s * r1 * BIG / 2), fill=color + (255,), width=width)


def sun(draw, r, color, core):
	R = BIG / 2
	for i in range(16):
		a = i / 16 * math.tau
		b = 0.09
		long = r * (1.0 if i % 2 == 0 else 0.78)
		tip = (R + math.cos(a) * long * R, R + math.sin(a) * long * R)
		left = (R + math.cos(a - b) * r * 0.5 * R, R + math.sin(a - b) * r * 0.5 * R)
		right = (R + math.cos(a + b) * r * 0.5 * R, R + math.sin(a + b) * r * 0.5 * R)
		draw.polygon((left, tip, right), fill=color + (255,))
	d = r * 0.52 * R
	draw.ellipse((R - d, R - d, R + d, R + d), fill=color + (255,))
	d = r * 0.36 * R
	draw.ellipse((R - d, R - d, R + d, R + d), fill=core + (255,))


def snowflake(draw, r, width, color):
	R = BIG / 2
	for i in range(6):
		a = i / 6 * math.tau + math.pi / 6
		c, s = math.cos(a), math.sin(a)
		draw.line((R, R, R + c * r * R, R + s * r * R), fill=color + (255,), width=width)
		for k in (0.42, 0.68, 0.88):
			px, py = R + c * r * R * k, R + s * r * R * k
			long = r * R * (0.3 - 0.2 * k)
			for t in (0.9, -0.9):
				draw.line((px, py, px + math.cos(a + t) * long, py + math.sin(a + t) * long), fill=color + (255,), width=max(2, width - 2))


def gear(draw, r, teeth, color, hole):
	R = BIG / 2
	points = []
	for i in range(teeth * 4):
		a = i / (teeth * 4) * math.tau
		q = r if i % 4 in (0, 1) else r * 0.84
		points.append((R + math.cos(a) * q * R, R + math.sin(a) * q * R))
	draw.polygon(points, fill=color + (255,))
	d = r * 0.42 * R
	draw.ellipse((R - d, R - d, R + d, R + d), fill=hole + (255,))


def flame_cracks(draw, seed, color):
	rng = random.Random(seed)
	R = BIG / 2
	for i in range(9):
		a = i / 9 * math.tau + rng.uniform(-0.2, 0.2)
		r = 0.1
		x, y = R + math.cos(a) * r * R, R + math.sin(a) * r * R
		points = [(x, y)]
		while r < 0.86:
			a += rng.uniform(-0.3, 0.3)
			r += rng.uniform(0.08, 0.16)
			points.append((R + math.cos(a) * r * R, R + math.sin(a) * r * R))
		draw.line(points, fill=color + (255,), width=rng.choice((5, 7, 9)), joint="curve")


def spiral(draw, turns, r, width, color):
	R = BIG / 2
	points = []
	for i in range(240):
		t = i / 239
		a = t * turns * math.tau
		q = r * (0.08 + 0.92 * t)
		points.append((R + math.cos(a) * q * R, R + math.sin(a) * q * R))
	draw.line(points, fill=color + (255,), width=width, joint="curve")


def seal(name, seed, rings, joints, details, dust, edge=0.985, hollow=0.0, grain=0.16):
	"""rings: (outer radius, colour), joints: (r0, r1, count, colour), details(draw) paints on the big canvas, dust: colour and strength in the grooves."""
	noise = fbm(seed).load()
	wobble = soft_noise(seed + 9, 16).load()
	base = Image.new("RGB", (S, S))
	pixels = base.load()
	for y in range(S):
		for x in range(S):
			r, a = polar(x, y)
			color = rings[-1][1]
			for outer, tone in rings:
				if r <= outer:
					color = tone
					break
			color = hexrgb(color)
			shade = 1 + (noise[x, y] / 255 - 0.5) * grain * 2
			shade *= 1 - 0.08 * max(0, r - 0.8) / 0.2
			color = tuple(c * shade for c in color)
			pixels[x, y] = tuple(int(max(0, min(255, c))) for c in color)
	canvas = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
	draw = ImageDraw.Draw(canvas)
	for r0, r1, count, tone in joints:
		spokes(draw, count, r0, r1, 3, hexrgb(tone), 0.13)
	details(draw)
	small = canvas.resize((S, S), Image.LANCZOS)
	out = base.convert("RGBA")
	out.alpha_composite(small)
	# worn: the carving fades in patches, dust sits in it
	fade = soft_noise(seed + 3, 22).load()
	result = out.load()
	dust_color, strength = hexrgb(dust[0]), dust[1]
	alpha = Image.new("L", (S, S))
	alphas = alpha.load()
	for y in range(S):
		for x in range(S):
			r, a = polar(x, y)
			n = fade[x, y] / 255
			px = result[x, y]
			if n > 0.52:
				t = min(1, (n - 0.52) / 0.3) * strength
				px = tuple(int(v) for v in mix(px[:3], dust_color, t)) + (255,)
				result[x, y] = px
			limit = edge - 0.03 * wobble[x, y] / 255
			inner = hollow + 0.02 * wobble[x, y] / 255 if hollow else -1
			value = min(1, max(0, (limit - r) * S / 4))
			if hollow:
				value *= min(1, max(0, (r - inner) * S / 4))
			alphas[x, y] = int(value * 255)
	out.putalpha(alpha)
	return out


def build():
	os.makedirs(OUT, exist_ok=True)
	out = {}

	def desert(d):
		gold = hexrgb("e0b64c")
		ring_line(d, 0.905, 9, gold)
		ring_line(d, 0.705, 7, gold)
		ring_line(d, 0.685, 3, hexrgb("a07c4c"))
		glyph_band(d, 0.72, 0.895, 22, hexrgb("7c5a30"), 9, 201)
		ring_line(d, 0.3, 11, gold)
		sun(d, 0.25, gold, hexrgb("f0d48a"))

	out["seal_desert"] = seal("desert", 200, [(0.28, "2c56b8"), (0.30, "2c56b8"), (0.70, "d8b47c"), (0.905, "c8a468"), (1.0, "b89458")], [(0.31, 0.68, 12, "a8824c"), (0.91, 0.98, 36, "98764a")], desert, ("e6c684", 0.42))

	def ice(d):
		line = hexrgb("dcf4ff")
		ring_line(d, 0.97, 8, line)
		ring_line(d, 0.78, 5, line)
		glyph_band(d, 0.79, 0.96, 16, hexrgb("c4ecfc"), 8, 211)
		snowflake(d, 0.72, 11, line)

	out["seal_ice"] = seal("ice", 210, [(0.78, "6e96cc"), (1.0, "5a82ba")], [(0.05, 0.76, 8, "4c74ac")], ice, ("eef6ff", 0.26))

	def ice_ring(d):
		line = hexrgb("dcf4ff")
		ring_line(d, 0.985, 7, line)
		ring_line(d, 0.95, 5, line)
		glyph_band(d, 0.952, 0.984, 64, hexrgb("c4ecfc"), 4, 212)

	out["seal_ice_ring"] = seal("ice_ring", 215, [(1.0, "6e96cc")], [], ice_ring, ("eef6ff", 0.4), edge=0.998, hollow=0.94)

	def jungle(d):
		green = hexrgb("7fbf5a")
		ring_line(d, 0.92, 9, hexrgb("3e4a34"))
		ring_line(d, 0.66, 7, hexrgb("3e4a34"))
		glyph_band(d, 0.68, 0.905, 18, hexrgb("46523a"), 9, 221)
		spiral(d, 3, 0.46, 13, hexrgb("46523a"))
		ring_line(d, 0.5, 5, green)

	out["seal_jungle"] = seal("jungle", 220, [(0.5, "7c8a6e"), (0.66, "6e7c62"), (0.92, "848e78"), (1.0, "5e7056")], [(0.51, 0.65, 16, "4e5c46"), (0.93, 0.99, 30, "46523a")], jungle, ("5f8f3e", 0.55))

	def jungle_ring(d):
		dark = hexrgb("3e4a34")
		ring_line(d, 0.985, 7, dark)
		ring_line(d, 0.85, 6, dark)
		glyph_band(d, 0.855, 0.98, 30, hexrgb("46523a"), 7, 222)

	out["seal_jungle_ring"] = seal("jungle_ring", 225, [(1.0, "7c8a6e")], [(0.85, 0.99, 44, "4e5c46")], jungle_ring, ("5f8f3e", 0.5), edge=0.998, hollow=0.83)

	def volcano(d):
		ember = hexrgb("ff8a30")
		ring_line(d, 0.92, 9, hexrgb("2a2428"))
		flame_cracks(d, 231, ember)
		ring_line(d, 0.2, 10, ember)

	out["seal_volcano"] = seal("volcano", 230, [(0.2, "ffb040"), (0.92, "4a464b"), (1.0, "3a363c")], [(0.93, 0.99, 28, "2a2428")], volcano, ("5a5054", 0.4))

	def abyss(d):
		line = hexrgb("3cd8d2")
		ring_line(d, 0.94, 8, line)
		ring_line(d, 0.62, 6, line)
		glyph_band(d, 0.64, 0.92, 20, hexrgb("1a4a78"), 9, 241)
		spiral(d, 2.5, 0.54, 12, line)

	out["seal_abyss"] = seal("abyss", 240, [(0.62, "1e5a96"), (0.94, "2a7a98"), (1.0, "184a7c")], [(0.95, 0.99, 40, "123a64")], abyss, ("6ab8c0", 0.35))

	def mechanical(d):
		line = hexrgb("3cf0ff")
		ring_line(d, 0.94, 8, hexrgb("3a3e48"))
		gear(d, 0.72, 16, hexrgb("596070"), hexrgb("2c3038"))
		ring_line(d, 0.3, 6, line)
		spokes(d, 8, 0.78, 0.92, 7, line)

	out["seal_mechanical"] = seal("mechanical", 250, [(0.94, "757b85"), (1.0, "4e545e")], [(0.95, 0.99, 32, "3a3e48")], mechanical, ("8a909a", 0.25), grain=0.08)

	for key, im in out.items():
		im.save(os.path.join(OUT, key + ".png"), optimize=True)
	sheet = Image.new("RGB", (4 * 262, 2 * 262), (120, 110, 100))
	for i, (key, im) in enumerate(out.items()):
		thumb = im.resize((256, 256), Image.LANCZOS)
		sheet.paste(thumb, (i % 4 * 262, i // 4 * 262), thumb)
	sheet.save(os.path.join(OUT, "seals_sheet.png"))
	print(len(out), "seals")


if __name__ == "__main__":
	build()
