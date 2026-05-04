#!/bin/bash
# deploy.sh - Configuración inicial del entorno Aeroméxico

set -e

echo "[AEROMEXICO] Iniciando despliegue de infraestructura local..."

# 1. Actualizar sistema e instalar Docker si no existe
sudo yum update -y
if ! command -v docker &> /dev/null; then
    echo "Instalando Docker..."
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
fi

# 2. Crear estructura de directorios para logs
echo "Creando carpetas de persistencia..."
mkdir -p ~/app/logs
touch ~/app/logs/app.log

# 3. Dar permisos
sudo chmod -R 777 ~/app/logs

echo "Despliegue técnico completado. Listo para iniciar aplicaciones."