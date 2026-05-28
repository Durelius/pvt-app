#!/bin/bash

# When IMAGE_PREFIX is set, uses pre-built images from the registry.
# When not set, falls back to building locally from prod Dockerfiles.
IMAGE_PREFIX="${IMAGE_PREFIX:-}"

cat > docker-compose.prod.yml << EOF
services:
  api-gateway:
EOF

if [ -n "$IMAGE_PREFIX" ]; then
  cat >> docker-compose.prod.yml << EOF
    image: ${IMAGE_PREFIX}/pvt-api-gateway:latest
EOF
else
  cat >> docker-compose.prod.yml << EOF
    build:
      context: .
      dockerfile: DockerGateway.prod
EOF
fi

cat >> docker-compose.prod.yml << EOF
    container_name: api-gateway
    ports:
      - "8080:8080"
    env_file:
      - .env
    restart: "no"
    mem_limit: 96m
    depends_on:
      db:
        condition: service_healthy

  db:
EOF

if [ -n "$IMAGE_PREFIX" ]; then
  cat >> docker-compose.prod.yml << EOF
    image: ${IMAGE_PREFIX}/pvt-postgres:16
EOF
else
  cat >> docker-compose.prod.yml << EOF
    image: postgres:16
EOF
fi

cat >> docker-compose.prod.yml << EOF
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydb
    volumes:
      - db-data:/var/lib/postgresql/data
    restart: "no"
    mem_limit: 128m
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5
EOF

for dir in ./backend/services/*/; do
  [ -f "$dir/app/main.go" ] || continue
  name=$(basename "$dir")

  cat >> docker-compose.prod.yml << EOF

  ${name}:
EOF

  # Services with their own assets get a dedicated Dockerfile
  if [ "$name" = "middle" ]; then
    dockerfile="DockerMiddle.prod"
  else
    dockerfile="DockerService.prod"
  fi

  if [ -n "$IMAGE_PREFIX" ]; then
    cat >> docker-compose.prod.yml << EOF
    image: ${IMAGE_PREFIX}/pvt-${name}:latest
EOF
  else
    cat >> docker-compose.prod.yml << EOF
    build:
      context: .
      dockerfile: ${dockerfile}
      args:
        SERVICE_NAME: ${name}
EOF
  fi

  mem_limit="96m"
  [ "$name" = "middle" ] && mem_limit="320m"

  cat >> docker-compose.prod.yml << EOF
    container_name: ${name}
    environment:
      - SERVICE_NAME=${name}
EOF

  if [ "$name" = "middle" ]; then
    cat >> docker-compose.prod.yml << EOF
      - GOMEMLIMIT=280MiB
EOF
  fi

  cat >> docker-compose.prod.yml << EOF
    env_file:
      - .env
    restart: "no"
    mem_limit: ${mem_limit}
    depends_on:
      db:
        condition: service_healthy
EOF
done

cat >> docker-compose.prod.yml << EOF

volumes:
  db-data:
EOF
