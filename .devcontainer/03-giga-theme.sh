#!/usr/bin/with-contenv bash
# GigaBrowse v2 — install the theme (gold/black/white, no generic white).
# Runs on every container start; only touches our own files, so it is
# idempotent and safe on rebuilds (re-applying the theme after an update).
set -e
mkdir -p /config/.config/openbox /config/theme /config/www /config/Downloads /config/chrome-profile

# Wallpaper (desktop background, set by feh in autostart).
cp /usr/share/gigabrowse/wallpaper.jpg /config/theme/wallpaper.jpg
# Same wallpaper as the start-page background (served from /config/www).
cp /usr/share/gigabrowse/wallpaper.jpg /config/www/wallpaper.jpg

# Openbox window-manager config + right-click menu.
cp /usr/share/gigabrowse/rc.xml /config/.config/openbox/rc.xml
cp /usr/share/gigabrowse/menu.xml /config/.config/openbox/menu.xml

# Branded start page (served on :8080 by s6 service giga-www).
cp /usr/share/gigabrowse/www/index.html /config/www/index.html
cp /usr/share/gigabrowse/www/style.css /config/www/style.css

# Initial download-status file (the watcher overwrites it continuously).
if [ ! -f /config/www/status.json ]; then
  cat > /config/www/status.json <<'EOF'
{"updated": "starting", "rclone": "unknown", "uploading": null, "pending": 0, "completed": []}
EOF
fi

# Seed Chrome preferences on FIRST run only (never overwrite an existing
# profile): downloads go to /config/Downloads with no "save as" prompt,
# dark theme preferred. The --force-dark-mode flag in autostart is the
# primary dark-mode mechanism; this is belt-and-braces.
if [ ! -f /config/chrome-profile/Default/Preferences ]; then
  mkdir -p /config/chrome-profile/Default
  cat > /config/chrome-profile/Default/Preferences <<'EOF'
{
  "download": {
    "default_directory": "/config/Downloads",
    "prompt_for_download": false,
    "directory_upgrade": true
  },
  "browser": {
    "theme": {
      "color_scheme": 2
    }
  }
}
EOF
fi

echo "gigabrowse: theme installed (GigaGold, wallpaper, start page)"
