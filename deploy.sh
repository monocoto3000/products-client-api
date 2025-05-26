#!/bin/bash
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

# --- Paso 1: Verificar conexión SSH ---
log "Verificando conectividad SSH..."
if ! $SSH_CMD "echo 'Conexión SSH exitosa'"; then
    error "No se pudo conectar a $EC2_IP"
    exit 1
fi
success "Conexión SSH establecida"

# --- Paso 2: Preparar directorio ---
log "Preparando directorio remoto..."
remote_exec "mkdir -p $REMOTE_PATH"

# --- Paso 3: Clonar/Actualizar repo ---
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

# --- Paso 4: Configurar archivo .env ---
log "Generando archivo .env.${NODE_ENV}..."
remote_exec "cat <<EOF > $REMOTE_PATH/.env.${NODE_ENV}
PORT=3000
NODE_ENV=${NODE_ENV}
DB_HOST=${DB_HOST}
DB_PORT=3306
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
DB_NAME=${DB_NAME}
DB_DIALECT=mysql  
EOF"

# Crear symlink para .env
remote_exec "
cd $REMOTE_PATH
ln -sf .env.${NODE_ENV} .env
"

# --- Paso 5: Instalar Node.js y PM2 ---
log "Instalando Node.js y PM2..."
remote_exec "
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
if ! command -v pm2 &>/dev/null; then
    sudo npm install -g pm2
fi
"

# --- Paso 6: Instalar dependencias ---
log "Instalando dependencias..."
remote_exec "
cd $REMOTE_PATH
rm -rf node_modules package-lock.json
npm cache clean --force
npm install --production
"

# --- Paso 7: Validar conexión a MySQL ---
log "Validando conexión a MySQL..."
remote_exec "
if ! mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e 'SELECT 1' &>/dev/null; then
    echo '❌ Error: No se pudo conectar a MySQL'
    exit 1
fi
echo '✅ MySQL accesible'
"

# --- Paso 8: Ejecutar migraciones ---
log "Ejecutando migraciones..."
remote_exec "
cd $REMOTE_PATH
if npm run | grep -q 'migrate:$NODE_ENV'; then
    npm run migrate:$NODE_ENV || echo '⚠️ Migración falló o no era necesaria'
fi
"

# --- Paso 9: Configurar PM2 ---
log "Configurando PM2..."
remote_exec "mkdir -p $REMOTE_PATH/logs"
remote_exec "cat <<EOF > $REMOTE_PATH/ecosystem.config.json
{
  \"apps\": [{
    \"name\": \"$APP_NAME-$NODE_ENV\",
    \"script\": \"dist/server.js\",
    \"cwd\": \"$REMOTE_PATH\",
    \"env\": {
      \"NODE_ENV\": \"$NODE_ENV\"
    },
    \"error_file\": \"$REMOTE_PATH/logs/err.log\",
    \"out_file\": \"$REMOTE_PATH/logs/out.log\",
    \"merge_logs\": true,
    \"autorestart\": true
  }]
}
EOF"

# --- Paso 10: Reiniciar aplicación ---
log "Reiniciando aplicación..."
remote_exec "
cd $REMOTE_PATH
pm2 delete $APP_NAME-$NODE_ENV || true
pm2 start ecosystem.config.json
pm2 save
pm2 startup || true
"

# --- Paso 11: Verificar estado ---
log "Verificando estado..."
remote_exec "
cd $REMOTE_PATH
pm2 list
pm2 logs --lines 10 --nostream
"

# --- Paso 12: Health Check ---
log "Comprobando health check..."
remote_exec "
sleep 10
curl -fs http://localhost:3000/health && echo '✅ Health check OK' || echo '❌ Health check falló'
"

# --- Resultado final ---
success "¡Despliegue completado en $NODE_ENV!"
log "App: $APP_NAME-$NODE_ENV"
log "Ruta: $REMOTE_PATH"
log "Endpoint: http://$EC2_IP:3000"