"""Animation filmstrip for the owner: docs/before_after/W_<weapon>_filmstrip.png + a GIF next to it.

Frames come from tools/grab_studio.py (docs/before_after/frames/<set>/NN_Label_words.jpg, sorted by name; the label is the
name without its number). Each set is one block of the sheet: AVANT (orange) / APRES (green) or a neutral heading.

  python tools/make_filmstrip.py W_sword "Epee - combo" --set APRES sword_after [--set AVANT sword_before] [--cols 4] [--gif sword_after]
"""
import argparse
import glob
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs", "before_after")
FRAMES = os.path.join(OUT_DIR, "frames")
VIEWPORT = (156, 231, 1446, 955)  # the Studio viewport inside the grabbed window
CROP = (0.26, 0.04, 0.74, 0.96)  # the character, in fractions of the viewport
CELL_W, PAD, TITLE_H, HEAD_H, LABEL_H = 400, 10, 76, 50, 34
BG, WHITE = (30, 34, 44), (255, 255, 255)
HEADS = {"AVANT": (236, 150, 40), "APRES": (60, 170, 90)}


def font(size):
	for name in ("segoeuib.ttf", "arialbd.ttf"):
		try:
			return ImageFont.truetype(os.path.join("C:/Windows/Fonts", name), size)
		except OSError:
			pass
	return ImageFont.load_default()


def load(path):
	image = Image.open(path).convert("RGB")
	if image.size[0] > VIEWPORT[2]:
		image = image.crop(VIEWPORT)
	w, h = image.size
	return image.crop((int(w * CROP[0]), int(h * CROP[1]), int(w * CROP[2]), int(h * CROP[3])))


def frames_of(folder):
	paths = sorted(glob.glob(os.path.join(FRAMES, folder, "*.jpg")))
	if not paths:
		raise SystemExit(f"no frames in {folder}")
	return paths


def label_of(path):
	name = os.path.splitext(os.path.basename(path))[0]
	return name.split("_", 1)[-1].replace("_", " ")


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("name")
	ap.add_argument("title")
	ap.add_argument("--set", nargs=2, action="append", metavar=("HEADING", "FOLDER"), required=True)
	ap.add_argument("--cols", type=int, default=4)
	ap.add_argument("--gif")
	ap.add_argument("--gif-ms", type=int, default=90)
	a = ap.parse_args()
	sets = [(heading, frames_of(folder)) for heading, folder in a.set]
	sample = load(sets[0][1][0])
	cell_h = int(CELL_W * sample.size[1] / sample.size[0])
	big, medium, small = font(44), font(30), font(22)
	width = a.cols * CELL_W + (a.cols + 1) * PAD
	height = TITLE_H
	for _, paths in sets:
		rows = (len(paths) + a.cols - 1) // a.cols
		height += HEAD_H + rows * (cell_h + LABEL_H + PAD)
	sheet = Image.new("RGB", (width, height), BG)
	draw = ImageDraw.Draw(sheet)
	draw.text((PAD * 2, 14), a.title, font=big, fill=WHITE)
	y = TITLE_H
	for heading, paths in sets:
		draw.rectangle((PAD, y, width - PAD, y + HEAD_H - 8), fill=HEADS.get(heading, (70, 80, 100)))
		draw.text((PAD * 2, y + 4), heading, font=medium, fill=WHITE)
		y += HEAD_H
		for i, path in enumerate(paths):
			col, row = i % a.cols, i // a.cols
			x, top = PAD + col * (CELL_W + PAD), y + row * (cell_h + LABEL_H + PAD)
			sheet.paste(load(path).resize((CELL_W, cell_h), Image.LANCZOS), (x, top))
			draw.text((x + 4, top + cell_h + 3), label_of(path), font=small, fill=WHITE)
		y += ((len(paths) + a.cols - 1) // a.cols) * (cell_h + LABEL_H + PAD)
	out = os.path.join(OUT_DIR, a.name + "_filmstrip.png")
	sheet.save(out)
	print(out, sheet.size)
	if a.gif:
		images = [load(path).resize((360, int(360 * sample.size[1] / sample.size[0])), Image.LANCZOS) for path in frames_of(a.gif)]
		gif = os.path.join(OUT_DIR, a.name + ".gif")
		images[0].save(gif, save_all=True, append_images=images[1:], duration=a.gif_ms, loop=0, optimize=True)
		print(gif, os.path.getsize(gif) // 1024, "KB")


if __name__ == "__main__":
	main()
