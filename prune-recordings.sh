#!/usr/bin/env bash
# Delete CCTV recordings strictly older than RETENTION_HOURS hours (default 72).
# Reads RETENTION_HOURS from .env if present. Run via user crontab every 6h.
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"

# Load .env (RETENTION_HOURS, etc.) without overriding already-set vars
if [ -f "${BASE}/.env" ]; then
  while IFS= read -r line; do
    case "${line}" in
      ''|'#'*) continue ;;
      RETENTION_HOURS=*)
        if [ -z "${RETENTION_HOURS:-}" ]; then
          eval "${line}"
        fi
        ;;
    esac
  done < "${BASE}/.env"
fi

RETENTION_HOURS="${RETENTION_HOURS:-72}"
MINUTES=$(( RETENTION_HOURS * 60 ))
FIND_BIN="$(command -v find)"

prune_dir() {
  local d="$1" b a
  [ -d "$d" ] || return 0
  b="$( "${FIND_BIN}" "$d" -type f 2>/dev/null | wc -l )"
  "${FIND_BIN}" "$d" -type f -mmin "+${MINUTES}" -delete 2>/dev/null
  a="$( "${FIND_BIN}" "$d" -type f 2>/dev/null | wc -l )"
  echo "$(date -Is) [prune] ${d}: before=${b} after=${a}"
}

if [ -z "${FIND_BIN}" ]; then
  echo "$(date -Is) [prune] find unavailable"
  exit 0
fi

prune_dir "${BASE}/data/recordings"
