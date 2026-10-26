"""Before / after sheet for the owner (one per changed asset or room): docs/before_after/NN_name.png.

Title "NN - Name" on top, then a 2 x 2 grid: AVANT (orange label) on the left, APRES (green label) on the right.
Rows default to "Zone de test" and "Dans le jeu"; rooms pass their own row names (for example "Murs" and "Sol").

  python tools/make_before_after.py 01 plains_gate_boss_gate "Porte du boss (Plaines)" \
      --row "Zone de test" before_preview.jpg after_preview.jpg \
      --row "Dans le jeu" before_map.jpg after_map.jpg
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs", "before_after")
CELL_W, CELL_H, PAD, TITLE_H, LABEL_H = 800, 450, 14, 76, 52
BG, WHITE = (30, 34, 44), (255, 255, 255)
ORANGE, GREEN = (236, 150, 40), (60, 170, 90)


def font(size):
	for name in ("segoeuib.ttf", "arialbd.ttf"):
		try:
			return ImageFont.truetype(os.path.join("C:/Windows/Fonts", name), size)
		except OSError:
			pass
	return ImageFont.load_default()


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("nn")
	ap.add_argument("name")
	ap.add_argument("title")
	ap.add_argument("--row", nargs=3, action="append", metavar=("LABEL", "BEFORE", "AFTER"), required=True)
	a = ap.parse_args()
	big, small = font(46), font(30)
	rows = a.row
	W = 2 * CELL_W + 3 * PAD
	H = TITLE_H + len(rows) * (LABEL_H + CELL_H + PAD) + PAD
	sheet = Image.new("RGB", (W, H), BG)
	d = ImageDraw.Draw(sheet)
	d.text((PAD, 12), f"{a.nn} - {a.title}", fill=WHITE, font=big)
	y = TITLE_H
	for label, before, after in rows:
		for i, (path, word, colour) in enumerate(((before, "AVANT", ORANGE), (after, "APRÈS", GREEN))):
			x = PAD + i * (CELL_W + PAD)
			d.rounded_rectangle([x, y, x + CELL_W, y + LABEL_H - 8], radius=8, fill=colour)
			d.text((x + 12, y + 6), f"{word} - {label}", fill=WHITE, font=small)
			cell = Image.new("RGB", (CELL_W, CELL_H), (20, 22, 28))
			if path and os.path.exists(path):
				im = Image.open(path).convert("RGB")
				im.thumbnail((CELL_W, CELL_H))
				cell.paste(im, ((CELL_W - im.width) // 2, (CELL_H - im.height) // 2))
			else:
				ImageDraw.Draw(cell).text((20, CELL_H // 2 - 15), "(pas de capture)", fill=WHITE, font=small)
			sheet.paste(cell, (x, y + LABEL_H))
		y += LABEL_H + CELL_H + PAD
	os.makedirs(OUT_DIR, exist_ok=True)
	out = os.path.join(OUT_DIR, f"{a.nn}_{a.name}.png")
	sheet.save(out)
	print(out)


if __name__ == "__main__":
	main()
