#!/usr/bin/env bash
set -euo pipefail

echo "[AEROOPS] Starting internal operations and data plane..."

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.example to .env and configure the required secrets."
  exit 1
fi

docker compose up -d --build

echo
docker compose ps
echo
echo "Admin UI: http://localhost:${ADMIN_PORT:-8090}"
