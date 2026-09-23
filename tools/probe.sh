#!/usr/bin/env bash
# Probe which drawtext timestamp encodings this FFmpeg 9.0 build accepts.
set -u
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf

probe() {
  local desc="$1" filt="$2"
  local out
  out="$(docker run --rm --entrypoint ffmpeg ghcr.io/linuxserver/ffmpeg:latest \
    -hide_banner -loglevel error -f lavfi -i "color=c=gray:s=320x240:r=5" \
    -vf "${filt}" -frames:v 1 -f null - 2>&1 | head -1)"
  if [ -z "$out" ]; then
    echo "PASS  $desc"
  else
    echo "FAIL  $desc :: $out"
  fi
}

probe "A: q+strftime cols"     "drawtext=fontfile=$FONT:text='%H:%M:%S':strftime=1:x=10:y=10"
probe "B: noq+strftime cols"   "drawtext=fontfile=$FONT:text=%H:%M:%S:strftime=1:x=10:y=10"
probe "C: sb+strftime"         "drawtext=fontfile=$FONT:text=%H\\:%M\\:%S:strftime=1:x=10:y=10"
probe "D: db+strftime"         "drawtext=fontfile=$FONT:text=%H\\\\:%M\\\\:%S:strftime=1:x=10:y=10"
probe "E: q-localtime"         "drawtext=fontfile=$FONT:text='%{localtime:%H:%M:%S}':x=10:y=10"
probe "F: sb-localtime"        "drawtext=fontfile=$FONT:text=%{localtime\\:%H\\:%M\\:%S}:x=10:y=10"
probe "G: nosep underscores"   "drawtext=fontfile=$FONT:text=%Y-%m-%d_%H-%M-%S:strftime=1:x=10:y=10"
probe "H: underscore+dash"     "drawtext=fontfile=$FONT:text=%Y-%m-%d_%H-%M-%S:x=10:y=10:expansion=none"
probe "I: G + label filter"    "drawtext=fontfile=$FONT:text=%Y-%m-%d_%H-%M-%S:strftime=1:x=10:y=10,drawtext=fontfile=$FONT:text=ROOMCAM:x=w-tw-10:y=10"