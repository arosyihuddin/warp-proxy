.DEFAULT_GOAL := help

.PHONY: help start up wait check logs down detach restart clean rotate change-ip down-v

help:
	@echo "WARP Proxy — Cloudflare WARP HTTP proxy"
	@echo ""
	@echo "Targets:"
	@echo "  make start     # default: up + check"
	@echo "  make up        # Start container"
	@echo "  make check     # Verify WARP egress IP"
	@echo "  make logs      # Tail logs"
	@echo "  make down      # Copot device dari akun license + stop container"
	@echo "  make restart   # Restart everything"
	@echo "  make clean     # Full cleanup (stop + remove volumes/images)"
	@echo "  make rotate    # Rotate WARP tunnel keys (warp-cli tunnel rotate-keys)"
	@echo "  make change-ip # Copot device + hapus state WARP + up ulang → egress IP baru"

start: up wait check

change-ip: detach down-v up wait check

up:
	docker compose up -d

wait:
	@echo "Menunggu proxy WARP siap..."
	@if [ -f .env ]; then set -a; . ./.env; set +a; fi; \
	HOST="$${WARP_PROXY_HOST:-127.0.0.1}"; PORT="$${WARP_PORT_START:-40001}"; \
	for i in $$(seq 1 30); do \
		if curl -sx "http://$${HOST}:$${PORT}" https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -q '^warp=on'; then \
			echo "Proxy siap."; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "✗ Proxy tidak siap dalam 30s."; \
	exit 1

check:
	./check.sh

logs:
	docker compose logs -f --tail 50

down: detach
	docker compose down

down-v:
	docker compose down -v

# Copot device dari akun license → slot nggak numpuk tiap down/restart.
detach:
	@echo "Mencopot device WARP dari akun license..."
	@if docker exec warp-proxy warp-cli --accept-tos registration delete >/dev/null 2>&1; then \
		echo "✓ Device dicopot."; \
	else \
		echo "✗ Container warp-proxy gak jalan / gagal copot — lanjut."; \
	fi

restart: down up

clean: detach
	docker compose down -v --rmi all --remove-orphans

rotate:
	docker exec -it warp-proxy warp-cli tunnel rotate-keys || echo "Rotate gagal. Pastikan container warp-proxy jalan."
	echo "WARP tunnel keys rotated (docker exec warp-proxy warp-cli tunnel rotate-keys)"