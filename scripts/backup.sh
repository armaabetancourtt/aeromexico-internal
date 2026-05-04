#!/bin/bash
# =============================================================================
# backup.sh – Backup de base de datos y logs de Aeroméxico
# =============================================================================
# Uso:
#   ./backup.sh                → backup local
#   ./backup.sh --s3 mi-bucket → backup local + subir a S3
#
# Cron (ejecutar diariamente a las 2:00 AM):
#   0 2 * * * /ruta/al/proyecto/backup.sh >> /var/log/aeromex-backup.log 2>&1
#
# Cron con S3 (ejecutar cada 6 horas):
#   0 */6 * * * /ruta/al/proyecto/backup.sh --s3 mi-bucket-aeromex >> /var/log/aeromex-backup.log 2>&1
# =============================================================================

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backups"
DB_BACKUP_FILE="${BACKUP_DIR}/mongodb_backup_${TIMESTAMP}.gz"
LOGS_BACKUP_FILE="${BACKUP_DIR}/logs_backup_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   AeroMex – Backup ${TIMESTAMP}${NC}"
echo -e "${CYAN}============================================${NC}"

# ── 1. Backup de MongoDB ─────────────────────────────────────────────────────
echo -e "\n${YELLOW}[1/3] Realizando backup de MongoDB...${NC}"

if docker ps | grep -q vuelos-mongodb; then
    docker exec vuelos-mongodb mongodump \
        --db=vuelos \
        --archive \
        --gzip > "$DB_BACKUP_FILE"
    echo -e "${GREEN} Backup de BD guardado en: ${DB_BACKUP_FILE}${NC}"
else
    echo -e "${RED}  El contenedor vuelos-mongodb no está corriendo. Saltando backup de BD.${NC}"
fi

# ── 2. Backup de Logs ────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[2/3] Realizando backup de logs...${NC}"

echo -e "\n${YELLOW}[2/3] Realizando backup de logs...${NC}"

docker exec vuelos-backend sh -c "tar czf - /app/logs" > "$LOGS_BACKUP_FILE"

echo -e "${GREEN} Backup de logs guardado en: ${LOGS_BACKUP_FILE}${NC}"

# ── 3. Subir a S3 (opcional) ─────────────────────────────────────────────────
if [ "$1" = "--s3" ] && [ -n "$2" ]; then
    S3_BUCKET="$2"
    echo -e "\n${YELLOW}[3/3] Subiendo a S3: s3://${S3_BUCKET}/backups/...${NC}"

    if ! command -v aws &> /dev/null; then
        echo -e "${RED} AWS CLI no instalado. Instálalo con: pip install awscli${NC}"
        exit 1
    fi

    [ -f "$DB_BACKUP_FILE" ]   && aws s3 cp "$DB_BACKUP_FILE"   "s3://${S3_BUCKET}/backups/mongodb/" && echo "✅ BD subida a S3"
    [ -f "$LOGS_BACKUP_FILE" ] && aws s3 cp "$LOGS_BACKUP_FILE" "s3://${S3_BUCKET}/backups/logs/"   && echo "✅ Logs subidos a S3"
else
    echo -e "\n${YELLOW}[3/3] (S3 omitido — ejecuta con: ./backup.sh --s3 <nombre-bucket>)${NC}"
fi

# ── Limpieza de backups viejos (conservar últimos 7 días) ─────────────────────
echo -e "\n${YELLOW}Limpiando backups con más de 7 días...${NC}"
find "$BACKUP_DIR" -name "*.gz" -mtime +7 -delete
echo -e "${GREEN} Limpieza completada${NC}"

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}   Backup finalizado: ${TIMESTAMP}${NC}"
echo -e "${GREEN}============================================${NC}\n"
