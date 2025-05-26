#!/bin/bash

echo "🚀 Iniciando despliegue remoto en $EC2_IP"

REMOTE_PATH="/home/$EC2_USER/app"
APP_NAME="products-api"

ssh -i $SSH_KEY -o StrictHostKeyChecking=no $EC2_USER@$EC2_IP << EOF
  set -e

  echo "🔧 Preparando entorno en EC2"
  sudo apt update -y
  sudo apt install -y nodejs npm

  echo "📦 Instalando TypeScript"
  sudo npm install -g typescript

  mkdir -p $REMOTE_PATH
  cd $REMOTE_PATH

  if [ ! -d ".git" ]; then
    echo "🔄 Clonando repo"
    git clone -b $GIT_BRANCH $REPO_URL .
  else
    echo "📥 Actualizando repo"
    git reset --hard
    git pull origin $GIT_BRANCH
  fi

  echo "🌱 Generando .env"
  cat > .env << ENV
DB_USER_PRODUCTION=$DB_USER
DB_PASSWORD_PRODUCTION=$DB_PASS
DB_NAME_PRODUCTION=$DB_NAME
DB_HOST_PRODUCTION=$DB_HOST
DB_PORT=3306
PORT=3000
ENV

  echo "📦 Instalando dependencias"
  npm ci

  echo "🏗️ Compilando proyecto"
  tsc

  echo "🚀 Desplegando con PM2"
  pm2 delete $APP_NAME || true
  pm2 start dist/server.js --name "$APP_NAME" --env production

  echo "✅ Despliegue completado"
EOF
