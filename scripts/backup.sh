#!/bin/bash
# =============================================================================
# backup.sh – Backup de base de datos y logs de Aeroméxico
# =============================================================================
# Uso:
#   ./backup.sh
#   ./backup.sh --s3 mi-bucket
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

LOGS_VOLUME_PATH="/var/lib/docker/volumes/priv-profinaldevops_admin_logs/_data"

mkdir -p "$BACKUP_DIR"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   AeroMex – Backup ${TIMESTAMP}${NC}"
echo -e "${CYAN}============================================${NC}"

# ── 1. Backup de MongoDB ─────────────────────────────────────
echo -e "\n${YELLOW}[1/3] Realizando backup de MongoDB...${NC}"

if docker ps --format '{{.Names}}' | grep -q "^mongodb-vuelos$"; then
    
    docker exec mongodb-vuelos mongodump \
        --archive \
        --gzip > "$DB_BACKUP_FILE"

    echo -e "${GREEN} Backup MongoDB guardado en:${NC} $DB_BACKUP_FILE"

else
    echo -e "${RED} El contenedor mongodb-vuelos no está corriendo.${NC}"
fi

# ── 2. Backup de Logs ────────────────────────────────────────
echo -e "\n${YELLOW}[2/3] Realizando backup de logs...${NC}"

if [ -d "$LOGS_VOLUME_PATH" ]; then
    
    sudo tar -czf "$LOGS_BACKUP_FILE" "$LOGS_VOLUME_PATH"

    echo -e "${GREEN} Backup de logs guardado en:${NC} $LOGS_BACKUP_FILE"

else
    echo -e "${RED} No se encontró el volumen de logs.${NC}"
fi

# ── 3. Subir a S3 (opcional) ─────────────────────────────────
if [ "$1" = "--s3" ] && [ -n "$2" ]; then

    S3_BUCKET="$2"

    echo -e "\n${YELLOW}[3/3] Subiendo backups a S3...${NC}"

    if ! command -v aws &> /dev/null; then
        echo -e "${RED} AWS CLI no está instalado.${NC}"
        exit 1
    fi

    [ -f "$DB_BACKUP_FILE" ] && \
    aws s3 cp "$DB_BACKUP_FILE" "s3://${S3_BUCKET}/backups/mongodb/" && \
    echo -e "${GREEN} Backup MongoDB subido a S3${NC}"

    [ -f "$LOGS_BACKUP_FILE" ] && \
    aws s3 cp "$LOGS_BACKUP_FILE" "s3://${S3_BUCKET}/backups/logs/" && \
    echo -e "${GREEN} Backup logs subido a S3${NC}"

else
    echo -e "\n${YELLOW}[3/3] S3 omitido.${NC}"
    echo -e "Usa: ./backup.sh --s3 <bucket>"
fi

# ── Limpieza automática ──────────────────────────────────────
echo -e "\n${YELLOW}Limpiando backups con más de 7 días...${NC}"

find "$BACKUP_DIR" -name "*.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo -e "${GREEN} Limpieza completada${NC}"

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}   Backup finalizado correctamente${NC}"
echo -e "${GREEN}============================================${NC}\n"