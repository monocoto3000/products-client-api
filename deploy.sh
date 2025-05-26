#!/bin/bash

echo "🚀 Iniciando despliegue remoto en $EC2_IP (PRODUCCIÓN)"
if [ -z "$EC2_IP" ] || [ -z "$EC2_USER" ] || [ -z "$SSH_KEY" ] || [ -z "$APP_NAME" ]; then
  echo "❌ Faltan variables de entorno necesarias."
  exit 1
fi

# 1. Compilar localmente
echo "🏗️ Compilando TypeScript localmente"
rm -rf dist
npm run build

# 2. Crear carpeta temporal con archivos necesarios
echo "📁 Preparando archivos para producción"
rm -rf deploy-temp
mkdir deploy-temp
cp -r dist package*.json ecosystem.config.js deploy-temp 2>/dev/null

# 3. Crear .env dinámico
cat > deploy-temp/.env << ENV
DB_USER_PROD=$DB_USER
DB_PASSWORD_PROD=$DB_PASS
DB_NAME_PROD=$DB_NAME
DB_HOST_PROD=$DB_HOST
DB_PORT=3306
PORT=3000
ENV

# 4. Enviar archivos al servidor
echo "📤 Subiendo archivos al servidor"
scp -i $SSH_KEY -r deploy-temp $EC2_USER@$EC2_IP:/home/$EC2_USER/$APP_NAME

# 5. Ejecutar comandos remotos
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $EC2_USER@$EC2_IP << EOF
  set -e
  cd /home/$EC2_USER/$APP_NAME/deploy-temp

  echo "📦 Instalando dependencias de producción"
  npm ci --only=production

  echo "🚦 Reiniciando servidor con PM2"
  pm2 delete $APP_NAME || true
  pm2 start dist/server.js --name "$APP_NAME" --env production

  echo "✅ Despliegue completado"
EOF

# 6. Limpiar archivos locales
rm -rf deploy-temp
