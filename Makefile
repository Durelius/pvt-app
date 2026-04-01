.PHONY: up down build generate flutter ios android

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

flutter:
	cd frontend && dart run flutter_native_splash:create && flutter run

ios:
	cd frontend && flutter emulators --launch apple_ios_simulator

android:
	emulator -avd $(shell emulator -list-avds | head -1)
