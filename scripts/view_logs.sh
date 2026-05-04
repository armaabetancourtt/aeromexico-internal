#!/bin/bash
# view_logs.sh - Consultar logs y simular errores para CloudWatch

LOG_FILE="$HOME/app/logs/app.log"

if [ "$1" == "error" ]; then
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] ERROR: Fallo crítico en conexión a base de datos Aeroméxico" >> $LOG_FILE
    echo " Error simulado e inyectado en el log."
else
    echo " [AEROMEXICO] Mostrando últimas 10 líneas del log:"
    tail -n 10 $LOG_FILE
fi


echo "------------------------------------------------"
echo "Nota: Ejecuta './view_logs.sh error' para activar la alerta Lambda."