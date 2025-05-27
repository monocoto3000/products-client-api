#!/bin/bash

set -e

EC2_USER=$(whoami)
echo "🔧 Iniciando configuración en EC2 para usuario: $EC2_USER"

# Actualizar e instalar dependencias básicas
echo "📦 Actualizando paquetes..."
sudo apt-get update -y

# Instalar Node.js y npm
if ! command -v node >/dev/null 2>&1; then
  echo "📥 Instalando Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "✅ Node.js ya está instalado."
fi

# Instalar pm2
if ! command -v pm2 >/dev/null 2>&1; then
  echo "📥 Instalando PM2..."
  sudo npm install -g pm2

  echo "⚙️ Configurando PM2 para reinicio automático..."
  pm2 startup systemd
  sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $EC2_USER --hp /home/$EC2_USER
  pm2 save
else
  echo "✅ PM2 ya está instalado."
fi

# Instalar Git
if ! command -v git >/dev/null 2>&1; then
  echo "📥 Instalando Git..."
  sudo apt-get install -y git
else
  echo "✅ Git ya está instalado."
fi

# Instalar build-essential
if ! dpkg -s build-essential >/dev/null 2>&1; then
  echo "📥 Instalando build-essential..."
  sudo apt-get install -y build-essential
else
  echo "✅ build-essential ya está instalado."
fi

echo "✅ Configuración completada. Tu EC2 está lista para los despliegues."