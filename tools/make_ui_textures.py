"""Round 8 part 8: the wood + metal UI images. All drawn here (no copied artwork, no pirate theme), small, 9-slice friendly.

  python tools/make_ui_textures.py        writes docs/ui_textures/*.png and docs/ui_textures/sheet.png (preview)

Slice centres are in Config/UITheme.Images (the same numbers as SLICE below).
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "ui_textures")
SS = 4  # drawn 4 times larger, then reduced: clean edges

GOLD_LIGHT, GOLD, GOLD_DARK = (255, 224, 138), (226, 170, 66), (138, 88, 26)
STEEL_LIGHT, STEEL, STEEL_DARK = (226, 232, 240), (168, 176, 188), (92, 98, 110)
INK = (30, 18, 10)


def canvas(w, h):
	return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def finish(im):
	return im.resize((im.width // SS, im.height // SS), Image.LANCZOS)


def lerp(a, b, t):
	return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def vgrad(w, h, top, bottom):
	im = Image.new("RGB", (1, h))
	im.putdata([lerp(top, bottom, y / max(1, h - 1)) for y in range(h)])
	return im.resize((w, h))


def rounded_mask(w, h, box, r):
	mask = Image.new("L", (w, h), 0)
	ImageDraw.Draw(mask).rounded_rectangle(box, r, fill=255)
	return mask


def grain(w, h, seed, dark, light, lines=120, wrap=False):
	"""Long horizontal wood fibres."""
	rng = random.Random(seed)
	im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	for _ in range(lines):
		y = rng.uniform(0, h)
		x = rng.uniform(-w, w)
		long = rng.uniform(w * 0.3, w * 1.1)
		wob = rng.uniform(1, 3) * h / 256
		color = (dark if rng.random() < 0.65 else light) + (rng.randrange(30, 90),)
		pts = [(x + long * t / 12, y + math.sin(t * 0.8 + x) * wob) for t in range(13)]
		for ox in ([-w, 0, w] if wrap else [0]):
			d.line([(p[0] + ox, p[1]) for p in pts], fill=color, width=max(1, int(rng.uniform(1, 2.4) * h / 256)))
	return im


def planks(seed, rows, top, bottom, gap, rivets=True):
	"""256 px tile: planks with grain, gaps, a nail pair at the plank ends."""
	s = 256 * 2
	rng = random.Random(seed)
	out = Image.new("RGB", (s, s), gap)
	h = s / rows
	tones = [rng.uniform(0.88, 1.08) for _ in range(rows)]
	for r in range(rows):
		y0, y1 = int(r * h), int((r + 1) * h)
		board = vgrad(s, y1 - y0, tuple(int(c * tones[r]) for c in top), tuple(int(c * tones[r]) for c in bottom)).convert("RGBA")
		board.alpha_composite(grain(s, y1 - y0, seed + r * 7, (30, 16, 8), (150, 104, 66), 60, wrap=True))
		d = ImageDraw.Draw(board)
		d.line((0, 0, s, 0), fill=(255, 220, 170, 56), width=2)
		d.line((0, y1 - y0 - 3, s, y1 - y0 - 3), fill=(0, 0, 0, 90), width=4)
		out.paste(board.convert("RGB"), (0, y0 + 2))
	d = ImageDraw.Draw(out)
	for r in range(rows):
		y = (r + 0.5) * h
		x = (rng.uniform(0.1, 0.9) * s + r * s * 0.37) % s
		d.line((x, r * h + 2, x, (r + 1) * h), fill=gap, width=4)
		if rivets:
			for ox in (-14, 14):
				for oy in (-h * 0.22, h * 0.22):
					px, py = x + ox, y + oy
					d.ellipse((px - 4.5, py - 4.5, px + 4.5, py + 4.5), fill=(70, 74, 84))
					d.ellipse((px - 3.5, py - 4, px + 2, py + 1), fill=(190, 196, 206))
	return out.resize((256, 256), Image.LANCZOS)


def frame():
	"""Thick rounded wooden frame, thin gold inner line, hollow middle. 128 px, slice 44."""
	w = h = 128 * SS
	s = SS
	wood = vgrad(w, h, (160, 104, 62), (92, 54, 30)).convert("RGBA")
	wood.alpha_composite(grain(w, h, 5, (44, 22, 10), (214, 160, 108), 180))
	mask = rounded_mask(w, h, (0, 0, w - 1, h - 1), 26 * s)
	inner = rounded_mask(w, h, (22 * s, 22 * s, w - 22 * s, h - 22 * s), 10 * s)
	mask = ImageChops.subtract(mask, inner)
	wood.putalpha(mask)
	d = ImageDraw.Draw(wood)
	d.rounded_rectangle((2 * s, 2 * s, w - 2 * s, h - 2 * s), 25 * s, outline=(255, 214, 160, 150), width=2 * s)
	d.rounded_rectangle((0, 0, w - 1, h - 1), 26 * s, outline=(34, 18, 8, 255), width=2 * s)
	d.rounded_rectangle((20 * s, 20 * s, w - 20 * s, h - 20 * s), 11 * s, outline=GOLD + (255,), width=2 * s)
	d.rounded_rectangle((22 * s, 22 * s, w - 22 * s, h - 22 * s), 10 * s, outline=(30, 16, 8, 255), width=1 * s)
	return finish(wood)


def bracket():
	"""A steel corner (top-left): a curved L with rivets. 96 px."""
	im = canvas(96, 96)
	s = SS
	d = ImageDraw.Draw(im)
	shape = [(6, 40), (6, 22), (22, 6), (40, 6), (70, 6), (78, 14), (78, 26), (34, 30), (30, 34), (26, 78), (14, 78), (6, 70)]
	d.polygon([(x * s, y * s) for x, y in shape], fill=STEEL_DARK + (255,))
	inner = [(9, 40), (9, 24), (24, 9), (40, 9), (69, 9), (75, 15), (75, 23), (34, 27), (27, 34), (23, 75), (15, 75), (9, 69)]
	d.polygon([(x * s, y * s) for x, y in inner], fill=STEEL + (255,))
	high = [(10, 34), (10, 25), (25, 10), (64, 10), (60, 13), (28, 14), (14, 28), (13, 60), (10, 64)]
	d.polygon([(x * s, y * s) for x, y in high], fill=STEEL_LIGHT + (255,))
	for x, y in ((18, 18), (56, 15), (15, 56)):
		d.ellipse(((x - 4) * s, (y - 4) * s, (x + 4) * s, (y + 4) * s), fill=(66, 70, 82, 255))
		d.ellipse(((x - 3) * s, (y - 3.4) * s, (x + 2) * s, (y + 1.5) * s), fill=(236, 240, 246, 255))
	return finish(im)


def banner():
	"""Gold ornate title plate: brown inside, stepped ends. 256 x 96, slice 70 x 30."""
	w, h = 256, 96
	s = SS
	def plate(m):
		a = m
		return [
			(a + 26, a), (w / 2, a), (w - a - 26, a), (w - a - 26, a + 8), (w - a - 14, a + 8), (w - a - 14, a + 18), (w - a, a + 18), (w - a, h - a - 18), (w - a - 14, h - a - 18),
			(w - a - 14, h - a - 8), (w - a - 26, h - a - 8), (w - a - 26, h - a), (a + 26, h - a), (a + 26, h - a - 8), (a + 14, h - a - 8), (a + 14, h - a - 18), (a, h - a - 18),
			(a, a + 18), (a + 14, a + 18), (a + 14, a + 8), (a + 26, a + 8),
		]
	im = canvas(w, h)
	d = ImageDraw.Draw(im)
	d.polygon([(x * s, y * s) for x, y in plate(2)], fill=(70, 40, 12, 255))
	grad = vgrad(w * s, h * s, GOLD_LIGHT, GOLD_DARK).convert("RGBA")
	mask = Image.new("L", im.size, 0)
	ImageDraw.Draw(mask).polygon([(x * s, y * s) for x, y in plate(4)], fill=255)
	im.paste(grad, (0, 0), mask)
	inner = vgrad(w * s, h * s, (122, 74, 36), (66, 36, 16)).convert("RGBA")
	inner.alpha_composite(grain(w * s, h * s, 9, (40, 20, 8), (170, 116, 70), 80))
	mask = Image.new("L", im.size, 0)
	ImageDraw.Draw(mask).polygon([(x * s, y * s) for x, y in plate(10)], fill=255)
	im.paste(inner, (0, 0), mask)
	d = ImageDraw.Draw(im)
	d.line([(x * s, y * s) for x, y in plate(10)] + [(plate(10)[0][0] * s, plate(10)[0][1] * s)], fill=(44, 24, 8, 255), width=s)
	return finish(im)


def slot():
	"""Reddish-brown slot with thin gold corner brackets. 128 px, slice 40."""
	w = h = 128 * SS
	s = SS
	base = vgrad(w, h, (124, 54, 34), (62, 26, 18)).convert("RGBA")
	base.putalpha(rounded_mask(w, h, (2 * s, 2 * s, w - 2 * s, h - 2 * s), 6 * s))
	d = ImageDraw.Draw(base)
	d.rounded_rectangle((2 * s, 2 * s, w - 2 * s, h - 2 * s), 6 * s, outline=(30, 12, 8, 255), width=2 * s)
	d.rectangle((6 * s, 6 * s, w - 6 * s, h - 6 * s), outline=GOLD_DARK + (255,), width=s)
	long = 30 * s
	for x, y, sx, sy in ((6, 6, 1, 1), (122, 6, -1, 1), (6, 122, 1, -1), (122, 122, -1, -1)):
		px, py = x * s, y * s
		d.line((px, py, px + sx * long, py), fill=GOLD_LIGHT + (255,), width=3 * s)
		d.line((px, py, px, py + sy * long), fill=GOLD_LIGHT + (255,), width=3 * s)
		d.rectangle((min(px, px + sx * 9 * s), min(py, py + sy * 9 * s), max(px, px + sx * 9 * s), max(py, py + sy * 9 * s)), outline=GOLD + (255,), width=2 * s)
	return finish(base)


def tile():
	"""Round-square wooden menu button with gold corner rims. 128 px, slice 44."""
	w = h = 128 * SS
	s = SS
	body = vgrad(w, h, (124, 66, 40), (66, 32, 20)).convert("RGBA")
	body.alpha_composite(grain(w, h, 13, (36, 16, 8), (178, 122, 80), 110))
	body.putalpha(rounded_mask(w, h, (2 * s, 2 * s, w - 2 * s, h - 2 * s), 20 * s))
	d = ImageDraw.Draw(body)
	d.rounded_rectangle((2 * s, 2 * s, w - 2 * s, h - 2 * s), 20 * s, outline=(30, 14, 8, 255), width=2 * s)
	d.rounded_rectangle((8 * s, 8 * s, w - 8 * s, h - 8 * s), 14 * s, outline=(214, 150, 96, 120), width=s)
	rim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	r = ImageDraw.Draw(rim)
	for x0, y0, start in ((3, 3, 180), (w / s - 3 - 56, 3, 270), (w / s - 3 - 56, h / s - 3 - 56, 0), (3, h / s - 3 - 56, 90)):
		r.arc((x0 * s, y0 * s, (x0 + 56) * s, (y0 + 56) * s), start, start + 90, fill=GOLD + (255,), width=7 * s)
		r.arc((x0 * s, y0 * s, (x0 + 56) * s, (y0 + 56) * s), start + 12, start + 78, fill=GOLD_LIGHT + (255,), width=3 * s)
	body.alpha_composite(rim)
	return finish(body)


def pill():
	"""Wooden counter pill with a gold border. 128 x 48, slice 24."""
	w, h = 128 * SS, 48 * SS
	s = SS
	body = vgrad(w, h, (86, 50, 28), (44, 24, 14)).convert("RGBA")
	body.alpha_composite(grain(w, h, 17, (30, 14, 6), (150, 100, 64), 40))
	body.putalpha(rounded_mask(w, h, (1 * s, 1 * s, w - s, h - s), 23 * s))
	d = ImageDraw.Draw(body)
	d.rounded_rectangle((1 * s, 1 * s, w - s, h - s), 23 * s, outline=(30, 14, 8, 255), width=s)
	d.rounded_rectangle((3 * s, 3 * s, w - 3 * s, h - 3 * s), 21 * s, outline=GOLD + (255,), width=2 * s)
	return finish(body)


def bar_frame():
	"""Gold-edged bar frame, the right end cut at an angle; the middle is hollow (the fill shows). 256 x 48, slice 30 x 20."""
	w, h = 256, 48
	s = SS
	outer = [(2, 2), (w - 2, 2), (w - 16, h - 2), (2, h - 2)]
	gold = [(4, 4), (w - 6, 4), (w - 19, h - 4), (4, h - 4)]
	hole = [(8, 8), (w - 26, 8), (w - 26, h - 8), (8, h - 8)]
	im = canvas(w, h)
	d = ImageDraw.Draw(im)
	d.polygon([(x * s, y * s) for x, y in outer], fill=(30, 14, 8, 255))
	mask = Image.new("L", im.size, 0)
	ImageDraw.Draw(mask).polygon([(x * s, y * s) for x, y in gold], fill=255)
	im.paste(vgrad(w * s, h * s, GOLD_LIGHT, GOLD_DARK).convert("RGBA"), (0, 0), mask)
	inner = [(7, 7), (w - 11, 7), (w - 21, h - 7), (7, h - 7)]
	ImageDraw.Draw(im).polygon([(x * s, y * s) for x, y in inner], fill=(40, 20, 12, 255))
	cut = Image.new("L", im.size, 255)
	ImageDraw.Draw(cut).polygon([(x * s, y * s) for x, y in hole], fill=0)
	alpha = ImageChops.multiply(im.getchannel("A"), cut)
	im.putalpha(alpha)
	return finish(im)


def portrait():
	"""A steel-rimmed shield with gold wings; a round hole shows the avatar. 256 x 256 (hole at 128, 104, radius 72)."""
	w = 256
	s = SS
	im = canvas(w, w)
	d = ImageDraw.Draw(im)
	# wings, left and right of the shield
	for side in (-1, 1):
		for i in range(4):
			base = 128 + side * 74
			tip = 128 + side * (120 - i * 8)
			y0 = 34 + i * 26
			feather = [(base, y0 + 30), (tip, y0 - 6), (tip + side * -6, y0 + 16), (base, y0 + 56)]
			d.polygon([(x * s, y * s) for x, y in feather], fill=GOLD_DARK + (255,))
			f2 = [(base, y0 + 30), (tip - side * 3, y0), (tip - side * 8, y0 + 13), (base, y0 + 46)]
			d.polygon([(x * s, y * s) for x, y in f2], fill=(lerp(GOLD, GOLD_LIGHT, i / 3)) + (255,))
	shield = lambda m: [(38 + m, 16 + m), (218 - m, 16 + m), (218 - m, 140 - m * 0.2), (128, 246 - m * 1.5), (38 + m, 140 - m * 0.2)]
	d.polygon([(x * s, y * s) for x, y in shield(0)], fill=(30, 18, 12, 255))
	mask = Image.new("L", im.size, 0)
	ImageDraw.Draw(mask).polygon([(x * s, y * s) for x, y in shield(3)], fill=255)
	im.paste(vgrad(w * s, w * s, STEEL_LIGHT, STEEL_DARK).convert("RGBA"), (0, 0), mask)
	woodface = vgrad(w * s, w * s, (112, 66, 38), (60, 32, 18)).convert("RGBA")
	woodface.alpha_composite(grain(w * s, w * s, 21, (34, 16, 8), (168, 116, 74), 120))
	mask = Image.new("L", im.size, 0)
	ImageDraw.Draw(mask).polygon([(x * s, y * s) for x, y in shield(13)], fill=255)
	im.paste(woodface, (0, 0), mask)
	d = ImageDraw.Draw(im)
	d.ellipse((50 * s, 26 * s, 206 * s, 182 * s), fill=GOLD_DARK + (255,))
	d.ellipse((53 * s, 29 * s, 203 * s, 179 * s), fill=GOLD + (255,))
	alpha = im.getchannel("A")
	ImageDraw.Draw(alpha).ellipse((58 * s, 34 * s, 198 * s, 174 * s), fill=0)
	im.putalpha(alpha)
	return finish(im)


def gem():
	"""A small green gem for the key labels. 64 px."""
	im = canvas(64, 64)
	s = SS
	d = ImageDraw.Draw(im)
	outer = [(32, 2), (60, 18), (60, 44), (32, 62), (4, 44), (4, 18)]
	d.polygon([(x * s, y * s) for x, y in outer], fill=(16, 56, 28, 255))
	mid = [(32, 7), (56, 21), (56, 42), (32, 57), (8, 42), (8, 21)]
	mask = Image.new("L", im.size, 0)
	ImageDraw.Draw(mask).polygon([(x * s, y * s) for x, y in mid], fill=255)
	im.paste(vgrad(64 * s, 64 * s, (112, 204, 104), (32, 110, 56)).convert("RGBA"), (0, 0), mask)
	d = ImageDraw.Draw(im)
	d.polygon([(x * s, y * s) for x, y in [(32, 8), (55, 21), (32, 21), (9, 21)]], fill=(170, 236, 150, 170))
	return finish(im)


def build():
	os.makedirs(OUT, exist_ok=True)
	out = {
		"wood_panel": planks(3, 5, (124, 78, 46), (86, 50, 28), (28, 14, 8)),
		"wood_inset": planks(4, 6, (74, 44, 26), (48, 28, 16), (20, 10, 6), rivets=False),
		"frame": frame(),
		"bracket": bracket(),
		"banner": banner(),
		"slot": slot(),
		"tile": tile(),
		"pill": pill(),
		"bar_frame": bar_frame(),
		"portrait": portrait(),
		"gem": gem(),
	}
	for name, im in out.items():
		im.save(os.path.join(OUT, name + ".png"), optimize=True)
	cols = 4
	sheet = Image.new("RGB", (cols * 266, 3 * 266), (60, 90, 110))
	for i, (name, im) in enumerate(out.items()):
		rgba = im.convert("RGBA")
		sheet.paste(rgba, (i % cols * 266 + 5, i // cols * 266 + 5), rgba)
	sheet.save(os.path.join(OUT, "sheet.png"))
	print(len(out), "images in", OUT)


if __name__ == "__main__":
	build()
