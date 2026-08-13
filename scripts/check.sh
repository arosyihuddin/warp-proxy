#!/usr/bin/env bash
# Verifikasi egress IP tiap proxy WARP.
# Tiap pool harus keliatan IP Cloudflare WARP (bukan IP lo / bukan workers.dev).

set -euo pipefail

# ── load .env kalau ada ───────────────────────────────────────────────
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ENV_FILE"
  set +a
fi

HOST="${WARP_PROXY_HOST:-127.0.0.1}"
PORT_START="${WARP_PORT_START:-40001}"
COUNT="${WARP_INSTANCE_COUNT:-1}"

# Argumen opsional (konsisten dengan start.sh / down.sh):
#   make check           → cek semua (1..COUNT)
#   make check N         → cek instance 1..N
#   make check -i N      → cek instance ke-N saja
if [ "${1:-}" = "-i" ]; then
  START_I="${2:?butuh nomor instance, contoh: check -i 3}"
  END_I="$START_I"
elif [ -n "${1:-}" ]; then
  START_I=1
  END_I="${1}"
else
  START_I=1
  END_I="$COUNT"
fi

echo "Egress per instance WARP:"
echo ""
for i in $(seq "$START_I" "$END_I"); do
  port=$((PORT_START + i - 1))
  url="http://${HOST}:${port}"
  echo "── warp (${url}) ──"
  # curl via proxy → trace cloudflare
  curl -sx "$url" https://www.cloudflare.com/cdn-cgi/trace \
    | grep -E '^(warp|colo|ip|loc|asn|ts)=' \
    | sed 's/^/   /' || echo "   ✗ proxy gagal / nggak nyambung"
  # account type (Free / Premium) + license via warp-cli inside container
  cname="warp-proxy-${i}"
  if docker ps --format '{{.Names}}' | grep -q "^${cname}$"; then
    docker exec "${cname}" warp-cli --accept-tos registration show 2>/dev/null \
      | grep -E 'Account type|License' \
      | sed -e 's/Account type:/account type:/' -e 's/License:/license:/' \
      | sed 's/^/   /'
  else
    echo "   account type: ✗ container ${cname} nggak jalan"
  fi
  echo ""
done