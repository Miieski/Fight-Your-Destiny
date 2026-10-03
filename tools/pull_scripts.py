"""Write the scripts exported by ServerStorage.DevTools.ExportScripts to disk.

Scripts are edited in Studio through the MCP, so Studio is ahead of the repo. The exporter prints
every script of the mapped roots (base64 chunks) to the Output window; Studio mirrors Output into
%LOCALAPPDATA%/Roblox/logs/*_Studio_*.log and this script rebuilds the files under tools/ and src/.

Usage:  python tools/pull_scripts.py [--wait SECONDS]
Only the most recent complete export session is used. Exit code 1 if none is complete.
"""

import base64
import glob
import os
import sys
import time

MARK = b"FYDSRC|"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG_DIR = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs")
ALLOWED_PREFIXES = ("tools/", "src/")


def read_sessions():
	"""Returns {session: {"done": int | None, "files": {path: {"n", "b64len", "chunks"}}}}."""
	sessions = {}
	now = time.time()
	for log in glob.glob(os.path.join(LOG_DIR, "*_Studio_*.log")):
		if now - os.path.getmtime(log) > 2 * 24 * 3600:
			continue
		with open(log, "rb") as f:
			for line in f:
				at = line.find(MARK)
				if at < 0:
					continue
				fields = line[at + len(MARK):].strip().split(b"|")
				if len(fields) < 3:
					continue
				session = sessions.setdefault(fields[0].decode(), {"done": None, "files": {}})
				path, kind = fields[1].decode("utf-8", "replace"), fields[2]
				if kind == b"DONE" and len(fields) >= 4:
					session["done"] = int(fields[3])
					continue
				entry = session["files"].setdefault(path, {"n": None, "b64len": 0, "chunks": {}})
				if kind == b"HEAD" and len(fields) >= 5:
					entry["n"], entry["b64len"] = int(fields[3]), int(fields[4])
				elif kind.isdigit():
					entry["chunks"][int(kind)] = fields[3] if len(fields) >= 4 else b""
	return sessions


def latest_complete(sessions):
	for name in sorted(sessions, reverse=True):
		session = sessions[name]
		if session["done"] is None or len(session["files"]) != session["done"]:
			continue
		ok = all(
			e["n"] is not None
			and all(i in e["chunks"] for i in range(1, e["n"] + 1))
			and sum(len(e["chunks"][i]) for i in range(1, e["n"] + 1)) == e["b64len"]
			for e in session["files"].values()
		)
		if ok:
			return name, session
	return None, None


def main():
	wait = float(sys.argv[sys.argv.index("--wait") + 1]) if "--wait" in sys.argv else 0.0
	deadline = time.time() + wait
	while True:
		name, session = latest_complete(read_sessions())
		if session or time.time() >= deadline:
			break
		time.sleep(1.0)
	if not session:
		print("FAILED  no complete export session found in the Studio logs")
		return 1
	changed = 0
	for path, entry in sorted(session["files"].items()):
		if not path.startswith(ALLOWED_PREFIXES) or ".." in path:
			print("SKIPPED %s (outside tools/ and src/)" % path)
			continue
		data = base64.b64decode(b"".join(entry["chunks"][i] for i in range(1, entry["n"] + 1)))
		data = data.replace(b"\r\n", b"\n")
		dest = os.path.join(ROOT, *path.split("/"))
		previous = None
		if os.path.exists(dest):
			with open(dest, "rb") as f:
				previous = f.read().replace(b"\r\n", b"\n")
		if previous != data:
			os.makedirs(os.path.dirname(dest), exist_ok=True)
			with open(dest, "wb") as f:
				f.write(data)
			changed += 1
			print("%s %s" % ("UPDATED" if previous is not None else "NEW    ", path))
	print("Session %s: %d scripts, %d written." % (name, len(session["files"]), changed))
	return 0


if __name__ == "__main__":
	sys.exit(main())
