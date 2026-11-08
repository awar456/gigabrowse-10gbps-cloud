#!/usr/bin/with-contenv bash
# GigaBrowse v2 — write the KasmVNC server config before Xvnc starts.
# Same content as kasmvnc.yaml in the repo; $RESOLUTION (WxH, e.g. 1280x720)
# overrides the width/height. All keys are from the KasmVNC configuration
# reference / defaults (kasmtech/KasmVNC unix/kasmvnc_defaults.yaml).
set -e
RES="${RESOLUTION:-1280x720}"
WIDTH="${RES%x*}"
HEIGHT="${RES#*x}"
mkdir -p /etc/kasmvnc /usr/local/etc/kasmvnc
cat > /etc/kasmvnc/kasmvnc.yaml <<EOF
desktop:
  resolution:
    width: ${WIDTH}
    height: ${HEIGHT}
  allow_resize: false
  pixel_depth: 24
  gpu:
    hw3d: false
    drinode: /dev/dri/renderD128
max_resolution:
  width: 1920
  height: 1080
pointer:
  enabled: true
  game_mode: false
  touch_support: true
keyboard:
  enabled: true
  remap_keys: {}
  ignore_numlock: false
  raw_keyboard: false
network:
  protocol: http
  interface: 127.0.0.1
  websocket_port: auto
  use_ipv4: true
  use_ipv6: true
  ssl:
    require_ssl: false
runtime_configuration:
  allow_client_to_override_kasm_server_settings: true
  allow_override_standard_vnc_server_settings: true
  allow_override_list:
    - pointer.enabled
    - data_loss_prevention.clipboard.server_to_client.enabled
    - data_loss_prevention.clipboard.client_to_server.enabled
    - data_loss_prevention.clipboard.server_to_client.primary_clipboard_enabled
encoding:
  max_frame_rate: 60
  full_frame_updates: none
  rect_encoding_mode:
    min_quality: 7
    max_quality: 8
    consider_lossless_quality: 10
    rectangle_compress_threads: auto
  video_encoding_mode:
    jpeg_quality: -1
    webp_quality: -1
    max_resolution:
      width: 1920
      height: 1080
    enter_video_encoding_mode:
      time_threshold: 5
      area_threshold: 45%
    exit_video_encoding_mode:
      time_threshold: 3
    scaling_algorithm: progressive_bilinear
    webp_encoding_time: 30
  video_streaming_mode:
    codec: auto
  compare_framebuffer: auto
  zrle_zlib_level: auto
  hextile_improved_compression: true
  scrolling:
    detect_vertical_scrolling: true
    detect_horizontal_scrolling: false
    scroll_detect_threshold: 25%
data_loss_prevention:
  clipboard:
    server_to_client:
      enabled: true
      size: unlimited
      primary_clipboard_enabled: false
    client_to_server:
      enabled: true
      size: unlimited
security:
  brute_force_protection:
    blacklist_threshold: 5
    blacklist_timeout: 10
user_session:
  idle_timeout: never
server:
  auto_shutdown:
    no_user_session_timeout: never
    active_user_session_timeout: never
    inactive_user_session_timeout: never
EOF
cp /etc/kasmvnc/kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml.lsio
cp /etc/kasmvnc/kasmvnc.yaml /usr/local/etc/kasmvnc/kasmvnc.yaml
cp /etc/kasmvnc/kasmvnc.yaml /usr/local/etc/kasmvnc/kasmvnc.yaml.lsio
echo "gigabrowse: kasmvnc resolution set to ${WIDTH}x${HEIGHT}"
