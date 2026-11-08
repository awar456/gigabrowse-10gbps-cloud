# GigaBrowse v2 — KasmVNC-based cloud browser, tuned for maximum speed and
# a luxury gold/black/white look.
#
# Base: LinuxServer baseimage-kasmvnc (Ubuntu 24.04), actively maintained.
# (lscr.io/linuxserver/chromium:latest is Selkies-based now; the kasm tags
#  were deprecated July 2026, so we build on the KasmVNC base instead.)
#
# What this image adds over the v1 plan:
#   - Real Google Chrome (.deb — Ubuntu's chromium-browser is a snap stub)
#   - rclone + a supervised download watcher: every Chrome download is
#     automatically moved to Google Drive (gdrive:GigaBrowse_Downloads)
#   - A branded gold/black start page + download-status server on :8080
#   - GigaGold Openbox theme + custom wallpaper (no generic white desktop)
#   - Chrome managed policy: downloads go to /config/Downloads, no prompts
FROM ghcr.io/linuxserver/baseimage-kasmvnc:ubuntunoble

# Tools:
#   python3       — start-page HTTP server + download-status JSON writer
#   inotify-tools — download watcher (inotifywait)
#   feh           — set the desktop wallpaper
#   rclone        — Google Drive uploads (official .deb; Ubuntu's apt build lags)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg python3 inotify-tools feh \
 && curl -fsSL https://downloads.rclone.org/rclone-current-linux-amd64.deb -o /tmp/rclone.deb \
 && apt-get install -y /tmp/rclone.deb \
 && rm -f /tmp/rclone.deb \
 && curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/google-chrome.deb \
 && apt-get install -y /tmp/google-chrome.deb \
 && rm -f /tmp/google-chrome.deb \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# KasmVNC server config: fixed 1280x720 landscape desktop, no client resize
# (the desktop stays desktop-shaped on a phone), native touch on, absolute
# mouse, encoding tuned for smooth scrolling (see kasmvnc.yaml comments).
# Installed as the live config and as the .lsio template the base image's
# first-run init renames into place.
COPY kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml
COPY kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml.lsio
COPY kasmvnc.yaml /usr/local/etc/kasmvnc/kasmvnc.yaml
COPY kasmvnc.yaml /usr/local/etc/kasmvnc/kasmvnc.yaml.lsio

# Chrome managed policy: downloads land in /config/Downloads with no
# "save as" prompt; no password-manager popups; no metrics.
COPY chrome-policy.json /etc/opt/chrome/policies/managed/gigabrowse.json

# Theme assets (cont-init copies them into /config on every start).
# The wallpaper is stored base64-encoded (wallpaper.jpg.b64) because the
# repo push is text-only; it is decoded to wallpaper.jpg in the RUN below.
COPY theme/wallpaper.jpg.b64 /usr/share/gigabrowse/wallpaper.jpg.b64
COPY theme/themerc /usr/share/themes/GigaGold/openbox-3/themerc
COPY theme/rc.xml /usr/share/gigabrowse/rc.xml
COPY theme/menu.xml /usr/share/gigabrowse/menu.xml

# Branded start page + download status (served on :8080 by s6 service giga-www).
COPY www/ /usr/share/gigabrowse/www/

# Openbox autostart: wallpaper + tuned Chrome. The LSIO init copies this to
# /config/.config/openbox/autostart on first run.
COPY autostart /defaults/autostart

# Container init (run before any service starts):
#   01 — write kasmvnc.yaml deterministically from $RESOLUTION
#   02 — install the rclone config from the RCLONE_CONF_B64 secret
#   03 — install theme files + start page + seed Chrome preferences
COPY 01-kasmvnc-config.sh /custom-cont-init.d/01-kasmvnc-config.sh
COPY 02-rclone-config.sh /custom-cont-init.d/02-rclone-config.sh
COPY 03-giga-theme.sh /custom-cont-init.d/03-giga-theme.sh

# Supervised services (s6): start-page server + download watcher.
COPY services/giga-www/run /custom-services.d/giga-www/run
COPY services/giga-downloads/run /custom-services.d/giga-downloads/run
COPY download-watch.sh /usr/local/bin/giga-download-watch.sh
COPY giga-status.py /usr/local/bin/giga-status.py

RUN chmod +x /custom-cont-init.d/*.sh \
      /custom-services.d/giga-www/run \
      /custom-services.d/giga-downloads/run \
      /usr/local/bin/giga-download-watch.sh \
      /usr/local/bin/giga-status.py \
 && base64 -d /usr/share/gigabrowse/wallpaper.jpg.b64 > /usr/share/gigabrowse/wallpaper.jpg \
 && rm /usr/share/gigabrowse/wallpaper.jpg.b64
