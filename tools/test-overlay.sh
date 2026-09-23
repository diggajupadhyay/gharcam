#!/usr/bin/env bash
# Validate the drawtext overlay (clock via textfile+reload, plus label) on a
# synthetic source using the EXACT -vf construction as capture.sh.
set -u
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
OVERLAY_TEXT="gharcam"
WORK=/tmp/ovtest
mkdir -p "$WORK"
printf '%s' "$(date '+%Y-%m-%d %H:%M:%S')" > "$WORK/time.txt"
CLOCK="drawtext=fontfile=${FONT}:textfile=/work/time.txt:reload=1:expansion=none:x=10:y=10:fontsize=20:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=6"
LABEL="drawtext=fontfile=${FONT}:text=${OVERLAY_TEXT}:expansion=none:x=w-tw-10:y=10:fontsize=20:fontcolor=yellow:box=1:boxcolor=black@0.55:boxborderw=6"
FILTER="${CLOCK},${LABEL}"
echo "FILTER=$FILTER"
docker run --rm -v "$WORK":/work:ro --entrypoint ffmpeg ghcr.io/linuxserver/ffmpeg:latest \
  -hide_banner -loglevel info \
  -f lavfi -i "color=c=gray:s=1280x720:r=12" \
  -vf "${FILTER}" -frames:v 2 -f null - 2>&1 \
  | grep -iE "option not found|no option|error|invalid|failed|no such|font|drawtext|configured|Refusing" | head -25
echo "rc=${PIPESTATUS[0]}"