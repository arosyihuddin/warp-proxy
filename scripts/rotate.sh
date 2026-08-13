#!/usr/bin/env bash
# Rotate WARP tunnel keys tiap instance.
#
# Tiga mode:
#   make rotate        → semua instance (1..COUNT)
#   make rotate N      → instance 1..N
#   make rotate -i N   → instance ke-N saja

set -euo pipefail
cd "$(dirname "$0")/.."   # root proyek (tempat .env & docker-compose.yml)

# ── load .env ───────────────────────────────────────────────────────────
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

COUNT="${WARP_INSTANCE_COUNT:-1}"

rotate_one() {
  local n="$1"
  local cname="warp-proxy-${n}"

  if docker ps --format '{{.Names}}' | grep -q "^${cname}$"; then
    echo "  rotate keys: ${cname}"
    docker exec "$cname" warp-cli --accept-tos tunnel rotate-keys \
      && echo "  ✓ ${cname} keys rotated." \
      || echo "  ✗ ${cname} rotate gagal"
  else
    echo "  ✗ ${cname} nggak jalan (skip)"
  fi
}

# ── parse argumen ───────────────────────────────────────────────────────
if [ "${1:-}" = "-i" ]; then
  echo "Rotate WARP tunnel keys instance ${2:?butuh nomor instance, contoh: rotate -i 3}:"
  rotate_one "$2"
elif [ -n "${1:-}" ]; then
  echo "Rotate WARP tunnel keys instance 1..${1}:"
  for n in $(seq 1 "$1"); do rotate_one "$n"; done
else
  echo "Rotate WARP tunnel keys semua instance (1..${COUNT}):"
  for n in $(seq 1 "$COUNT"); do rotate_one "$n"; done
fi
