#!/bin/bash

cat >docker-compose.prod.yml <<EOF
services:
  api-gateway:
    build:
      context: .
      dockerfile: DockerGateway.prod
    container_name: api-gateway
    ports:
      - "8080:8080"
    env_file:
      - .env
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydb
    volumes:
      - db-data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5
EOF

for dir in ./backend/services/*/; do
  [ -f "$dir/app/main.go" ] || continue
  name=$(basename "$dir")

  cat >>docker-compose.prod.yml <<EOF

  ${name}:
    build:
      context: .
      dockerfile: DockerService.prod
      args:
        SERVICE_NAME: ${name}
    container_name: ${name}
    env_file:
      - .env
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
EOF
done

cat >>docker-compose.prod.yml <<EOF

volumes:
  db-data:
EOF
