#!/usr/bin/env bash
# Resilient camera capture loop.
# Reads the LifeCam HD-5000 (V4L2, MJPG mode) and pushes a low-latency
# H.264 RTSP stream (with on-screen timestamp + room label overlay) into MediaMTX.
# Auto-restarts on failure.
set -u

RTSP_URL="${RTSP_URL:-rtsp://mediamtx:8554/cam}"
CAM_DEVICE="${CAM_DEVICE:-/dev/video0}"
CAM_SIZE="${CAM_SIZE:-1280x720}"
CAM_FPS="${CAM_FPS:-12}"
CAM_BITRATE="${CAM_BITRATE:-1600k}"
CAM_PRESET="${CAM_PRESET:-superfast}"

# --- Overlay options ---
OVERLAY_ENABLE="${OVERLAY_ENABLE:-on}"
OVERLAY_TEXT="${OVERLAY_TEXT:-gharcam}"
TIME_FILE="${TIME_FILE:-/tmp/cam_time.txt}"
# DejaVuSans-Bold ships inside the linuxserver/ffmpeg image
FONT_FILE="${FONT_FILE:-/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf}"

log() { echo "[capture] $*"; }

log "waiting for camera device ${CAM_DEVICE}"
until [ -e "${CAM_DEVICE}" ]; do
  log "${CAM_DEVICE} not present yet, retrying in 3s"
  sleep 3
done
log "device present: $(ls -l "${CAM_DEVICE}")"

# Live clock writer: refresh the overlay clock text every second.
# Used via drawtext textfile=+reload=1 so rendered ':' are NOT parsed as
# FFmpeg filter separators (this build cannot escape colons in a text value).
( while :; do date '+%Y-%m-%d %H:%M:%S' > "${TIME_FILE}"; sleep 1; done ) &
log "clock writer started (${TIME_FILE})"

GOP=$(( CAM_FPS * 3 ))

build_filter() {
  local ts="drawtext=fontfile=${FONT_FILE}:textfile=${TIME_FILE}:reload=1:expansion=none:x=10:y=10:fontsize=20:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=6"
  local lbl="drawtext=fontfile=${FONT_FILE}:text=${OVERLAY_TEXT}:expansion=none:x=w-tw-10:y=10:fontsize=20:fontcolor=yellow:box=1:boxcolor=black@0.55:boxborderw=6"
  echo "${ts},${lbl}"
}

while true; do
  VF_ARGS=()
  if [ "${OVERLAY_ENABLE}" = "on" ]; then
    VF_ARGS+=( "-vf" "$(build_filter)" )
  fi
  log "starting ffmpeg (${CAM_SIZE}@${CAM_FPS}fps, ${CAM_BITRATE}) -> ${RTSP_URL}"
  ffmpeg -hide_banner -loglevel warning \
    -f v4l2 -input_format mjpeg -framerate "${CAM_FPS}" -video_size "${CAM_SIZE}" \
    -i "${CAM_DEVICE}" \
    -an \
    "${VF_ARGS[@]}" \
    -c:v libx264 -preset "${CAM_PRESET}" -tune zerolatency \
    -pix_fmt yuv420p -profile:v high -level 4.0 \
    -g "${GOP}" -keyint_min "${GOP}" \
    -b:v "${CAM_BITRATE}" -maxrate "${CAM_BITRATE}" -bufsize 3200k \
    -f rtsp -rtsp_transport tcp "${RTSP_URL}"
  rc=$?
  log "ffmpeg exited with code ${rc}, restarting in 5s"
  sleep 5
done