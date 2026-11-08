# GigaBrowse v2 — the definitive cloud browser

KasmVNC-based Google Chrome running in a GitHub Codespace. The browser runs
in GitHub's datacenter at gigaspeed; your device only shows the picture and
sends taps back. **This is the build the user approved on Nov 8, 2026:
keep the floating keyboard, maximize everything else.**

## What v2 is

| Piece | What it does |
|---|---|
| **KasmVNC desktop** | Fixed 1280×720 landscape desktop, no client resize, native touch, absolute mouse, floating keyboard button (always visible). Encoding tuned for smooth scrolling (60 fps, scroll-region detection). |
| **Google Chrome** | Real Chrome (.deb), dark mode forced, scrollbars hidden, background tabs kept live, 1 GB disk cache, profile persisted in `/config`. |
| **Download pipeline** | Every finished Chrome download is **automatically moved to Google Drive → `GigaBrowse_Downloads`** by a supervised watcher (rclone). Live progress on the start page. Any size/format — including 5 GB+ files. |
| **Start page** | Branded gold/black page on `http://localhost:8080/` — speed test, live download status, quick links, Mini links, tips, honest limits. |
| **Theme** | Luxury modern minimalist, gold/black/white. Custom wallpaper, GigaGold Openbox theme, dark Chrome. No generic white background anywhere. |
| **Auth** | HTTP basic auth (`awar` + `GIGABROWSE_PASSWORD` Codespaces secret). |

## Files in this folder

| File | Purpose |
|---|---|
| `devcontainer.json` | Build from Dockerfile; 4-core/16 GB pin; forwards 3000, 3001, 8080; secrets via `${localEnv:...}`; `/config` named volume |
| `Dockerfile` | `baseimage-kasmvnc:ubuntunoble` + Chrome + rclone + python3 + inotify-tools + feh; copies all configs |
| `kasmvnc.yaml` | KasmVNC server config (all keys verified against the KasmVNC defaults reference) |
| `autostart` | Wallpaper + tuned Chrome launch (Openbox autostart) |
| `chrome-policy.json` | Managed Chrome policy: downloads → `/config/Downloads`, no prompts |
| `01-kasmvnc-config.sh` | cont-init: writes kasmvnc.yaml from `$RESOLUTION` |
| `02-rclone-config.sh` | cont-init: installs rclone config from `RCLONE_CONF_B64` secret |
| `03-giga-theme.sh` | cont-init: installs theme, start page, seeds Chrome prefs |
| `theme/wallpaper.jpg.b64` | Generated gold/black wallpaper (2048×1152), base64-encoded — the repo push is text-only, so the Dockerfile decodes it to `wallpaper.jpg` at image build time (exact same image) |
| `theme/themerc` | GigaGold Openbox theme |
| `theme/rc.xml` | Openbox window-manager config |
| `theme/menu.xml` | Right-click desktop menu |
| `www/index.html`, `www/style.css` | Branded start page + live download status |
| `services/giga-www/run` | s6 service: start-page server on :8080 |
| `services/giga-downloads/run` | s6 service: download watcher |
| `download-watch.sh` | Watcher: finished downloads → `gdrive:GigaBrowse_Downloads` |
| `giga-status.py` | Writes `/config/www/status.json` for the start page |
| `setup-rclone-drive.sh` | **Run on the Mini**: sets both Codespaces secrets from the Mini's rclone config |
| `README.md` | This file |
| `ORACLE.md` | GitHub vs Oracle verdict (short; full runbook: `../oracle-cloud-setup.md`) |

## Setup (in order)

### 1. Set the two Codespaces secrets (on the Mini)

```bash
bash ~/workspace/mac-mini-rebuild/gigabrowse-v2/setup-rclone-drive.sh
```

It reads the Mini's rclone config (remote `gdrive`, created by
`setup_google_drive.sh`), base64s it, and sets `RCLONE_CONF_B64` as a repo
secret, then asks for the browser password and sets `GIGABROWSE_PASSWORD`.
It never prints the token. (Needs `gh` authed on the Mini; otherwise it
prints the base64 once for manual pasting — then clear scrollback.)

Prerequisite: the Mini's rclone remote must already exist. If it doesn't,
run `setup_google_drive.sh` on the Mini first (Google sign-in step).

### 2. Push the v2 files to the repo

From a checkout of `awar456/gigabrowse-10gbps-cloud` (branch `main`, or a
branch + PR — your call at push time). The v2 files live in
`.devcontainer/` in the repo:

```
.devcontainer/devcontainer.json
.devcontainer/Dockerfile
.devcontainer/kasmvnc.yaml
.devcontainer/autostart
.devcontainer/chrome-policy.json
.devcontainer/01-kasmvnc-config.sh
.devcontainer/02-rclone-config.sh
.devcontainer/03-giga-theme.sh
.devcontainer/theme/...
.devcontainer/www/...
.devcontainer/services/...
.devcontainer/download-watch.sh
.devcontainer/giga-status.py
.devcontainer/README.md          (a copy of this file, trimmed if wanted)
```

