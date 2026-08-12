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
└── check.sh             # verifikasi egress IP (harus warp=on)
```

## Bikin & run

```bash
# 1. konfig
cp .env.example .env
#   LICENSE bisa dikosongin (free tier).

docker compose up -d

# 2. verifikasi egress
./check.sh        # harus keliatan warp=on + IP Cloudflare WARP
```

Proxy tersedia di `http://127.0.0.1:40001`.

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
| `WARP_LICENSE_1` | kosong | Isi license WARP+ buat upgrade (prioritas) |
| `WARP_PROXY_HOST` | `127.0.0.1` | Host Docker tempat proxy bind |
| `WARP_PORT_START` | `40001` | Port host proxy |
| `WARP_INSTANCE_COUNT` | `1` | Jumlah container (belum dipakai compose — satu container sekarang) |

## Notes

- Rotasi manual: `make rotate` (docker exec warp-proxy warp-cli tunnel rotate-keys)
- Satu container WARP = satu IP stabil per akun.
