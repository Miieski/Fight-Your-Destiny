"""Collect Studio backups printed by tools/backup_studio.luau into BackUP_Files/.

Studio cannot write files and HTTP is disabled in the experience, so the backup
module prints each serialized service as base64 chunks to the Output window.
Studio mirrors Output into %LOCALAPPDATA%/Roblox/logs/*_Studio_*.log; this script
reads those lines back, verifies them and writes one .rbxm per service.

Usage:  python tools/collect_backup.py [--wait SECONDS]
Exit code 0 = every backup found in the logs is on disk, 1 = something is missing.
Existing files are never overwritten.
"""

import base64
import glob
import os
import sys
import time

MARK = b"FYDBAK|"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "BackUP_Files")
LOG_DIR = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs")
MAX_LOG_AGE = 2 * 24 * 3600


def read_backups():
	"""Returns {id: {"n": int, "b64len": int, "rawlen": int, "chunks": {i: bytes}, "tail": bool}}."""
	found = {}
	now = time.time()
	for path in glob.glob(os.path.join(LOG_DIR, "*_Studio_*.log")):
		if now - os.path.getmtime(path) > MAX_LOG_AGE:
			continue
		with open(path, "rb") as f:
			for line in f:
				at = line.find(MARK)
				if at < 0:
					continue
				fields = line[at + len(MARK):].strip().split(b"|")
				if len(fields) < 2:
					continue
				entry = found.setdefault(fields[0].decode("ascii", "replace"), {"n": None, "chunks": {}, "tail": False})
				kind = fields[1]
				if kind == b"HEAD" and len(fields) >= 5:
					entry["n"], entry["b64len"], entry["rawlen"] = int(fields[2]), int(fields[3]), int(fields[4])
				elif kind == b"TAIL":
					entry["tail"] = True
				elif kind.isdigit() and len(fields) >= 3:
					entry["chunks"][int(kind)] = fields[2]
	return found


def collect():
	"""Returns (written, already, failed) lists of (id, detail)."""
	written, already, failed = [], [], []
	for backup_id, entry in sorted(read_backups().items()):
		dest = os.path.join(OUT_DIR, backup_id + ".rbxm")
		if os.path.exists(dest):
			already.append((backup_id, os.path.getsize(dest)))
			continue
		n = entry["n"]
		if n is None or not entry["tail"]:
			failed.append((backup_id, "incomplete (no header or no end marker)"))
			continue
		missing = [i for i in range(1, n + 1) if i not in entry["chunks"]]
		if missing:
			failed.append((backup_id, "missing %d of %d chunks" % (len(missing), n)))
			continue
		b64 = b"".join(entry["chunks"][i] for i in range(1, n + 1))
		if len(b64) != entry["b64len"]:
			failed.append((backup_id, "base64 length %d, expected %d" % (len(b64), entry["b64len"])))
			continue
		raw = base64.b64decode(b64)
		if len(raw) != entry["rawlen"] or not raw.startswith(b"<roblox!"):
			failed.append((backup_id, "decoded data failed verification"))
			continue
		with open(dest, "xb") as f:
			f.write(raw)
		written.append((backup_id, len(raw)))
	return written, already, failed


def main():
	wait = 0.0
	if "--wait" in sys.argv:
		wait = float(sys.argv[sys.argv.index("--wait") + 1])
	os.makedirs(OUT_DIR, exist_ok=True)
	deadline = time.time() + wait
	written_all = []
	while True:
		written, already, failed = collect()
		written_all += written
		if not failed or time.time() >= deadline:
			break
		time.sleep(1.0)
	for backup_id, size in written_all:
		print("WROTE   %s.rbxm (%d bytes)" % (backup_id, size))
	print("On disk: %d backup files (%d new)." % (len(already) + len(written), len(written_all)))
	for backup_id, why in failed:
		print("FAILED  %s: %s" % (backup_id, why))
	return 1 if failed else 0


if __name__ == "__main__":
	sys.exit(main())
