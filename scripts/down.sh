#!/usr/bin/env bash
# Stop instance WARP (copot device dari akun license dulu, biar slot nggak numpuk).
#
# Tiga mode:
#   make down           → down semua instance (1..COUNT)
#   make down N         → down N instance (1..N)
#   make down -i N      → down instance ke-N saja

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

# Copot device dari akun license + stop satu container.
down_one() {
  local n="$1"
  local cname="warp-proxy-${n}"

  if docker ps --format '{{.Names}}' | grep -q "^${cname}$"; then
    if docker exec "$cname" warp-cli --accept-tos registration delete >/dev/null 2>&1; then
      echo "  ✓ ${cname} device dicopot."
    else
      echo "  ✗ ${cname} gagal copot / nggak jalan — lanjut."
    fi
  fi

  docker compose stop "warp-${n}" >/dev/null 2>&1 || true
  echo "  ⏹ ${cname} di-stop."
}

# ── parse argumen ───────────────────────────────────────────────────────
if [ "${1:-}" = "-i" ]; then
  echo "Mencopot device WARP dari akun license + stop instance ${2:?butuh nomor instance}:"
  down_one "${2:?butuh nomor instance, contoh: down -i 3}"
elif [ -n "${1:-}" ]; then
  N="${1}"
  echo "Mencopot device WARP dari akun license + stop instance 1..${N}:"
  for n in $(seq 1 "$N"); do down_one "$n"; done
else
  echo "Mencopot device WARP dari akun license + stop semua instance (1..${COUNT}):"
  for n in $(seq 1 "$COUNT"); do down_one "$n"; done
fi
