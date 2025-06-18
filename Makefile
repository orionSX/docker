.PHONY: help build test dev prod clean lint format

# Цвета для вывода
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

# Переменные
IMAGE_NAME = kubsu/python-crud
COMPOSE_FILE = docker-compose.yml

help: ## Показать справку
	@echo "$(BLUE)Доступные команды:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

build: ## Собрать Docker образ
	@echo "$(GREEN)Сборка Docker образа...$(NC)"
	docker build -t $(IMAGE_NAME):latest .

test: ## Запустить тесты
	@echo "$(GREEN)Запуск тестов...$(NC)"
	docker-compose --profile test up -d db
	@sleep 5
	docker run --rm --network host \
		-e DATABASE_URL="postgresql+psycopg://kubsu:kubsu@localhost:5432/kubsu" \
		-e PYTHONPATH=/app \
		$(IMAGE_NAME):latest \
		python -m pytest -v tests/
	docker-compose --profile test down

test-compose: ## Запустить тесты через docker-compose
	@echo "$(GREEN)Запуск тестов через docker-compose...$(NC)"
	docker-compose --profile test up --build --exit-code-from test
	docker-compose --profile test down -v

dev: ## Запустить в режиме разработки
	@echo "$(GREEN)Запуск в режиме разработки...$(NC)"
	docker-compose --profile dev up --build

dev-detached: ## Запустить в режиме разработки в фоне
	@echo "$(GREEN)Запуск в режиме разработки (фон)...$(NC)"
	docker-compose --profile dev up --build -d

prod: ## Запустить в продакшен режиме
	@echo "$(GREEN)Запуск в продакшен режиме...$(NC)"
	docker-compose --profile prod up --build -d

stop: ## Остановить все сервисы
	@echo "$(YELLOW)Остановка сервисов...$(NC)"
	docker-compose --profile dev --profile prod --profile test down

clean: ## Очистить Docker ресурсы
	@echo "$(RED)Очистка Docker ресурсов...$(NC)"
	docker-compose --profile dev --profile prod --profile test down -v --remove-orphans
	docker system prune -f
	docker volume prune -f

logs: ## Показать логи приложения
	docker-compose logs -f app

logs-db: ## Показать логи базы данных
	docker-compose logs -f db

shell: ## Подключиться к контейнеру приложения
	docker-compose --profile dev exec app bash

shell-db: ## Подключиться к базе данных
	docker-compose --profile dev exec db psql -U kubsu -d kubsu

lint: ## Проверить код линтером
	@echo "$(GREEN)Проверка кода...$(NC)"
	docker run --rm -v $(PWD):/app -w /app $(IMAGE_NAME):latest \
		python -m flake8 src/ tests/

format: ## Форматировать код
	@echo "$(GREEN)Форматирование кода...$(NC)"
	docker run --rm -v $(PWD):/app -w /app $(IMAGE_NAME):latest \
		python -m black src/ tests/

security: ## Проверка безопасности
	@echo "$(GREEN)Проверка безопасности...$(NC)"
	docker run --rm -v $(PWD):/app -w /app $(IMAGE_NAME):latest \
		python -m bandit -r src/

health: ## Проверить здоровье приложения
	@curl -f http://localhost:8022/health || echo "$(RED)Приложение недоступно$(NC)"

backup-db: ## Создать бэкап базы данных
	@echo "$(GREEN)Создание бэкапа базы данных...$(NC)"
	docker-compose --profile dev exec db pg_dump -U kubsu -d kubsu > backup_$(shell date +%Y%m%d_%H%M%S).sql

restore-db: ## Восстановить базу данных из бэкапа (использовать: make restore-db BACKUP=filename.sql)
	@echo "$(GREEN)Восстановление базы данных...$(NC)"
	@if [ -z "$(BACKUP)" ]; then echo "$(RED)Укажите файл бэкапа: make restore-db BACKUP=filename.sql$(NC)"; exit 1; fi
	docker-compose --profile dev exec -T db psql -U kubsu -d kubsu < $(BACKUP)

deploy-local: ## Деплой локально (имитация продакшена)
	@echo "$(GREEN)Локальный деплой...$(NC)"
	$(MAKE) build
	docker tag $(IMAGE_NAME):latest $(IMAGE_NAME):deploy
	docker run -d --name python-crud-local --network host $(IMAGE_NAME):deploy

undeploy-local: ## Удалить локальный деплой
	@echo "$(YELLOW)Удаление локального деплоя...$(NC)"
	docker stop python-crud-local || true
	docker rm python-crud-local || true 
