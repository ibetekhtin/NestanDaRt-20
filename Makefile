.PHONY: up down logs restart backend check deploy status ship clean

up:                ## запустить все контейнеры
	docker compose up -d

down:              ## остановить все контейнеры
	docker compose down

logs:              ## логи всех контейнеров
	docker compose logs -f

restart:           ## перезапустить все контейнеры
	docker compose restart

backend:           ## backend локально (для разработки)
	cd app/backend && uvicorn main:app --reload --port 8000

check:             ## синтаксис Python
	@echo "Checking Python syntax..."
	@find app/ providers/ -name "*.py" -exec python3 -m py_compile {} \; && echo "OK"

deploy:            ## деплой на VPS через deploy.sh
	bash deploy/deploy.sh

status:            ## GitHub ↔ VPS ↔ локаль + статус контейнеров
	@bash scripts/status.sh

ship:              ## push main → VPS → пересборка backend (с подтверждением)
	@bash scripts/ship.sh

clean:             ## очистить docker мусор
	docker system prune -f
	docker image prune -f
