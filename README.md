# gharcam

Plug-and-record webcam CCTV for your LAN: USB camera → FFmpeg → MediaMTX
(RTSP / HLS / WebRTC) with a burned-in timestamp overlay and continuous
recording. Docker-only — nothing installed on the host beyond Docker and
`docker compose`.

## Quickstart (one command)

```bash
git clone https://github.com/diggajupadhyay/gharcam.git && cd gharcam && mkdir -p data/recordings && docker compose up -d
```

Then open (replace `<HOST>` with your machine's IP or `localhost`):

| Protocol | URL |
|---|---|
| Browser (WebRTC, lowest latency) | http://\<HOST\>:8889/cam/ |
| Browser (HLS) | http://\<HOST\>:8888/cam/ |
| VLC / ffplay / Home Assistant | `rtsp://<HOST>:8554/cam` |

- ffplay: `ffplay -rtsp_transport tcp rtsp://<HOST>:8554/cam`

## Prerequisites

1. **Docker + Compose** — https://docs.docker.com/engine/install/
2. **A USB webcam** visible as `/dev/video0` (see below)
3. **Permissions** — your user can access the camera:
   ```bash
   ls -l /dev/video*          # confirm the device node
   sudo usermod -aG video "$USER"   # then log out/in
   ```
4. **Writable recordings dir** — MediaMTX runs as UID/GID `1000:1000`:
   ```bash
   mkdir -p data/recordings
   sudo chown 1000:1000 data/recordings
   ```
   (Skip the `chown` if your user is already UID 1000 — the usual case on a
   fresh Linux desktop/server install.)

### Different camera device

If your camera is not `/dev/video0`, edit `docker-compose.yml`:

```yaml
# capture service
environment:
  - CAM_DEVICE=/dev/video2    # your device
devices:
  - "/dev/video2:/dev/video2:rwm"
```

Then `docker compose up -d --force-recreate capture`.

## What's running

| Service | Image | Role |
|---|---|---|
| `mediamtx` | `bluenviron/mediamtx:1.21.0` | RTSP/HLS/WebRTC server + recorder |
| `capture` | `ghcr.io/linuxserver/ffmpeg` | V4L2 → H.264 with `drawtext` overlay → RTSP |

Recordings land in `./data/recordings/` as 1-hour fMP4 segments.

## Timestamp & label overlay

FFmpeg `drawtext` burns a live clock (top-left) and a label (top-right).

- Clock uses a `textfile` refreshed every second (`reload=1`) so `:` is never
  parsed as an FFmpeg filter separator.
- Configure on the `capture` service in `docker-compose.yml`:
  `OVERLAY_ENABLE=on|off`, `OVERLAY_TEXT=gharcam`, `TZ=...`
- **Timezone:** default is UTC. Set `TZ=Asia/Kolkata` (or yours) on **both**
  services so the burned-in clock matches local time.
- Code: `capture/capture.sh` (`build_filter` + clock writer).

## Recording retention (optional)

`prune-recordings.sh` deletes recordings strictly older than 72 hours
(override with `RETENTION_HOURS`). Wire it up with cron:

```bash
crontab -e
# every 6 hours:
0 */6 * * * /path/to/gharcam/prune-recordings.sh >> /path/to/gharcam/prune.log 2>&1
```

## Operations

```bash
docker compose ps                                 # status
docker compose logs -f capture                    # encoder logs
docker compose logs -f mediamtx                   # router/recorder logs
docker compose restart capture                    # restart encoder
docker compose up -d --force-recreate capture     # apply capture.sh edits
docker compose down                               # stop everything
```

## Tuning

- **CPU:** `CAM_FPS`, `CAM_SIZE`, `CAM_PRESET`, `CAM_BITRATE` on `capture`.
- **Overlay off:** `OVERLAY_ENABLE=off`.
- **No recordings:** set `cam.record: false` in `config/mediamtx.yml`.
- **Regenerate MediaMTX config** (after upgrading the image):
  ```bash
  curl -fsSL -o config/default.yml \
    https://raw.githubusercontent.com/bluenviron/mediamtx/v1.21.0/mediamtx.yml
  python3 gen_config.py
  docker compose up -d --force-recreate mediamtx
  ```
- **WebRTC behind NAT:** if browser WebRTC fails from another network, set
  your reachable host in `gen_config.py` (`webrtcAdditionalHosts`) and
  regenerate.
- Camera unplug/replug: `capture` reconnects automatically (5s backoff).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `bind: cannot assign requested address` | You have an old compose file binding a LAN IP — use this version (ports bind `0.0.0.0`). |
| `no such file or directory /dev/video0` | Wrong `CAM_DEVICE` — see *Different camera device*. |
| `permission denied` on camera | Add yourself to the `video` group, re-login. |
| MediaMTX exits immediately | `config/mediamtx.yml` missing — run `python3 gen_config.py` (or re-clone; it ships with the repo). |
| Recordings not written | `ls -ld data/recordings` must be writable by UID 1000 — see Prerequisites. |
| Overlay text wrong/missing | Check `OVERLAY_TEXT` / font path in `capture` logs. |

## Project layout

```
gharcam/
├── docker-compose.yml      # mediamtx + capture
├── capture/capture.sh      # V4L2 → FFmpeg → RTSP (overlay)
├── config/mediamtx.yml     # generated MediaMTX config (committed)
├── gen_config.py           # regenerates config from upstream default
├── prune-recordings.sh     # optional retention cron job
└── tools/                  # overlay/ffmpeg dev helpers
```

## License

[MIT](LICENSE)
