#!/bin/bash
# start_app.sh - Arrancar contenedores Docker

echo "[AEROMEXICO] Levantando servicios..."

# Eliminar contenedores anteriores si existen
docker stop priv-admin-frontend priv-admin-backend mongodb-vuelos 2>/dev/null || true
docker rm priv-admin-frontend priv-admin-backend mongodb-vuelos 2>/dev/null || true

# Crear red si no existe
docker network create aeromexico-network 2>/dev/null || true

# Levantar MongoDB
docker run -d \
  --name mongodb-vuelos \
  --network aeromexico-network \
  -p 27017:27017 \
  -v priv-profinaldevops_admin_logs:/data/db \
  mongo:6-jammy

# Levantar Backend
docker run -d \
  --name priv-admin-backend \
  --network aeromexico-network \
  priv-profinaldevops-admin-backend

# Levantar Frontend
docker run -d \
  --name priv-admin-frontend \
  --network aeromexico-network \
  -p 8090:80 \
  priv-profinaldevops-admin-frontend

echo "------------------------------------------------"
echo "[AEROMEXICO] Estado actual de los contenedores:"
docker ps

echo "------------------------------------------------"
echo " Aplicación iniciada correctamente."