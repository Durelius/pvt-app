.PHONY: up down build generate flutter flutter-dev ios android

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
	cd frontend && flutter pub run flutter_native_splash:create && flutter pub get && flutter run

flutter-dev:
	cd frontend && flutter pub run flutter_native_splash:create && flutter pub get && flutter run --dart-define=DEV=true

ios:
	cd frontend && flutter emulators --launch apple_ios_simulator

flutter-web:
	cd frontend && flutter run -d chrome --web-hostname localhost --web-port 58555

android:
	emulator -avd $(shell emulator -list-avds | head -1)