Nothing in this folder is pushed automatically. **Nothing has been pushed
yet — this is plan + files only, awaiting your go-ahead.**

### 3. Create a fresh Codespace (delete the old one — cleanest)

```bash
gh codespace delete   # the old Selkies one, after confirming nothing in it matters
gh codespace create --repo awar456/gigabrowse-10gbps-cloud
gh codespace ports forward 3000:3020
```

Open http://localhost:3020/ — log in as `awar` with the
`GIGABROWSE_PASSWORD` secret value. The start page (gold/black) should be
the first thing Chrome shows.

### 4. Stop it when done (it bills while running)

```bash
gh codespace stop
```

The Mini can manage start/stop (`gh codespace start/stop`) once `gh` is
authed there — that's the always-on hub half of the setup.

## How downloads work (the pipeline)

1. You download anything in the cloud Chrome, exactly as normal.
   Chrome saves to `/config/Downloads` (policy + preferences, no prompts).
2. The watcher (s6 service `giga-downloads`) sees the finished file —
   Chrome renames `*.crdownload` to the final name on completion, and the
   watcher also requires the size to be stable for 5 seconds.
3. `rclone move` uploads it to `gdrive:GigaBrowse_Downloads/` with
   64 MB chunks, then deletes the local copy. The start page shows live
   progress (%, speed, ETA) while it uploads.
4. The file is in Google Drive, visible on every device — and on the Mini
   via the rclone mount (`/mnt/gdrive/GigaBrowse_Downloads`).

**Timing, honestly:** a 5 GB file takes roughly **1–3 minutes** to appear
in Drive: the cloud fetches it at gigaspeed (~40 s at 1 Gbps), then pushes
it to Drive at gigaspeed (~40 s). Small files arrive in seconds. It does
**not** appear in Drive the instant you press download — the cloud has to
fetch it and then upload it, both at gigaspeed. The start page shows you
exactly where it is at every moment.

**Limits:** Google Drive allows 750 GB of uploads per account per day —
a few 5 GB files a day is nowhere near it. Single files can be up to 5 TB.
If the rclone secret is missing, downloads queue locally in
`/config/Downloads` and upload once the secret is added — nothing is lost.

**Mini follow-up (after first successful upload):** in Jellyfin, add
`/mnt/gdrive/GigaBrowse_Downloads` as a media library (Movies/Shows) so
downloads appear in Jellyfin alongside the rest of the library.

## Speed test (verify the gigaspeed)

1. Open the Codespace, click **Run fast.com** on the start page.
2. Expect ~800–1000 Mbps (the Codespace's datacenter link; the user's
   previous measurement on the old setup was 890 Mbps).
