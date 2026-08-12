#!/usr/bin/env bash
# Verifikasi egress IP tiap proxy WARP.
# Tiap pool harus keliatan IP Cloudflare WARP (bukan IP lo / bukan workers.dev).

set -euo pipefail

# ── load .env kalau ada ───────────────────────────────────────────────
if [ -f "$(dirname "$0")/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$(dirname "$0")/.env"
  set +a
fi

HOST="${WARP_PROXY_HOST:-127.0.0.1}"
PORT_START="${WARP_PORT_START:-40001}"
COUNT="${WARP_INSTANCE_COUNT:-1}"

echo "Egress per instance WARP:"
echo ""
for i in $(seq 1 "$COUNT"); do
  port=$((PORT_START + i - 1))
  url="http://${HOST}:${port}"
  echo "── warp (${url}) ──"
  # curl via proxy → trace cloudflare
  curl -sx "$url" https://www.cloudflare.com/cdn-cgi/trace \
    | grep -E '^(warp|colo|ip|loc|asn|ts)=' \
    | sed 's/^/   /' || echo "   ✗ proxy gagal / nggak nyambung"
  # account type (Free / Premium) + license via warp-cli inside container
  if docker ps --format '{{.Names}}' | grep -q '^warp-proxy$'; then
    docker exec warp-proxy warp-cli --accept-tos registration show 2>/dev/null \
      | grep -E 'Account type|License' \
      | sed -e 's/Account type:/account type:/' -e 's/License:/license:/' \
      | sed 's/^/   /'
  else
    echo "   account type: ✗ container warp-proxy nggak jalan"
  fi
  echo ""
done