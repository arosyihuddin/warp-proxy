#!/bin/bash
# Patched entrypoint untuk zenexas/warp-cli.
# Image asli panggil `warp-cli set-license` yang gak ada di warp-cli modern
# (unrecognized subcommand) → license gak keapply. Di sini pakai
# `warp-cli registration license` biar WARP_LICENSE dari .env kebaca tiap start.

(
    if [ ! -f /var/lib/cloudflare-warp/reg.json ]; then
        while ! warp-cli --accept-tos registration new; do
            sleep 1
            >&2 echo "Awaiting warp-svc become online..."
        done
    fi

    if [ ! -z $LICENSE ]; then
        warp-cli --accept-tos registration license $LICENSE
    fi

    warp-cli --accept-tos mode proxy
    warp-cli --accept-tos proxy port 40001
    warp-cli --accept-tos connect

    # socat is used to redirect traffic from 40000 to 40001
    socat TCP-LISTEN:40000,fork TCP:localhost:40001
) &

exec warp-svc