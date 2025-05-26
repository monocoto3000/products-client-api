#!/bin/bash

# Script de despliegue para API REST con Express y Sequelize
# Funciona con Jenkins pipeline para diferentes ambientes (dev, qa, prod)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funciones de log
log()     { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Validar variables requeridas
required_vars=(
    "SSH_KEY" "EC2_USER" "EC2_IP" "REMOTE_PATH"
    "REPO_URL" "APP_NAME" "NODE_ENV" "GIT_BRANCH"
    "DB_HOST" "DB_USER" "DB_PASS" "DB_NAME"
)

for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        error "Variable requerida $var no está definida"
        exit 1
    fi
done

log "Iniciando despliegue en ambiente: $NODE_ENV"
log "Rama: $GIT_BRANCH"
log "Servidor: $EC2_IP"

# SSH
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
SSH_CMD="ssh -i $SSH_KEY $SSH_OPTIONS $EC2_USER@$EC2_IP"
SCP_CMD="scp -i $SSH_KEY $SSH_OPTIONS"

remote_exec() {
    log "Ejecutando remoto: $1"
    $SSH_CMD "$1"
}

# Verificar conexión
log "Verificando conectividad SSH..."
if ! $SSH_CMD "echo 'Conexión SSH exitosa'"; then
    error "No se pudo conectar a $EC2_IP"
    exit 1
fi
success "Conexión SSH establecida"

# Preparar directorio
log "Preparando directorio..."
remote_exec "mkdir -p $REMOTE_PATH"

# Clonar o actualizar repo
log "Sincronizando código fuente..."
remote_exec "
if [ -d '$REMOTE_PATH/.git' ]; then
    cd $REMOTE_PATH
    git fetch origin
    git reset --hard origin/$GIT_BRANCH
    git clean -fd
else
    rm -rf $REMOTE_PATH
    git clone -b $GIT_BRANCH $REPO_URL $REMOTE_PATH
fi
"

# Escribir archivo .env
log "Configurando archivo .env..."
remote_exec "cat <<EOF > $REMOTE_PATH/.env
PORT=3000
NODE_ENV=$NODE_ENV
DB_HOST=$DB_HOST
DB_PORT=5432
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
DB_NAME=$DB_NAME
EOF"

# Instalar Node.js y PM2 si no existen
remote_exec "
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
if ! command -v pm2 &>/dev/null; then
    sudo npm install -g pm2
fi
"

# Instalar dependencias
log "Instalando dependencias..."
remote_exec "
cd $REMOTE_PATH
rm -rf node_modules package-lock.json
npm cache clean --force
npm install --production
"

# Ejecutar migraciones si existen
log "Ejecutando migraciones..."
remote_exec "
cd $REMOTE_PATH
if npm run | grep -q 'migrate:$NODE_ENV'; then
    npm run migrate:$NODE_ENV || echo 'Migración falló o no era necesaria'
else
    echo 'No se encontró script migrate:$NODE_ENV'
fi
"

# Detectar archivo principal
MAIN_FILE="src/server.ts"
[[ "$NODE_ENV" == "prod" ]] && MAIN_FILE="dist/server.js"
log "Archivo principal: $MAIN_FILE"

# Crear configuración PM2
log "Creando configuración PM2..."
remote_exec "mkdir -p $REMOTE_PATH/logs"
remote_exec "cat <<EOF > $REMOTE_PATH/ecosystem.config.json
{
  \"apps\": [{
    \"name\": \"$APP_NAME-$NODE_ENV\",
    \"script\": \"$MAIN_FILE\",
    \"cwd\": \"$REMOTE_PATH\",
    \"env\": {
      \"NODE_ENV\": \"$NODE_ENV\",
      \"PORT\": \"3000\"
    },
    \"instances\": 1,
    \"exec_mode\": \"fork\",
    \"watch\": false,
    \"max_memory_restart\": \"1G\",
    \"error_file\": \"./logs/err.log\",
    \"out_file\": \"./logs/out.log\",
    \"log_file\": \"./logs/combined.log\",
    \"time\": true,
    \"autorestart\": true,
    \"restart_delay\": 1000
  }]
}
EOF"

# Reiniciar la app con PM2
log "Reiniciando aplicación en PM2..."
remote_exec "
cd $REMOTE_PATH
pm2 stop $APP_NAME-$NODE_ENV || true
pm2 delete $APP_NAME-$NODE_ENV || true
pm2 start ecosystem.config.json
pm2 save
pm2 startup || echo 'Startup ya estaba configurado'
"

# Verificar estado
log "Verificando estado de la aplicación..."
remote_exec "
cd $REMOTE_PATH
pm2 status
pm2 logs $APP_NAME-$NODE_ENV --lines 10 --nostream
"

# Comprobar healthcheck
log "Comprobando endpoint /health..."
remote_exec "
sleep 10
curl -fs http://localhost:3000/health && echo 'Aplicación saludable' || echo 'Advertencia: /health no respondió'
"

# Limpiar logs viejos
log "Limpiando archivos temporales..."
remote_exec "
cd $REMOTE_PATH
rm -rf .git/hooks/*
find . -name '*.log' -type f -mtime +7 -delete || true
"

# Resultado final
success "¡Despliegue completado exitosamente!"
log "Ambiente: $NODE_ENV"
log "Servidor: $EC2_IP"
log "Aplicación: $APP_NAME-$NODE_ENV"
log "Ruta: $REMOTE_PATH"
