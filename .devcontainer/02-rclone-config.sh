#!/usr/bin/with-contenv bash
# GigaBrowse v2 — install the rclone config for Google Drive uploads.
#
# The rclone config contains a Google OAuth refresh token: it is a
# credential. It is NEVER committed to the repo. It arrives as the
# RCLONE_CONF_B64 Codespaces secret (base64 of the Mini's rclone.conf —
# see setup-rclone-drive.sh, run on the Mini). This script decodes it into
# /config/rclone/rclone.conf (mode 600) and verifies the remote works.
#
# If the secret is absent, downloads simply accumulate in /config/Downloads
# and the watcher waits — nothing is lost, nothing uploads.
set -e
mkdir -p /config/rclone /config/Downloads /config/downloads /config/www

if [ -n "${RCLONE_CONF_B64:-}" ]; then
  echo "$RCLONE_CONF_B64" | base64 -d > /config/rclone/rclone.conf
  chmod 600 /config/rclone/rclone.conf
  echo "gigabrowse: rclone config installed from RCLONE_CONF_B64 secret"
  if rclone --config /config/rclone/rclone.conf lsd gdrive: >/dev/null 2>&1; then
    echo "gigabrowse: Drive remote OK (gdrive: reachable)"
  else
    echo "gigabrowse: WARNING — rclone config present but 'rclone lsd gdrive:' failed. Check the token (it may have expired or been generated with different client credentials)."
  fi
else
  echo "gigabrowse: RCLONE_CONF_B64 not set — downloads will stay local in /config/Downloads until the secret is added (see setup-rclone-drive.sh)."
fi
