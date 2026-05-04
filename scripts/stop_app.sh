#!/bin/bash
# stop_app.sh - Detener servicios de forma segura

echo "[AEROMEXICO] Deteniendo servicios..."

# Detener contenedores por nombre
containers=$(docker ps -aqf "name=aeromexico-app")
if [ -n "$containers" ]; then
    docker stop aeromexico-app
    docker rm aeromexico-app
    echo " Contenedor de Aplicación detenido."
fi

if [ -n "$(docker ps -aqf "name=mongo-db")" ]; then
    docker stop mongo-db
    docker rm mongo-db
    echo " Contenedor de MongoDB detenido."
fi

echo " Todos los procesos de Docker han sido finalizados."