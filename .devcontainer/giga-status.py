#!/usr/bin/env python3
"""GigaBrowse v2 — regenerate /config/www/status.json for the start page.

Reads the watcher state files (written by giga-download-watch.sh) and the
download folder, and writes a small JSON document the start page polls
every 3 seconds. No network, no credentials, no side effects.

State files:
  /config/downloads/current.txt   — "name|size|progress" while uploading
  /config/downloads/completed.log — "YYYY-MM-DD HH:MM|name|size" per finish
"""
import json
import os
import time
from pathlib import Path

WATCH = Path(os.environ.get("GIGA_DOWNLOAD_DIR", "/config/Downloads"))
STATE = Path("/config/downloads")
OUT = Path("/config/www/status.json")
PARTIAL_SUFFIXES = (".crdownload", ".tmp", ".partial", ".part", ".download")


def read_current():
    p = STATE / "current.txt"
    if not p.exists():
        return None
    try:
        name, size, progress = p.read_text().strip().split("|", 2)
        return {"name": name, "size": int(size), "progress": progress}
    except Exception:
        return None


def read_completed():
    out = []
    p = STATE / "completed.log"
    if p.exists():
        for line in p.read_text().splitlines()[-10:]:
            try:
                ts, name, size = line.split("|", 2)
                out.append({"finished": ts, "name": name, "size": int(size)})
            except Exception:
                continue
    return list(reversed(out))


def pending_count():
    if not WATCH.exists():
        return 0
    n = 0
    for f in WATCH.iterdir():
        if f.is_file() and not f.name.endswith(PARTIAL_SUFFIXES):
            n += 1
    return n


def main():
    data = {
        "updated": time.strftime("%Y-%m-%d %H:%M:%S"),
        "rclone": "ok" if Path("/config/rclone/rclone.conf").exists() else "missing",
        "uploading": read_current(),
        "pending": pending_count(),
        "completed": read_completed(),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    tmp = OUT.with_suffix(".tmp")
    tmp.write_text(json.dumps(data))
    tmp.replace(OUT)


if __name__ == "__main__":
    main()
