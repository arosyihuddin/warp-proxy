# WARP Proxy — Cloudflare WARP HTTP proxy

Proxy Cloudflare WARP (warp-cli) di Docker, siap dipakai app apa pun sebagai
HTTP proxy dengan egress IP Cloudflare.

Kenapa WARP? Beberapa provider AI rate-limit IP **workers.dev** yang shared & flagged.
WARP pakai egress IP Cloudflare **per-user & bersih** → lolos rate limit.

## Struktur

```
warp-proxy/
├── docker-compose.yml   # 6x container WARP → port 40001..40006 di host (http proxy)
├── .env.example         # LICENSE (kosong=free) + host/port proxy + jumlah instance
├── Makefile             # shortcut perintah (start, check, down, rotate, change-ip, ...)
└── scripts/
    ├── entrypoint.sh        # patched entrypoint (image panggil set-license yang gak ada)
    ├── start.sh             # start instance (satu-satu / batch / per-instance)
    ├── check.sh             # verifikasi egress IP + account type (harus warp=on)
    ├── down.sh              # copot device + stop (semua / batch / per-instance)
    ├── rotate.sh            # rotate WARP tunnel keys
    ├── change-ip.sh         # rotate egress IP (hapus volume reg → akun baru)
    ├── test-opencode.sh     # test tembak OpenCode API lewat proxy WARP
    └── status.sh            # status container jalan/stop + IP egress
```

## Bikin & run

```bash
# 1. konfig
cp .env.example .env
#   LICENSE bisa dikosongin (free tier).
#   WARP_INSTANCE_COUNT = jumlah instance yang mau di-start default.

# 2. start (up + tunggu siap + check egress)
make start
```

Proxy tersedia di `http://127.0.0.1:40001` (dst per instance).

### Konvensi argumen

Semua command punya **3 mode**:

| Pola | Arti |
|---|---|
| `make <cmd>` | semua instance (1..COUNT) |
| `make <cmd> N` | instance 1..N |
| `make <cmd>-i N` | instance ke-N saja |

Khusus `start`: tanpa angka = start **satu-satu** (berurutan + jeda, biar egress IP
tiap instance cenderung beda-beda). `make start N` = start N instance langsung.

### Perintah Makefile

| Perintah | Fungsi |
|---|---|
| `make start [N]` | start semua satu-satu (IP beda) / N langsung / `-i N` lewat `make start-i N` |
| `make check [N]` | Verifikasi egress IP WARP (semua / 1..N) |
| `make check-i N` | Verifikasi egress IP instance ke-N |
| `make down [N]` | Copot device dari akun license + stop (semua / 1..N) |
| `make down-i N` | Copot device + stop instance ke-N |
| `make rotate [N]` | Rotasi WARP tunnel keys |
| `make rotate-i N` | Rotasi keys instance ke-N |
| `make change-ip [N]` | Rotate egress IP (hapus volume → akun baru) |
| `make change-ip-i N` | Rotate egress IP instance ke-N |
| `make test [N]` | Test tembak OpenCode API lewat proxy WARP (semua / 1..N) |
| `make test-i N` | Test tembak OpenCode API instance ke-N |
| `make status [N]` | Status container jalan/stop + IP egress (semua / 1..N) |
| `make status-i N` | Status instance ke-N |
| `make logs` | Tail log container |
| `make restart [N]` | Down lalu start (semua / 1..N / `restart-i N`) |
| `make clean` | Cleanup total (stop + hapus volumes/images) |

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
| `WARP_PORT_START` | `40001` | Port host proxy (instance ke-N = port start + N - 1) |
| `WARP_INSTANCE_COUNT` | `1` | Jumlah container default buat `start` / `down` / `check` tanpa argumen |
| `OPENCODE_API_KEY` | kosong | API key OpenCode (dipakai `make test`; free model bisa kosong) |
| `OPENCODE_ENDPOINT` | `https://opencode.ai/zen/v1/chat/completions` | Endpoint OpenCode (dipakai `make test`) |

## Notes

- Rotasi manual: `make rotate`
- Ganti IP: `make change-ip` (hapus volume `warp-reg-N` → akun baru → IP baru)
- Satu container WARP = satu IP stabil per akun.
- Start satu-satu (`make start`) bikin tiap instance register akun di waktu beda
  → egress IP lebih mungkin beda-beda. Nggak dijamin 100% beda, tapi jauh lebih
  kecil kemungkinan IP kembar dibanding start barengan.
