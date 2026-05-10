#!/bin/bash
# stop_app.sh - Detener servicios de forma segura

echo "[AEROMEXICO] Deteniendo servicios..."

CONTAINERS=(
    "priv-admin-frontend"
    "priv-admin-backend"
    "mongodb-vuelos"
)

for container in "${CONTAINERS[@]}"
do
    if [ "$(docker ps -aq -f name=^/${container}$)" ]; then
        
        # Quitar reinicio automático
        docker update --restart=no $container > /dev/null 2>&1
        
        # Detener contenedor
        docker stop $container
        
        # Eliminar contenedor
        docker rm $container
        
        echo " Contenedor '$container' detenido y eliminado."
    else
        echo " El contenedor '$container' no existe o ya está detenido."
    fi
done

echo " Todos los procesos de Docker han sido finalizados."