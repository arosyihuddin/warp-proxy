#!/usr/bin/env bash
# Status instance WARP: container jalan/stop + egress IP.
#
# Tiga mode (konsisten dengan command lain):
#   make status           → status semua instance (1..COUNT)
#   make status N         → status instance 1..N
#   make status -i N      → status instance ke-N saja

set -euo pipefail
cd "$(dirname "$0")/.."   # root proyek (tempat .env & docker-compose.yml)

# ── load .env ───────────────────────────────────────────────────────────
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

HOST="${WARP_PROXY_HOST:-127.0.0.1}"
PORT="${WARP_PORT_START:-40001}"
COUNT="${WARP_INSTANCE_COUNT:-1}"

# ── parse argumen ───────────────────────────────────────────────────────
if [ "${1:-}" = "-i" ]; then
  START_I="${2:?butuh nomor instance, contoh: status -i 3}"
  END_I="$START_I"
elif [ -n "${1:-}" ]; then
  START_I=1
  END_I="${1}"
else
  START_I=1
  END_I="$COUNT"
fi

echo "Status instance WARP:"
echo ""

for i in $(seq "$START_I" "$END_I"); do
  p=$((PORT + i - 1))
  cname="warp-proxy-${i}"

  # container jalan / stop?
  state="✗ stopped"
  if docker ps --format '{{.Names}}' | grep -q "^${cname}$"; then
    state="✓ running"
  fi

  # IP egress (kalau jalan)
  ip="-"
  if [ "$state" = "✓ running" ]; then
    ip=$(curl -sx "http://${HOST}:${p}" https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | awk -F= '/^ip=/{print $2}')
    ip="${ip:-?}"
  fi

  printf "  %-15s  %-9s  ip=%s\n" "warp-proxy-${i}" "${state}" "${ip}"
done
