"""Round 9 part 14: the images of the portal ruins and of the Locate guide. No external image, all drawn here.

  python tools/make_ruin_textures.py          writes docs/floor_textures/ruin_*.png and locate_chevron.png

ruin_cracks: dark soft cracks on alpha, laid over the steps. ruin_rune: a worn rune circle in white on alpha, the Decal tints it with the
zone colour. locate_chevron: white chevrons on alpha, one tile of the guide's Beam, pointing along +U.
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_boss_seals import BIG, OUT, fbm, glyph_band, ring_line, spokes


def cracks():
	w, h = 1024, 340
	mask = Image.new("L", (w, h), 0)
	draw = ImageDraw.Draw(mask)
	rng = random.Random(1402)

	def branch(x, y, angle, length, width):
		points = [(x, y)]
		for _ in range(length):
			angle += rng.uniform(-0.55, 0.55)
			step = rng.uniform(16, 34)
			x, y = x + math.cos(angle) * step, y + math.sin(angle) * step
			points.append((x, y))
			if width > 2 and rng.random() < 0.28:
				branch(x, y, angle + rng.choice((-1, 1)) * rng.uniform(0.6, 1.1), length // 2, width - 2)
		draw.line(points, fill=255, width=width, joint="curve")

	for x, y, angle in ((120, 0, 1.2), (330, 340, -1.3), (690, 0, 1.9), (930, 340, -2.0), (0, 170, 0.1), (1024, 150, 3.1)):
		branch(x, y, angle, 10, 7)
	soft = mask.filter(ImageFilter.GaussianBlur(1.2))
	out = Image.new("RGBA", (w, h), (34, 32, 38, 0))
	out.putalpha(soft.point(lambda v: min(255, int(v * 0.9))))
	return out


def rune():
	line = Image.new("RGBA", (BIG, BIG), (255, 255, 255, 0))
	draw = ImageDraw.Draw(line)
	white = (255, 255, 255)
	ring_line(draw, 0.96, 12, white)
	ring_line(draw, 0.84, 6, white)
	ring_line(draw, 0.60, 8, white)
	ring_line(draw, 0.24, 8, white)
	glyph_band(draw, 0.62, 0.82, 14, white, 8, 77)
	spokes(draw, 8, 0.24, 0.60, 6, white, 0.2)
	alpha = line.getchannel("A").resize((512, 512), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.7))
	# worn: large soft gaps eat the lines
	worn = fbm(1404).point(lambda v: 255 if v > 112 else int(max(0, (v - 92) * 12)))
	alpha = ImageChops.multiply(alpha, worn)
	out = Image.new("RGBA", (512, 512), (255, 255, 255, 0))
	out.putalpha(alpha)
	return out


def chevron():
	s = 256
	big = s * 2
	mask = Image.new("L", (big, big), 0)
	draw = ImageDraw.Draw(mask)
	thick, head = big * 0.2, big * 0.3
	x0 = big * 0.18
	draw.polygon(((x0, big * 0.12), (x0 + thick, big * 0.12), (x0 + thick + head, big / 2), (x0 + thick, big * 0.88), (x0, big * 0.88), (x0 + head, big / 2)), fill=255)
	alpha = mask.resize((s, s), Image.LANCZOS)
	out = Image.new("RGBA", (s, s), (255, 255, 255, 0))
	out.putalpha(alpha)
	return out


if __name__ == "__main__":
	cracks().save(os.path.join(OUT, "ruin_cracks.png"))
	rune().save(os.path.join(OUT, "ruin_rune.png"))
	chevron().save(os.path.join(OUT, "locate_chevron.png"))
	print("written: ruin_cracks.png, ruin_rune.png, locate_chevron.png")
