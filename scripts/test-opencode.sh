#!/usr/bin/env bash
# Test tembak ke OpenCode API dengan proxy WARP dari host (lebih stabil).

set -euo pipefail
cd "$(dirname "$0")/.."   # root proyek (tempat .env)

# Load .env
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

API_KEY="${OPENCODE_API_KEY:-}"
HOST="127.0.0.1"
PORT_START="${WARP_PORT_START:-40001}"
ENDPOINT="${OPENCODE_ENDPOINT:-https://opencode.ai/zen/v1/chat/completions}"

# Argumen opsional (konsisten dengan script lain):
#   make test        → test semua instance (1..COUNT)
#   make test N      → test instance 1..N
#   make test -i N   → test instance ke-N saja
if [ "${1:-}" = "-i" ]; then
  START_I="${2:?butuh nomor instance, contoh: test -i 3}"
  END_I="$START_I"
elif [ -n "${1:-}" ]; then
  START_I=1
  END_I="${1}"
else
  START_I=1
  END_I="${WARP_INSTANCE_COUNT:-6}"
fi

echo "=== Test proxy WARP ke OpenCode API dari host ==="
echo "Endpoint: ${ENDPOINT}"
echo "Model: deepseek-v4-flash-free"
echo "Timeout: 15 detik per request"
echo "Apikey: ${API_KEY:0:8}... (dari .env)"
echo ""

for i in $(seq "$START_I" "$END_I"); do
  p=$((PORT_START + i - 1))
  # Ambil IP egress beneran dari proxy (bukan grep isi source check.sh)
  ip=$(curl -sx "http://${HOST}:${p}" https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | awk -F= '/^ip=/{print $2}')
  ip="${ip:-?}"

  echo "=== Instance ${i} (port ${p}) ==="
  echo "Proxy IP: ${ip}"

  # Test ke OpenCode API dari host (free model nggak butuh Authorization header,
  # tapi dikirim kalau API_KEY ada di .env)
  auth_hdr=()
  [ -n "$API_KEY" ] && auth_hdr=(-H "Authorization: Bearer ${API_KEY}")
  start=$(date +%s%N)
  response=$(curl -s -x "http://${HOST}:${p}" -m 15 \
    -H "Content-Type: application/json" \
    "${auth_hdr[@]}" \
    -d '{"model":"deepseek-v4-flash-free","messages":[{"role":"user","content":"Hello, test proxy"}]}' \
    "$ENDPOINT" 2>&1)

  status=$?
  end=$(date +%s%N)
  duration=$(( (end - start) / 1000000 ))  # ms

  # curl exit 0 tapi response berupa JSON error → tetap dianggap gagal
  if [ $status -eq 0 ] && echo "$response" | grep -q '"error"'; then
    echo "  ✗ API error (${duration}ms)"
    echo "  ${response}"
  elif [ $status -eq 0 ]; then
    size=$(echo "$response" | wc -c)
    echo "  ✓ Sukses (${duration}ms) | Response size: ${size} bytes"
    echo "  Response:"
    echo "$response" | head -c 500
    echo ""
  else
    echo "  ✗ Gagal (${duration}ms) | Status: $status"
    echo "  Error: ${response}"
  fi
  echo ""
done

echo "=== Selesai ==="
