#!/usr/bin/env bash
set -euo pipefail

echo "[AEROOPS] Admin API logs"
docker compose logs --tail=50 admin-backend
