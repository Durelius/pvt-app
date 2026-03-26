#!/bin/bash

BASE_PORT=8080

cat > docker-compose.yml <<EOF
services:

  api-gateway:
    build: ./api-gateway
    container_name: api-gateway
    ports:
      - "${BASE_PORT}:${BASE_PORT}"
    volumes:
      - ./services:/services

EOF

for dir in ./services/*/; do
  name=$(basename "$dir")
  cat >> docker-compose.yml <<EOF
  $name:
    build: $dir
    container_name: $name

EOF
done
