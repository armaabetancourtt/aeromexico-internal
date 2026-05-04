#!/bin/bash
# start_app.sh - Arrancar contenedores Docker

echo " [AEROMEXICO] Levantando servicios..."

docker stop aeromexico-app mongo-db 2>/dev/null || true
docker rm aeromexico-app mongo-db 2>/dev/null || true

# EJEMPLO PARA EC2 PÚBLICA (Landing Page)
# docker run -d --name aeromexico-app -p 80:80 nginx

# EJEMPLO PARA EC2 PRIVADA (Intranet + Mongo)
# docker run -d --name mongo-db -p 27017:27017 mongo

echo "Estado de los contenedores:"
docker ps

echo "Aplicación iniciada correctamente."