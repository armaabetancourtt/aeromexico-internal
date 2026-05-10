#!/bin/bash
# view_logs.sh - Consultar logs y simular errores para CloudWatch

LOG_FILE="/var/lib/docker/volumes/priv-profinaldevops_admin_logs/_data/admin.log"

# Verificar si existe el archivo
if ! sudo test -f "$LOG_FILE"; then
    echo " ERROR: No existe el archivo de log:"
    echo "$LOG_FILE"
    exit 1
fi

if [ "$1" == "error" ]; then
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] ERROR: Fallo crítico en conexión a base de datos Aeroméxico" | sudo tee -a "$LOG_FILE" > /dev/null
    echo " Error simulado e inyectado en el log."
else
    echo " [AEROMEXICO] Mostrando últimas 10 líneas del log:"
    sudo tail -n 10 "$LOG_FILE"
fi

echo "------------------------------------------------"
echo "Nota: Ejecuta './view_logs.sh error' para activar la alerta Lambda."