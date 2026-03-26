.PHONY: up down build generate

BASE_PORT ?= 8080

generate:
	@echo "Generating docker-compose.yml..."
	@BASE_PORT=$(BASE_PORT) bash scripts/generate-compose.sh

up: generate
	docker compose up

down:
	docker compose down

build: generate
	docker compose up --build
