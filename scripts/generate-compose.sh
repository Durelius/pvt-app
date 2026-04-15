#!/bin/bash

BASE_PORT=8080
NEXT_PORT=$((BASE_PORT + 1))

cat >docker-compose.yml <<EOF
services:
  api-gateway:
    build:
      context: .
      dockerfile: ./DockerGateway
    container_name: api-gateway
    ports:
      - "${BASE_PORT}:${BASE_PORT}"
    volumes:
      - .:/app
      - /app/bin
    env_file:
      - .env
    environment:
      - SERVICE_NAME=api-gateway
    depends_on:
      db:
        condition: service_healthy
EOF

cat >>docker-compose.yml <<EOF
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydb
    ports:
      - "5432:5432"
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5
EOF

for dir in ./backend/services/*/; do
  name=$(basename "$dir")

  cat >>docker-compose.yml <<EOF

  ${name}:
    build:
      context: .
      dockerfile: DockerService
      args:
        SERVICE_NAME: ${name}
    container_name: ${name}
    ports:
      - "${NEXT_PORT}:8080"
    volumes:
      - .:/app
      - /app/bin
    env_file:
      - .env
    environment:
      - SERVICE_NAME=${name}
    depends_on:
      db:
        condition: service_healthy
EOF

  NEXT_PORT=$((NEXT_PORT + 1))
done

cat >>docker-compose.yml <<EOF

volumes:
  db-data:
EOF
