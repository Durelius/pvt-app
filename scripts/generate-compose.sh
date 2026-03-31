#!/bin/bash

BASE_PORT=8080
NEXT_PORT=$((BASE_PORT + 1))

cat > docker-compose.yml <<EOF
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
    environment:
      - SERVICE_NAME=api-gateway
EOF

for dir in ./services/*/; do
  name=$(basename "$dir")

  cat >> docker-compose.yml <<EOF

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
    environment:
      - SERVICE_NAME=${name}
EOF

  NEXT_PORT=$((NEXT_PORT + 1))
done
