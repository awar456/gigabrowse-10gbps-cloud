#!/usr/bin/env bash
# GigaBrowse v2 — download watcher.
#
# Every file downloaded in the cloud Chrome lands in /config/Downloads.
# This watcher moves finished downloads to Google Drive automatically:
#   gdrive:GigaBrowse_Downloads/   (same folder the old setup used)
#
# How it decides a download is finished:
#   - Chrome writes to <name>.crdownload while downloading, then renames
#     to the final name when done. We ignore *.crdownload / *.tmp /
#     *.partial / *.part, and we require the file size to be stable for
#     5 seconds before touching it (protects against slow/flaky downloads).
#   - A per-file lock dir prevents double uploads (inotify event + sweep).
#   - A sweep every 5 minutes catches anything the event stream missed
#     (e.g. files that arrived while the container was restarting).
#
# Progress: while rclone runs, its --stats-one-line output is parsed and
# written to /config/downloads/current.txt; giga-status.py turns that into
# /config/www/status.json, which the start page polls every 3 seconds.
#
# Failure policy: a failed upload is left in place and retried on the next
# sweep. Nothing is ever deleted except by a successful `rclone move`.
#
# Config (env, all optional):
#   GIGA_DOWNLOAD_DIR  default /config/Downloads
#   GIGA_DRIVE_DEST    default gdrive:GigaBrowse_Downloads
#   GIGA_CHUNK_SIZE    default 64M (Drive multipart chunk size)
#   RCLONE_CONFIG      default /config/rclone/rclone.conf
set -u

WATCH_DIR="${GIGA_DOWNLOAD_DIR:-/config/Downloads}"
DEST="${GIGA_DRIVE_DEST:-gdrive:GigaBrowse_Downloads}"
RCLONE_CONF="${RCLONE_CONFIG:-/config/rclone/rclone.conf}"
STATE_DIR="/config/downloads"
CURRENT_FILE="$STATE_DIR/current.txt"
COMPLETED_LOG="$STATE_DIR/completed.log"
LOG_FILE="$STATE_DIR/watcher.log"
CHUNK="${GIGA_CHUNK_SIZE:-64M}"

mkdir -p "$WATCH_DIR" "$STATE_DIR" /config/www

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

human() { numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "$1 bytes"; }

set_current() { # name | size | progress
  printf '%s|%s|%s\n' "$1" "$2" "$3" > "$CURRENT_FILE"
  /usr/local/bin/giga-status.py || true
}
clear_current() {
  rm -f "$CURRENT_FILE"
  /usr/local/bin/giga-status.py || true
}
mark_completed() { # name | size
  echo "$(date '+%Y-%m-%d %H:%M')|$1|$2" >> "$COMPLETED_LOG"
  /usr/local/bin/giga-status.py || true
}

is_partial_name() {
  case "$1" in
    *.crdownload|*.tmp|*.partial|*.part|*.download) return 0 ;;
    *) return 1 ;;
  esac
}

# is_complete <file> — true when the file exists, is not a partial name,
# and its size is unchanged across 5 seconds.
is_complete() {
  local f="$1" s1 s2
  [ -f "$f" ] || return 1
  is_partial_name "$f" && return 1
  s1=$(stat -c%s "$f" 2>/dev/null || echo -1)
  sleep 5
  s2=$(stat -c%s "$f" 2>/dev/null || echo -2)
  [ "$s1" = "$s2" ] && [ "$s1" -ge 0 ]
}

upload_one() {
  local file="$1" name size lockdir rclone_log pid rc pct
  name=$(basename "$file")
  size=$(stat -c%s "$file" 2>/dev/null || echo 0)

  # Per-file lock: skip if another pass is already uploading this file.
  lockdir="$STATE_DIR/.lock-$(printf '%s' "$file" | md5sum | cut -d' ' -f1)"
  mkdir "$lockdir" 2>/dev/null || { log "Skipping (already uploading): $name"; return 0; }
  trap 'rmdir "$lockdir" 2>/dev/null || true' RETURN

  rclone_log="$STATE_DIR/rclone-$(date +%s).log"
  set_current "$name" "$size" "starting upload…"
  log "Uploading: $name ($(human "$size")) -> $DEST"

  rclone --config "$RCLONE_CONF" move "$file" "$DEST" \
    --drive-chunk-size "$CHUNK" \
    --transfers 1 --checkers 4 \
    --stats 2s --stats-one-line --log-file "$rclone_log" --log-level INFO &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    pct=$(grep -h "Transferred:" "$rclone_log" 2>/dev/null | tail -n 1)
    if [ -n "$pct" ]; then
      # Example line: "Transferred: 1.234 GiB / 5 GiB, 24%, 100 MiB/s, ETA 40s"
      set_current "$name" "$size" "$pct"
    fi
    sleep 2
  done
  wait "$pid"; rc=$?

  if [ "$rc" -eq 0 ] && [ ! -e "$file" ]; then
    log "Done: $name -> $DEST"
    mark_completed "$name" "$size"
  else
    log "FAILED (rc=$rc): $name — left in $WATCH_DIR for the next sweep. See $rclone_log"
  fi
  clear_current
  rm -f "$rclone_log"
  return 0
}

# Sweep: upload every complete file currently in the watch dir.
sweep() {
  local f
  for f in "$WATCH_DIR"/*; do
    [ -e "$f" ] || continue
    [ -f "$f" ] || continue
    is_partial_name "$f" && continue
    if is_complete "$f"; then
      upload_one "$f"
    fi
  done
}

# ---- main loop ----
log "GigaBrowse download watcher started: $WATCH_DIR -> $DEST"

# Wait for the rclone config (secret) to appear. Downloads queue locally
# meanwhile; nothing is lost.
while [ ! -f "$RCLONE_CONF" ]; do
  log "Waiting for rclone config ($RCLONE_CONF) — add the RCLONE_CONF_B64 secret and rebuild. Downloads will queue locally."
  /usr/local/bin/giga-status.py || true
  sleep 60
done

log "rclone config found. Watching $WATCH_DIR ..."
sweep  # catch anything that arrived before we started

if command -v inotifywait >/dev/null 2>&1; then
  # Event-driven: Chrome's completion rename fires MOVED_TO; a final write
  # fires CLOSE_WRITE. Both paths go through is_complete() first.
  # A background sweep runs every 5 minutes as a safety net.
  (
    while true; do sleep 300; sweep; done
  ) &
  inotifywait -m -q -e close_write -e moved_to --format '%w%f' "$WATCH_DIR" |
  while read -r file; do
    [ -f "$file" ] || continue
    is_partial_name "$file" && continue
    if is_complete "$file"; then
      upload_one "$file"
    fi
  done
else
  log "inotifywait not found — falling back to a 30s polling loop."
  while true; do
    sweep
    sleep 30
  done
fi
