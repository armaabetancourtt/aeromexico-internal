#!/bin/bash
# deploy.sh - Configuración inicial del entorno Aeroméxico

set -e

echo "[AEROMEXICO] Iniciando despliegue de infraestructura local..."

# Actualizar sistema
sudo yum update -y

# Instalar Docker si no existe
if ! command -v docker &> /dev/null; then
    echo "[AEROMEXICO] Instalando Docker..."

    sudo amazon-linux-extras install docker -y
    sudo systemctl enable docker
    sudo systemctl start docker

    sudo usermod -aG docker ec2-user

    echo "[AEROMEXICO] Docker instalado correctamente."
else
    echo "[AEROMEXICO] Docker ya está instalado."
fi

# Crear red Docker si no existe
docker network inspect aeromexico-network >/dev/null 2>&1 || \
docker network create aeromexico-network

# Crear volumen persistente para logs/datos
docker volume create priv-profinaldevops_admin_logs >/dev/null 2>&1 || true

echo "------------------------------------------------"
echo "[AEROMEXICO] Infraestructura preparada correctamente."
echo "Listo para ejecutar ./start_app.sh"