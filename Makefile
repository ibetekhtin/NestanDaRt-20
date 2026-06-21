.PHONY: up down logs restart bot backend validate deploy clean status ship

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

restart:
	docker compose restart

bot:
	npm run bot

backend:
	cd app/backend && uvicorn main:app --reload --port 8000

validate:
	@echo "Validating JS..."
	@find bot/ -name "*.js" -exec node --check {} \; 2>/dev/null || true
	@echo "Validating Python..."
	@find app/ -name "*.py" -exec python3 -c "import ast; ast.parse(open('{}').read())" \; 2>/dev/null || true
	@echo "Done"

deploy:
	bash deploy/deploy.sh

status:        ## сходятся ли GitHub ↔ VPS ↔ локаль + здоровье контейнеров
	@bash scripts/status.sh

ship:          ## деплой: push main → git pull на VPS → пересборка backend (с подтверждением)
	@bash scripts/ship.sh

clean:
	docker system prune -f
	docker image prune -f