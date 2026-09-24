# gharcam

**Quick home CCTV in one command** — plug in any USB webcam, run, and you get
live RTSP / HLS / WebRTC plus continuous loop recording with a burned-in
timestamp. Docker-only; nothing installed on the host beyond Docker.

```bash
git clone https://github.com/diggajupadhyay/gharcam.git && cd gharcam \
  && cp .env.example .env && mkdir -p data/recordings \
  && docker compose up -d
```

| Protocol | URL |
|---|---|
| **WebRTC** (lowest latency) | `http://<HOST>:8889/cam/` |
| **HLS** (broadest browser support) | `http://<HOST>:8888/cam/` |
| **RTSP** (VLC / ffplay / NVR / Home Assistant) | `rtsp://<HOST>:8554/cam` |

Replace `<HOST>` with your machine’s LAN IP (e.g. `192.168.1.50`) or
`localhost` if viewing on the same machine.

```bash
ffplay -rtsp_transport tcp rtsp://<HOST>:8554/cam
```

## Prerequisites

1. **Docker + Compose v2** — https://docs.docker.com/engine/install/
2. **A USB webcam** (UVC / V4L2) — almost every modern webcam works
3. **Camera access:**
   ```bash
   ls -l /dev/video*                 # find your device (usually video0)
   sudo usermod -aG video "$USER"    # then log out / back in
   ```
4. **Writable recordings directory** (MediaMTX runs as UID/GID `1000:1000`):
   ```bash
   mkdir -p data/recordings
   sudo chown 1000:1000 data/recordings   # skip if your UID is already 1000
   ```

## Configuration (`.env`)

Copy the template and edit — no YAML surgery required:

```bash
cp .env.example .env
```

| Variable | Default | Purpose |
|---|---|---|
| `RECORD_SEGMENT_DURATION` | `1h` | Length of each recording file (`15m`, `30m`, `1h`, `6h`, …) |
| `RETENTION_HOURS` | `72` | Auto-delete recordings older than this (prune script) |
| `CAM_DEVICE` | `/dev/video0` | Camera device node |
| `CAM_FORMAT` | `mjpeg` | `mjpeg`, or `auto` to let the camera choose |
| `CAM_SIZE` | `1280x720` | Capture resolution |
| `CAM_FPS` | `12` | Frames per second |
| `CAM_BITRATE` | `1600k` | Video bitrate |
| `CAM_PRESET` | `superfast` | x264 preset (speed vs compression) |
| `OVERLAY_ENABLE` | `on` | Burn timestamp + label into the video |
| `OVERLAY_TEXT` | `gharcam` | Label shown top-right |
| `TZ` | `UTC` | Timezone for the burned-in clock **and** container |

Apply changes:

```bash
docker compose up -d --force-recreate
```

### Any webcam

- Not `/dev/video0`? Set `CAM_DEVICE=/dev/video2` in `.env` (the compose file
  maps whatever you set).
- Camera rejects `1280x720@12` MJPG? Leave defaults — after two failures the
  capture loop **automatically falls back** to camera auto-detect mode.
- Still failing? Try `CAM_FORMAT=auto` and a conservative `CAM_SIZE=640x480`,
  `CAM_FPS=15`.

### Recording loop timing

Each recording file is **`RECORD_SEGMENT_DURATION`** long (default `1h`).
Files are written to `data/recordings/cam/` as fMP4. Set a shorter segment
(e.g. `15m`) if you want more, smaller files.

Retention is separate: `prune-recordings.sh` removes files older than
`RETENTION_HOURS` (default 72). Optional cron:

```bash
crontab -e
0 */6 * * * /path/to/gharcam/prune-recordings.sh >> /path/to/gharcam/prune.log 2>&1
```

The script reads `RETENTION_HOURS` from your `.env` automatically.

## How it works

```
USB webcam ──V4L2──▶ capture (FFmpeg, overlay) ──RTSP──▶ MediaMTX ──▶ RTSP / HLS / WebRTC
                                                    └──▶ data/recordings/ (loop segments)
```

| Service | Image | Role |
|---|---|---|
| `mediamtx` | `bluenviron/mediamtx:1.21.0` | Media router + recorder |
| `capture` | `ghcr.io/linuxserver/ffmpeg` | Webcam → H.264 + timestamp overlay → RTSP |

Both services use **`network_mode: host`** so WebRTC’s UDP media path (port
`8189/udp`) works out of the box on your LAN. Ports used:

| Port | Proto | Purpose |
|---|---|---|
| 8554 | TCP | RTSP |
| 8888 | TCP | HLS |
| 8889 | TCP | WebRTC signaling (WHEP) + player page |
| 8189 | UDP | WebRTC media (ICE) — **must be reachable** |

### Why WebRTC might not connect

HLS (8888) only needs TCP; WebRTC also needs **UDP 8189** to your machine.

- Firewall: allow `8189/udp` (and `8889/tcp`) on the host
  (`sudo ufw allow 8189/udp && sudo ufw allow 8889/tcp`)
- Same LAN recommended for first run; across subnets/VPN, UDP must be routed
- Prefer HLS (`:8888`) if WebRTC is blocked — it always works through TCP

## Overlay

- Top-left: live clock (from container `TZ`)
- Top-right: `OVERLAY_TEXT`
- Disable with `OVERLAY_ENABLE=off`

## Operations

```bash
docker compose ps                          # status
docker compose logs -f capture             # encoder logs
docker compose logs -f mediamtx            # router / recorder logs
docker compose restart capture             # restart encoder
docker compose up -d --force-recreate      # apply .env changes
docker compose down                        # stop
```

## Advanced: regenerate MediaMTX config

`config/mediamtx.yml` is committed and works as-is. Only regenerate after a
MediaMTX version upgrade:

```bash
curl -fsSL -o config/default.yml \
  https://raw.githubusercontent.com/bluenviron/mediamtx/v1.21.0/mediamtx.yml
python3 gen_config.py
docker compose up -d --force-recreate mediamtx
```

Recording segment duration is applied at **runtime** via
`RECORD_SEGMENT_DURATION` — you do not need to regenerate for that.

## Troubleshooting

| Symptom | Fix |
|---|---|
| WebRTC page loads but no video | Open UDP `8189` firewall; try HLS on `:8888` |
| `no such file or directory /dev/video*` | Wrong `CAM_DEVICE` in `.env` |
| `permission denied` on camera | `sudo usermod -aG video "$USER"`, re-login |
| Capture restart loop | Check logs; try `CAM_FORMAT=auto`, lower `CAM_SIZE` |
| Recordings not written | `chown 1000:1000 data/recordings` |
| Overlay clock wrong | Set `TZ` in `.env` (e.g. `Asia/Kolkata`) |
| Port already in use | Stop the other service or change host ports (host mode binds directly) |

## Project layout

```
gharcam/
├── .env.example           # configuration template
├── docker-compose.yml     # mediamtx + capture (host network)
├── capture/capture.sh     # V4L2 → FFmpeg → RTSP (auto-fallback)
├── config/mediamtx.yml    # MediaMTX config (committed)
├── gen_config.py          # regenerate config after MediaMTX upgrades
├── prune-recordings.sh    # retention cron job
└── tools/                 # overlay / FFmpeg dev helpers
```

## License

[MIT](LICENSE)
