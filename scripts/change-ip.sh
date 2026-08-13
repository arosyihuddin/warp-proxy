#!/usr/bin/env bash
# Rotate egress IP tiap instance WARP.
#
# Tiap instance punya named volume warp-reg-N berisi reg.json (device + akun
# Cloudflare). Egress IP nempel ke akun → buat dapet IP baru: hapus reg + volume,
# up ulang → instance re-register akun baru (IP beda, kemungkinan besar).
#
# Kenapa hapus volume, bukan cuma registration delete? Registration delete
# nggak selalu ngehapus reg.json (bisa konflik sama volume yang persist).
# Hapus volume = jamin instance mulai kosong → akun baru.
#
# Tiga mode:
#   make change-ip        → semua instance (1..COUNT)
#   make change-ip N      → instance 1..N
#   make change-ip -i N   → instance ke-N saja

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

# Rotate satu instance: stop → hapus volume reg (reset akun) → up → tunggu → IP.
change_ip_one() {
  local n="$1"
  local p=$((PORT + n - 1))
  local vol="warp-proxy_warp-reg-${n}"

  echo "── instance ${n} (:${p}) ──"
  echo "  stop + hapus volume ${vol} (reset akun)..."
  docker compose stop "warp-${n}" >/dev/null 2>&1 || true
  docker volume rm "$vol" >/dev/null 2>&1 || true

  echo "  start ulang..."
  docker compose up -d "warp-${n}" >/dev/null 2>&1

  local ok=0
  for i in $(seq 1 30); do
    if curl -sx "http://${HOST}:${p}" https://www.cloudflare.com/cdn-cgi/trace \
      2>/dev/null | grep -q '^warp=on'; then
      ok=1
      break
    fi
    sleep 1
  done

  if [ "$ok" -eq 1 ]; then
    local ip
    ip=$(curl -sx "http://${HOST}:${p}" https://www.cloudflare.com/cdn-cgi/trace \
      2>/dev/null | awk -F= '/^ip=/{print $2}')
    echo "  ✓ instance ${n} (:${p}) → ${ip:-?}"
    return 0
  fi
  echo "  ✗ instance ${n} (:${p}) → gagal"
  return 1
}

# ── parse argumen ───────────────────────────────────────────────────────
if [ "${1:-}" = "-i" ]; then
  echo "Rotate egress IP instance ${2:?butuh nomor instance, contoh: change-ip -i 3}:"
  change_ip_one "$2"
elif [ -n "${1:-}" ]; then
  N="${1}"
  echo "Rotate egress IP instance 1..${N}:"
  ok=0
  for n in $(seq 1 "$N"); do change_ip_one "$n" && ok=$((ok + 1)); done
  echo ""
  echo "✓ ${ok}/${N} instance dapat IP baru."
  [ "$ok" -eq "$N" ]
else
  echo "Rotate egress IP semua instance (1..${COUNT}):"
  ok=0
  for n in $(seq 1 "$COUNT"); do change_ip_one "$n" && ok=$((ok + 1)); done
  echo ""
  echo "✓ ${ok}/${COUNT} instance dapat IP baru."
  [ "$ok" -eq "$COUNT" ]
fi
