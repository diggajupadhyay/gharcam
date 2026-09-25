#!/usr/bin/env python3
"""Generate mediamtx.yml from the pristine v1.21.0 default shipped config.

Deterministic and idempotent: run AFTER downloading default.yml.
"""
import pathlib
import sys

base = pathlib.Path(__file__).resolve().parent
src = base / "config" / "default.yml"
dst = base / "config" / "mediamtx.yml"

if not src.exists():
    sys.exit("error: config/default.yml missing - download it first")

text = src.read_text()

replacements = {
    # api/metrics/pprof stay DISABLED (default) - not exposed
    "rtmp: true\n": "rtmp: false\n",
    "srt: true\n": "srt: false\n",
    "moq: true\n": "moq: false\n",
    "hlsVariant: lowLatency\n": "hlsVariant: mpegts\n",
    "rpiCameraAfMode: continuous\n": "rpiCameraAfMode: manual\n",
    # For WebRTC behind NAT, set your public/LAN host here, e.g.:
    # 'webrtcAdditionalHosts: []\n': 'webrtcAdditionalHosts: ["192.168.1.50"]\n',
}

for old, new in replacements.items():
    n = text.count(old)
    if n != 1:
        sys.exit(f"error: pattern not unique/missing: {old!r} (count={n})")
    text = text.replace(old, new)

cam_block = """  cam:
    source: publisher
    record: true
    recordPath: /recordings/%path/%Y-%m-%d_%H-%M-%S-%f
    recordFormat: fmp4
    recordPartDuration: 1s
    recordSegmentDuration: 1h
  all_others:
"""
if "  cam:\n" not in text:
    if text.count("  all_others:\n") != 1:
        sys.exit("error: 'all_others:' anchor not unique")
    text = text.replace("  all_others:\n", cam_block, 1)

dst.write_text(text)
print(f"wrote {dst}")