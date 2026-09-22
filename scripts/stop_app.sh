#!/usr/bin/env bash
set -euo pipefail

echo "[AEROOPS] Stopping internal operations and data plane..."
docker compose down
