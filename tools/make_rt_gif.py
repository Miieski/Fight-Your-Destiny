"""Real-time clip of a weapon from a tools/grab_studio.py burst: a GIF plus a few picked frames for the filmstrip.

  python tools/make_rt_gif.py <burst folder> W_sword sword_after_fx --range 12 250 --picks 30:Hit1_trail 62:Hit2_trail ...
The burst folder stays outside the repo (hundreds of big frames): only the GIF and the picks go to docs/before_after/.
"""
import argparse
import glob
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs", "before_after")
VIEWPORT = (156, 231, 1446, 955)
CROP = (0.30, 0.12, 0.86, 0.98)


def load(path):
	image = Image.open(path).convert("RGB").crop(VIEWPORT)
	w, h = image.size
	return image.crop((int(w * CROP[0]), int(h * CROP[1]), int(w * CROP[2]), int(h * CROP[3])))


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("burst")
	ap.add_argument("name")
	ap.add_argument("picks_set")
	ap.add_argument("--range", nargs=2, type=int, default=(0, 240))
	ap.add_argument("--picks", nargs="*", default=[])
	ap.add_argument("--step", type=int, default=2)
	ap.add_argument("--width", type=int, default=340)
	a = ap.parse_args()
	files = sorted(glob.glob(os.path.join(a.burst, "*.jpg")))
	chosen = files[a.range[0]:a.range[1]:a.step]
	frames = []
	for path in chosen:
		image = load(path)
		frames.append(image.resize((a.width, a.width * image.size[1] // image.size[0]), Image.LANCZOS))
	gif = os.path.join(OUT_DIR, a.name + ".gif")
	frames[0].save(gif, save_all=True, append_images=frames[1:], duration=1000 * a.step // 48, loop=0, optimize=True)
	print(gif, len(frames), "frames", os.path.getsize(gif) // 1024, "KB")
	folder = os.path.join(OUT_DIR, "frames", a.picks_set)
	os.makedirs(folder, exist_ok=True)
	for order, pick in enumerate(a.picks, 1):
		index, label = pick.split(":")
		load(files[int(index)]).save(os.path.join(folder, f"{order:02d}_{label}.jpg"), quality=90)
	print(len(a.picks), "picks")


if __name__ == "__main__":
	main()
