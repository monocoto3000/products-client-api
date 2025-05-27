#!/bin/bash

echo "🚀 Iniciando despliegue remoto en $EC2_IP"

# Validar variables locales
if [ -z "$EC2_IP" ] || [ -z "$EC2_USER" ] || [ -z "$SSH_KEY" ] || [ -z "$REPO_URL" ] || [ -z "$GIT_BRANCH" ] || [ -z "$NODE_ENV" ]; then
  echo "❌ Faltan variables de entorno. Asegúrate de definir EC2_IP, EC2_USER, SSH_KEY, REPO_URL, GIT_BRANCH y NODE_ENV."
  exit 1
fi
if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_NAME" ] || [ -z "$DB_HOST" ]; then
  echo "❌ Faltan variables de entorno de la base de datos. Asegúrate de definir DB_USER, DB_PASS, DB_NAME y DB_HOST."
  exit 1
fi

REMOTE_PATH="/home/$EC2_USER/app"
APP_NAME="$APP_NAME"

echo "🌐 Conectando a la instancia EC2: $EC2_IP"
echo "➡️ Conectando a $EC2_USER@$EC2_IP"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" bash -s << EOF
  set -e

  export DB_HOST="$DB_HOST"
  export DB_USER="$DB_USER"
  export DB_PASS="$DB_PASS"
  export DB_NAME="$DB_NAME"
  export NODE_ENV="$NODE_ENV"
  export APP_NAME="$APP_NAME"

  echo "📁 Creando/entrando a carpeta del proyecto"
  mkdir -p "$REMOTE_PATH"
  cd "$REMOTE_PATH"

  if [ ! -d ".git" ]; then
    echo "🌀 Clonando repositorio"
    git clone -b "$GIT_BRANCH" "$REPO_URL" .
  else
    echo "🔄 Haciendo pull del código"
    git fetch origin
    git checkout "$GIT_BRANCH"
    git pull origin "$GIT_BRANCH"
  fi

  echo "⚙️ Ejecutando setup EC2 (deploy-utils)"
  chmod +x scripts/deploy-utils.sh
  ./scripts/deploy-utils.sh

  echo "🔧 Creando archivo .env"
  cat > .env << ENV
DB_USER_\${NODE_ENV^^}=\$DB_USER
DB_PASSWORD_\${NODE_ENV^^}=\$DB_PASS
DB_NAME_\${NODE_ENV^^}=\$DB_NAME
DB_HOST_\${NODE_ENV^^}=\$DB_HOST
DB_PORT=3306
PORT=3000
ENV

  echo "📦 Instalando dependencias"
  npm ci

  echo "🏗️ Compilando TypeScript"
  npm run build

  echo "🚦 Reiniciando servidor con PM2"
  pm2 delete "\$APP_NAME" || true
  pm2 start dist/server.js --name "\$APP_NAME" --env "\$NODE_ENV"

  echo "✅ Despliegue completado en \$NODE_ENV"
EOF
