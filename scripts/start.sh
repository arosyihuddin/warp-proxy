#!/usr/bin/env bash
# Start instance WARP.
#
# Tiga mode:
#   make start          → start 1..COUNT SATU-SATU (berurutan + jeda, IP cenderung beda)
#   make start N        → start N instance LANGSUNG (1..N barengan)
#   make start -i N     → start instance ke-N SAJA
#
# Kenapa ada mode satu-satu? Kalau semua di-up bersamaan, akun WARP ke-register
# hampir barengan → sering dapet IP yang sama. Start berurutan + jeda bikin
# tiap instance register di waktu beda → kemungkinan IP beda jauh lebih besar.

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

# Print info lengkap satu instance — sama persis formatnya dengan check.sh.
show_info() {
  local n="$1"
  local p=$((PORT + n - 1))
  local url="http://${HOST}:${p}"

  echo "── warp (${url}) ──"
  curl -sx "$url" https://www.cloudflare.com/cdn-cgi/trace \
    | grep -E '^(warp|colo|ip|loc|asn|ts)=' \
    | sed 's/^/   /' || echo "   ✗ proxy gagal / nggak nyambung"

  local cname="warp-proxy-${n}"
  if docker ps --format '{{.Names}}' | grep -q "^${cname}$"; then
    docker exec "${cname}" warp-cli --accept-tos registration show 2>/dev/null \
      | grep -E 'Account type|License' \
      | sed -e 's/Account type:/account type:/' -e 's/License:/license:/' \
      | sed 's/^/   /'
  else
    echo "   account type: ✗ container ${cname} nggak jalan"
  fi
}

# Tunggu satu instance siap (return 0 kalau siap, 1 kalau timeout).
wait_ready() {
  local n="$1"
  local p=$((PORT + n - 1))
  for _ in $(seq 1 60); do
    if curl -sx "http://${HOST}:${p}" https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -q '^warp=on'; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# Start satu instance, tunggu, tampilkan info.
start_one() {
  local n="$1"
  local p=$((PORT + n - 1))

  echo "▶ Start instance ${n} (port ${p})..."
  docker compose up -d "warp-${n}" >/dev/null 2>&1

  if wait_ready "$n"; then
    echo "  ✓ instance ${n} siap."
    echo ""
    show_info "$n"
    echo ""
    return 0
  fi

  echo "  ✗ instance ${n} belum siap (timeout 60s)."
  return 1
}

# Start N instance sekaligus (barengan), tunggu semua, tampilkan info.
start_batch() {
  local n="$1"
  local jobs="warp-1"
  local i
  for i in $(seq 2 "$n"); do jobs="$jobs warp-$i"; done

  echo "▶ Start ${n} instance langsung (${jobs})..."
  docker compose up -d $jobs >/dev/null 2>&1

  local ok=0
  for i in $(seq 1 "$n"); do
    if wait_ready "$i"; then
      echo "  ✓ instance ${i} siap."
      ok=$((ok + 1))
    else
      echo "  ✗ instance ${i} belum siap (timeout 60s)."
    fi
  done

  echo ""
  for i in $(seq 1 "$n"); do
    show_info "$i"
    echo ""
  done

  [ "$ok" -eq "$n" ]
}

# ── parse argumen ───────────────────────────────────────────────────────
if [ "${1:-}" = "-i" ]; then
  # single: instance ke-N saja
  start_one "${2:?butuh nomor instance, contoh: start -i 3}"
elif [ -n "${1:-}" ]; then
  # batch: N instance langsung
  start_batch "$1"
else
  # satu-satu: 1..COUNT berurutan
  for n in $(seq 1 "$COUNT"); do
    start_one "$n"
    sleep 2
  done
  echo "✓ Selesai. Cek IP: make check"
fi
