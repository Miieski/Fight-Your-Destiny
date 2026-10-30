"""Real-time clip of a weapon from a tools/grab_studio.py burst: a GIF plus a few picked frames for the filmstrip.

  python tools/make_rt_gif.py <burst folder> W_sword sword_after_fx --range 12 250 --picks 30:Hit1_trail 62:Hit2_trail ...
  --auto 8 picks the 8 busiest frames instead (and the range around the action when --range is not given).
The burst folder stays outside the repo (hundreds of big frames): only the GIF and the picks go to docs/before_after/.
"""
import argparse
import glob
import os

from PIL import Image, ImageChops, ImageStat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs", "before_after")
VIEWPORT = (156, 231, 1446, 955)
CROP = (0.30, 0.12, 0.86, 0.98)


def load(path):
	image = Image.open(path).convert("RGB").crop(VIEWPORT)
	w, h = image.size
	return image.crop((int(w * CROP[0]), int(h * CROP[1]), int(w * CROP[2]), int(h * CROP[3])))


def activity(files):
	"""[(index, change from 6 frames before)], low resolution, around the character."""
	previous, out = None, []
	for index in range(0, len(files), 3):
		image = load(files[index]).convert("L").resize((80, 70))
		if previous is not None:
			out.append((index, ImageStat.Stat(ImageChops.difference(image, previous)).mean[0]))
		previous = image
	return out


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("burst")
	ap.add_argument("name")
	ap.add_argument("picks_set")
	ap.add_argument("--range", nargs=2, type=int)
	ap.add_argument("--auto", type=int, default=0)
	ap.add_argument("--picks", nargs="*", default=[])
	ap.add_argument("--step", type=int, default=2)
	ap.add_argument("--width", type=int, default=340)
	a = ap.parse_args()
	files = sorted(glob.glob(os.path.join(a.burst, "*.jpg")))
	busy = activity(files)
	quiet = [i for i, v in busy if v > 4]
	first, last = a.range or (max(0, quiet[0] - 12), min(len(files), quiet[-1] + 24))
	if a.auto:
		a.picks = []
		taken = []
		for index, value in sorted(busy, key=lambda e: -e[1]):
			if len(taken) < a.auto and all(abs(index - t) >= 18 for t in taken):
				taken.append(index)
		a.picks = [f"{i}:t_{(i - first) / 48:.2f}s" for i in sorted(taken)]
	chosen = files[first:last:a.step]
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
