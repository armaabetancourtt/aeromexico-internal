#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backups"
DB_FILE="${BACKUP_DIR}/mongodb_${TIMESTAMP}.archive.gz"
LOG_FILE="${BACKUP_DIR}/admin_logs_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "[AEROOPS] Backing up MongoDB..."
docker compose exec -T mongodb mongodump   --db="${MONGO_INITDB_DATABASE:-vuelos}"   --archive   --gzip > "$DB_FILE"

echo "[AEROOPS] Archiving admin logs..."
docker compose exec -T admin-backend sh -c "tar czf - -C /app/logs ." > "$LOG_FILE"

echo "Saved:"
echo "  $DB_FILE"
echo "  $LOG_FILE"

if [ "${1:-}" = "--s3" ] && [ -n "${2:-}" ]; then
  if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI is required for S3 upload."
    exit 1
  fi

  aws s3 cp "$DB_FILE" "s3://$2/backups/mongodb/"
  aws s3 cp "$LOG_FILE" "s3://$2/backups/admin-logs/"
  echo "Uploaded backup artifacts to s3://$2/backups/"
fi

find "$BACKUP_DIR" -type f \( -name "*.gz" -o -name "*.tar.gz" \) -mtime +7 -delete