3. If it shows ~40 Mbps, something is wrong — you are measuring the home
   link, not the cloud. Check that you are looking at the Codespace stream
   (http://localhost:3020/), not a local browser.

## iPhone / iPad / Mac — what to expect

- **Whole desktop, no scrollbars:** fixed 1280×720 + Local Scaling means
  the full desktop fits your screen. Chrome also hides page scrollbars
  (`--hide-scrollbars`).
- **Tap = click where you touch** (native touch, absolute mouse).
- **Typing:** tap the floating keyboard button (bottom of the screen).
  The native iOS keyboard will never appear inside a streamed desktop —
  that's physics (the phone sees a video, not a web page), and it is the
  trade-off you accepted to keep the gigaspeed and the speed-test numbers.
- **Zoom:** floating keyboard → `Ctrl`+`+` / `Ctrl`+`−`. Pinch-to-zoom
  in the KasmVNC client is **unverified** — test it on first use and
  record the result; the Ctrl++ path works regardless.
- **Best client settings (KasmVNC web client):** Scaling Mode = Local
  Scaling; Image Quality = High (on Wi-Fi) / Medium (on cellular);
  Frame Rate = 60 on Wi-Fi, 30 on cellular if it stutters.
- **Resolution:** 1280×720 is the default (smooth everywhere). For a
  sharper Mac/iPad desktop, set `RESOLUTION=1920x1080` in
  `devcontainer.json` and rebuild — costs more bandwidth on the phone.

## What this build cannot do (read before promising anything)

- **Apple TV / Amazon Prime purchases cannot be downloaded as files.**
  Movies and shows bought on Apple TV and Amazon Prime are DRM-protected
  streams. A browser cannot save them as playable files to Drive, and no
  download pipeline can change that — the protection is the point. Their
  apps' offline downloads are encrypted and locked to the app that made
  them. The pipeline handles **direct file downloads of any size/format**
  (videos, ISOs, zips, music, documents, 5 GB+ movies from direct links);
  it cannot rip DRM streaming purchases. The way to actually *own* a movie
  is a physical disc: buy the Blu-ray/DVD and rip it to the Mini/Jellyfin.
  (California AB 2426, effective Jan 1, 2025, now requires digital stores
  to disclose that "buy" is a license, not ownership. Apple refunds:
  reportaproblem.apple.com, usually decided in 24–48 h, best odds on
  recent/unwatched titles; Amazon is stricter — mainly accidental or
  unwatched purchases.)
- **Native iOS keyboard / native scrolling will never appear** inside any
  streamed remote desktop (KasmVNC, Selkies, all of them). The floating
  keyboard is the price of the gigaspeed stream.
- **Codespaces are not 24/7:** 30 min idle timeout (configurable 5–240
  min), 12 h max runtime, 30 h/month free on a 4-core machine (GitHub
  Free). The always-on half is the Mini + the Oracle VM (see ORACLE.md).

## Cost

- GitHub Free: 120 core-hours/month = **30 h/month on the 4-core
  machine**, then Codespaces stop (no charge unless a payment method is on
  file; overage would be $0.36/h). Storage 15 GB included.
- GitHub Pro ($4/month): 180 core-hours = 45 h/month. Not needed unless
  you outgrow 30 h.
- Oracle VM (always-on companion): $0 — see ORACLE.md.

## Troubleshooting

| Symptom | Fix |
|---|---|
| UI loads but Chrome never opens | `gh codespace ssh`, then `docker logs` / check `/config/.config/openbox/autostart` exists; check `curl -s http://127.0.0.1:8080/` inside the container |
| Start page shows an error / blank | s6 service `giga-www` not up: check `python3 -m http.server` is running; the autostart waits up to 30 s for it |
| Downloads stay local, never reach Drive | `RCLONE_CONF_B64` secret missing or bad — check the watcher log `/config/downloads/watcher.log`; re-run `setup-rclone-drive.sh` on the Mini |
| `rclone lsd gdrive:` fails in the container | Token expired or generated with different OAuth client credentials — regenerate on the Mini and re-set the secret |
| Black/white desktop instead of gold | `03-giga-theme.sh` runs at container start; check it copied files to `/config/theme/` and `/config/.config/openbox/`; `feh` must be installed (Dockerfile does it) |
| Stream is choppy on the phone | KasmVNC client → lower Image Quality / Frame Rate to 30; or switch the desktop to 1280×720 (default) |
| KasmVNC UI loads but the VNC session is black | `network.interface: 127.0.0.1` + `require_ssl: false` in kasmvnc.yaml assumes the LSIO NGINX proxy layout; if the base image changes, try `interface: 0.0.0.0` |
| Codespace stops mid-session | 30-min idle timeout or 12 h max — restart with `gh codespace start` |

## Rollout checklist (after push)

1. Codespace builds; UI loads on :3000; basic-auth prompt appears.
2. `cat /etc/kasmvnc/kasmvnc.yaml` matches intent (1280×720, allow_resize false, touch_support true, scroll detection on).
3. Start page loads (gold/black) on Chrome launch; `curl http://127.0.0.1:8080/status.json` returns JSON.
4. iPhone: whole desktop fits, no scrollbars; tap = click; floating keyboard types; Ctrl++ zooms; pinch tested + recorded.
5. Download a small test file → appears in Drive → `GigaBrowse_Downloads` within seconds; start page shows it in "Recently arrived".
6. Download a large test file (e.g. a 1 GB test file) → progress shows live → lands in Drive.
7. fast.com from the stream: ~800–1000 Mbps.
8. `gh codespace stop` works; Mini can start/stop it.
9. Jellyfin library added for `/mnt/gdrive/GigaBrowse_Downloads` (Mini side).

## Sources (verified Nov 8, 2026)

- KasmVNC configuration reference + defaults YAML (`kasmtech/KasmVNC`
  `unix/kasmvnc_defaults.yaml`, fetched live) — every kasmvnc.yaml key.
- LinuxServer `docker-baseimage-kasmvnc` README (fetched live) — env vars
  (`CUSTOM_USER`, `PASSWORD`, `TITLE`, `CUSTOM_PORT`), `/defaults/autostart`
  pattern, s6-overlay v3, `/custom-cont-init.d/` + `/custom-services.d/`.
- Chromium source (`content_switches.cc`, `ui_base_switches.h`) —
  `--hide-scrollbars`, `--force-dark-mode` are real switches.
- rclone docs + headless-authorization guides — `rclone authorize`,
  `--drive-chunk-size`, `rclone move`, 750 GB/day Drive upload cap.
- GitHub Codespaces billing — 120 core-hours Free, $0.09/core-hour.
