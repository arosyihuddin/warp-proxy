.DEFAULT_GOAL := help

.PHONY: help start up check logs down restart clean rotate

help:
	@echo "WARP Proxy — Cloudflare WARP HTTP proxy"
	@echo ""
	@echo "Targets:"
	@echo "  make start     # default: up + check"
	@echo "  make up        # Start container"
	@echo "  make check     # Verify WARP egress IP"
	@echo "  make logs      # Tail logs"
	@echo "  make down      # Stop container"
	@echo "  make restart   # Restart everything"
	@echo "  make clean     # Full cleanup (stop + remove volumes/images)"
	@echo "  make rotate    # Rotate WARP tunnel keys (warp-cli tunnel rotate-keys)"

start: up check

up:
	docker compose up -d

check:
	./check.sh

logs:
	docker compose logs -f --tail 50

down:
	docker compose down

restart: down up

clean:
	docker compose down -v --rmi all --remove-orphans

rotate:
	docker exec -it warp-proxy warp-cli tunnel rotate-keys || echo "Rotate gagal. Pastikan container warp-proxy jalan."
	echo "WARP tunnel keys rotated (docker exec warp-proxy warp-cli tunnel rotate-keys)"