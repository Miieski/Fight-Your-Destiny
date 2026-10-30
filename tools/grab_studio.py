"""Grabs the Roblox Studio viewport to image files, for animation filmstrips (no screen_capture round trip).

Only the Studio window is read (PrintWindow, so it works when another window covers it; not when it is minimised).

  python tools/grab_studio.py --out shot.png                      one grab of the window
  python tools/grab_studio.py --follow DIR [--timeout 300]        follows the Studio log: every line
      FYDSHOT|<weapon>/<name>   grabs DIR/<weapon>/<name>.jpg           (the Play client holds the pose meanwhile)
      FYDSHOT|END               stops
"""
import argparse
import ctypes
import glob
import os
import re
import time
from ctypes import wintypes

from PIL import Image

LOG_DIR = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs")
MARK = b"FYDSHOT|"
SAFE_NAME = re.compile(r"^[A-Za-z0-9_\-]+/[A-Za-z0-9_\-]+$")
user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
user32.SetProcessDPIAware()
PW_RENDERFULLCONTENT = 2


def studio_window():
	found = []

	@ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
	def visit(hwnd, _):
		if user32.IsWindowVisible(hwnd):
			length = user32.GetWindowTextLengthW(hwnd)
			buffer = ctypes.create_unicode_buffer(length + 1)
			user32.GetWindowTextW(hwnd, buffer, length + 1)
			if "Roblox Studio" in buffer.value:
				found.append(hwnd)
		return True

	user32.EnumWindows(visit, 0)
	if not found:
		raise SystemExit("No Roblox Studio window")
	return found[0]


def grab(hwnd):
	rect = wintypes.RECT()
	user32.GetWindowRect(hwnd, ctypes.byref(rect))
	width, height = rect.right - rect.left, rect.bottom - rect.top
	screen = user32.GetDC(hwnd)
	memory = gdi32.CreateCompatibleDC(screen)
	bitmap = gdi32.CreateCompatibleBitmap(screen, width, height)
	gdi32.SelectObject(memory, bitmap)
	user32.PrintWindow(hwnd, memory, PW_RENDERFULLCONTENT)

	class BITMAPINFOHEADER(ctypes.Structure):
		_fields_ = [(n, t) for n, t in (("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG), ("biHeight", wintypes.LONG), ("biPlanes", wintypes.WORD), ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD), ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", wintypes.LONG), ("biYPelsPerMeter", wintypes.LONG), ("biClrUsed", wintypes.DWORD), ("biClrImportant", wintypes.DWORD))]

	info = BITMAPINFOHEADER(ctypes.sizeof(BITMAPINFOHEADER), width, -height, 1, 32, 0, 0, 0, 0, 0, 0)
	data = ctypes.create_string_buffer(width * height * 4)
	gdi32.GetDIBits(memory, bitmap, 0, height, data, ctypes.byref(info), 0)
	gdi32.DeleteObject(bitmap)
	gdi32.DeleteDC(memory)
	user32.ReleaseDC(hwnd, screen)
	return Image.frombuffer("RGB", (width, height), data, "raw", "BGRX", 0, 1)


def newest_log():
	return max(glob.glob(os.path.join(LOG_DIR, "*_Studio_*.log")), key=os.path.getmtime)


def follow(out_dir, timeout):
	hwnd = studio_window()
	path = newest_log()
	count = 0
	with open(path, "rb") as log:
		log.seek(0, os.SEEK_END)
		end = time.time() + timeout
		pending = b""
		while time.time() < end:
			chunk = log.read()
			if not chunk:
				time.sleep(0.02)
				continue
			pending += chunk
			lines = pending.split(b"\n")
			pending = lines.pop()
			for line in lines:
				at = line.find(MARK)
				if at < 0:
					continue
				name = line[at + len(MARK):].strip().decode("ascii", "replace")
				if name == "END":
					print(f"{count} frames")
					return
				if SAFE_NAME.match(name):
					dest = os.path.join(out_dir, *name.split("/")) + ".jpg"
					os.makedirs(os.path.dirname(dest), exist_ok=True)
					grab(hwnd).save(dest, quality=92)
					count += 1
	print(f"timed out after {count} frames")


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("--out")
	parser.add_argument("--follow")
	parser.add_argument("--timeout", type=float, default=300)
	args = parser.parse_args()
	if args.follow:
		follow(args.follow, args.timeout)
	else:
		grab(studio_window()).save(args.out)


if __name__ == "__main__":
	main()
