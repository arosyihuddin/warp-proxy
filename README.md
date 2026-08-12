# WARP Proxy — Cloudflare WARP HTTP proxy

Proxy Cloudflare WARP (warp-cli) di Docker, siap dipakai app apa pun sebagai
HTTP proxy dengan egress IP Cloudflare.

Kenapa WARP? Beberapa provider AI rate-limit IP **workers.dev** yang shared & flagged.
WARP pakai egress IP Cloudflare **per-user & bersih** → lolos rate limit.

## Struktur

```
warp-proxy/
├── docker-compose.yml   # 1x container WARP → port 40001 di host (http proxy)
├── .env.example         # LICENSE (kosong=free) + host/port proxy
├── Makefile             # shortcut perintah (up, check, logs, down, ...)
└── check.sh             # verifikasi egress IP (harus warp=on)
```

## Bikin & run

```bash
# 1. konfig
cp .env.example .env
#   LICENSE bisa dikosongin (free tier).

# 2. start (up + tunggu siap + check egress)
make start
```

Proxy tersedia di `http://127.0.0.1:40001`.

### Perintah Makefile

| Perintah | Fungsi |
|---|---|
| `make start` | up + tunggu siap + verifikasi (default) |
| `make up` | Start container |
| `make check` | Verifikasi egress IP WARP |
| `make logs` | Tail log container |
| `make down` | Stop container |
| `make restart` | Restart ulang |
| `make clean` | Cleanup total (stop + hapus volumes/images) |
| `make rotate` | Rotasi WARP tunnel keys |
| `make change-ip` | Hapus state WARP + up ulang → egress IP baru |

Tanpa Makefile, setara dengan `docker compose up -d` lalu `./check.sh`.

## Alur

Port host (`WARP_PORT_START`, default `40001`) dipetakan ke port **40000** di container.
Di dalam container, `socat` meneruskan `40000 → 40001`, tempat `warp-cli` mode proxy bind ke loopback.

## Pakai

### curl

```bash
curl -x http://127.0.0.1:40001 https://www.cloudflare.com/cdn-cgi/trace
```

### Aplikasi dengan env proxy

```bash
HTTP_PROXY=http://127.0.0.1:40001 \
HTTPS_PROXY=http://127.0.0.1:40001 \
nama-program
```

## Konfigurasi

| Var | Default | Fungsi |
|---|---|---|
| `WARP_LICENSE` | kosong | Isi license WARP+ buat upgrade (prioritas) |
| `WARP_PROXY_HOST` | `127.0.0.1` | Host Docker tempat proxy bind |
| `WARP_PORT_START` | `40001` | Port host proxy |
| `WARP_INSTANCE_COUNT` | `1` | Jumlah container (belum dipakai compose — satu container sekarang) |

## Notes

- Rotasi manual: `make rotate`
- Ganti IP: `make change-ip`
- Satu container WARP = satu IP stabil per akun.
