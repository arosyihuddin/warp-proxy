.DEFAULT_GOAL := help

SCRIPTS = scripts

.PHONY: help start start-i check check-i down down-i rotate rotate-i change-ip change-ip-i test status status-i logs restart restart-i clean

# Catch-all biar `make start 3` / `make check 3` nggak error "No rule to make target '3'".
# Argumen di MAKECMDGOALS diambil lewat $(word 2,$(MAKECMDGOALS)) di tiap target.
%:
	@true

help:
	@echo "WARP Proxy — Cloudflare WARP HTTP proxy"
	@echo ""
	@echo "Semua command punya 3 mode: tanpa angka = semua, N = 1..N, -i N = instance ke-N"
	@echo ""
	@echo "  make start [N]     # start; tanpa angka = satu-satu (IP beda-beda), N = N langsung"
	@echo "  make start-i N     # start instance ke-N saja"
	@echo "  make check [N]     # verify egress IP (semua / 1..N)"
	@echo "  make check-i N     # verify egress IP instance ke-N saja"
	@echo "  make down [N]      # copot device + stop (semua / 1..N)"
	@echo "  make down-i N      # copot device + stop instance ke-N saja"
	@echo "  make rotate [N]    # rotate WARP tunnel keys (semua / 1..N)"
	@echo "  make rotate-i N    # rotate keys instance ke-N saja"
	@echo "  make change-ip [N] # rotate egress IP (semua / 1..N)"
	@echo "  make change-ip-i N # rotate egress IP instance ke-N saja"
	@echo "  make test [N]      # test tembak OpenCode API (semua / 1..N)"
	@echo "  make test-i N      # test tembak OpenCode API instance ke-N saja"
	@echo "  make status [N]    # status container jalan/stop + IP egress (semua / 1..N)"
	@echo "  make status-i N    # status instance ke-N saja"
	@echo "  make logs          # tail logs semua container"
	@echo "  make restart [N]   # down lalu start (semua / 1..N)"
	@echo "  make restart-i N   # restart instance ke-N saja"
	@echo "  make clean         # full cleanup (semua volume + images)"

# `make start 3` → start 3 instance langsung. `make start` → satu-satu (1..COUNT, IP beda).
start:
	./$(SCRIPTS)/start.sh $(word 2,$(MAKECMDGOALS))

start-i:
	./$(SCRIPTS)/start.sh -i $(word 2,$(MAKECMDGOALS))

check:
	./$(SCRIPTS)/check.sh $(word 2,$(MAKECMDGOALS))

check-i:
	./$(SCRIPTS)/check.sh -i $(word 2,$(MAKECMDGOALS))

down:
	./$(SCRIPTS)/down.sh $(word 2,$(MAKECMDGOALS))

down-i:
	./$(SCRIPTS)/down.sh -i $(word 2,$(MAKECMDGOALS))

rotate:
	./$(SCRIPTS)/rotate.sh $(word 2,$(MAKECMDGOALS))

rotate-i:
	./$(SCRIPTS)/rotate.sh -i $(word 2,$(MAKECMDGOALS))

change-ip:
	./$(SCRIPTS)/change-ip.sh $(word 2,$(MAKECMDGOALS))

change-ip-i:
	./$(SCRIPTS)/change-ip.sh -i $(word 2,$(MAKECMDGOALS))

# Test tembak ke OpenCode API lewat proxy WARP.
test:
	./$(SCRIPTS)/test-opencode.sh $(word 2,$(MAKECMDGOALS))

test-i:
	./$(SCRIPTS)/test-opencode.sh -i $(word 2,$(MAKECMDGOALS))

status:
	./$(SCRIPTS)/status.sh $(word 2,$(MAKECMDGOALS))

status-i:
	./$(SCRIPTS)/status.sh -i $(word 2,$(MAKECMDGOALS))

logs:
	docker compose logs -f --tail 50

# `make restart 3` → down 3 lalu start 3. `make restart-i 3` → restart instance 3 aja.
# Tanpa argumen → down semua + start satu-satu.
restart: down
	./$(SCRIPTS)/start.sh $(word 2,$(MAKECMDGOALS))

restart-i: down-i
	./$(SCRIPTS)/start.sh -i $(word 2,$(MAKECMDGOALS))

# Full cleanup — selalu hapus SEMUA (volume + images). Nggak bisa per-instance.
clean:
	./$(SCRIPTS)/down.sh >/dev/null 2>&1 || true
	docker compose down -v --rmi all --remove-orphans
