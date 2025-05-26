#!/bin/bash

# Script de despliegue para API REST con Express y Sequelize
# Funciona con Jenkins pipeline para diferentes ambientes (dev, qa, prod)

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar variables requeridas
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

# Configurar SSH
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
SSH_CMD="ssh -i $SSH_KEY $SSH_OPTIONS $EC2_USER@$EC2_IP"
SCP_CMD="scp -i $SSH_KEY $SSH_OPTIONS"

# Función para ejecutar comandos remotos
remote_exec() {
    log "Ejecutando: $1"
    $SSH_CMD "$1"
}

# Función para copiar archivos
remote_copy() {
    log "Copiando: $1 -> $2"
    $SCP_CMD "$1" "$EC2_USER@$EC2_IP:$2"
}

# Verificar conectividad
log "Verificando conectividad SSH..."
if ! $SSH_CMD "echo 'Conexión SSH exitosa'"; then
    error "No se pudo conectar via SSH a $EC2_IP"
    exit 1
fi

success "Conexión SSH establecida"

# Preparar directorio remoto
log "Preparando directorio de aplicación..."
remote_exec "mkdir -p $REMOTE_PATH"
remote_exec "cd $REMOTE_PATH && pwd"

# Clonar o actualizar repositorio
log "Actualizando código fuente..."
remote_exec "
if [ -d '$REMOTE_PATH/.git' ]; then
    echo 'Repositorio existe, actualizando...'
    cd $REMOTE_PATH
    git fetch origin
    git reset --hard origin/$GIT_BRANCH
    git clean -fd
else
    echo 'Clonando repositorio...'
    rm -rf $REMOTE_PATH
    git clone -b $GIT_BRANCH $REPO_URL $REMOTE_PATH
    cd $REMOTE_PATH
fi
"

# Crear archivo .env basado en el ambiente
log "Configurando variables de entorno para $NODE_ENV..."
ENV_CONTENT=\"PORT=3000
NODE_ENV=$NODE_ENV
DB_HOST=$DB_HOST
DB_PORT=5432
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
DB_NAME=$DB_NAME\"

# Escribir .env en el servidor
remote_exec "cat > $REMOTE_PATH/.env << 'EOF'
$ENV_CONTENT
EOF"

# Verificar Node.js y npm
log "Verificando Node.js y npm..."
remote_exec "
if ! command -v node &> /dev/null; then
    echo 'Instalando Node.js...'
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

if ! command -v pm2 &> /dev/null; then
    echo 'Instalando PM2...'
    sudo npm install -g pm2
fi

node --version
npm --version
pm2 --version
"

# Instalar dependencias
log "Instalando dependencias..."
remote_exec "
cd $REMOTE_PATH
rm -rf node_modules package-lock.json
npm cache clean --force
npm install --production
"

# Ejecutar migraciones de base de datos
log "Ejecutando migraciones de base de datos..."
MIGRATE_SCRIPT="migrate:$NODE_ENV"
remote_exec "
cd $REMOTE_PATH
if [ -f 'package.json' ] && npm run | grep -q \"\$MIGRATE_SCRIPT\"; then
    echo 'Ejecutando migraciones con: \$MIGRATE_SCRIPT'
    npm run \$MIGRATE_SCRIPT || echo 'No se pudieron ejecutar migraciones, continuando...'
else
    echo 'No se encontraron scripts de migración para \$MIGRATE_SCRIPT'
fi
"

# Determinar archivo principal según el entorno
if [ \"$NODE_ENV\" == \"prod\" ]; then
    MAIN_FILE=\"dist/server.js\"
else
    MAIN_FILE=\"src/server.ts\"
fi

log \"Archivo principal detectado: \$MAIN_FILE\"

# Crear archivo de configuración PM2
log \"Configurando PM2...\"
PM2_CONFIG=\"{
  \\\"apps\\\": [{
    \\\"name\\\": \\\"$APP_NAME-$NODE_ENV\\\",
    \\\"script\\\": \\\"\$MAIN_FILE\\\",
    \\\"cwd\\\": \\\"$REMOTE_PATH\\\",
    \\\"env\\\": {
      \\\"NODE_ENV\\\": \\\"$NODE_ENV\\\",
      \\\"PORT\\\": \\\"3000\\\"
    },
    \\\"instances\\\": 1,
    \\\"exec_mode\\\": \\\"fork\\\",
    \\\"watch\\\": false,
    \\\"max_memory_restart\\\": \\\"1G\\\",
    \\\"error_file\\\": \\\"./logs/err.log\\\",
    \\\"out_file\\\": \\\"./logs/out.log\\\",
    \\\"log_file\\\": \\\"./logs/combined.log\\\",
    \\\"time\\\": true,
    \\\"autorestart\\\": true,
    \\\"restart_delay\\\": 1000
  }]
}\"

remote_exec "
cd $REMOTE_PATH
mkdir -p logs
echo '$PM2_CONFIG' > ecosystem.config.json
echo 'Configuración PM2 creada:'
cat ecosystem.config.json
"

# Detener aplicación existente
log "Deteniendo aplicación existente..."
remote_exec "
cd $REMOTE_PATH
pm2 stop $APP_NAME-$NODE_ENV || echo 'Aplicación no estaba ejecutándose'
pm2 delete $APP_NAME-$NODE_ENV || echo 'Proceso no existía en PM2'
"

# Iniciar aplicación
log "Iniciando aplicación..."
remote_exec "
cd $REMOTE_PATH
pm2 start ecosystem.config.json
pm2 save
pm2 startup || echo 'PM2 startup ya configurado'
"

# Verificar que la aplicación esté corriendo
log "Verificando estado de la aplicación..."
sleep 5
remote_exec "
cd $REMOTE_PATH
echo '=== PM2 STATUS ==='
pm2 status
echo '=== ÚLTIMOS 10 LOGS ==='
pm2 logs $APP_NAME-$NODE_ENV --lines 10 --nostream
echo '=== VERIFICANDO PROCESO ==='
pm2 describe $APP_NAME-$NODE_ENV || echo 'Proceso no encontrado'
"

# Verificar endpoint de salud (opcional)
log "Verificando endpoint de salud..."
remote_exec "
sleep 10
if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
    echo 'Aplicación respondiendo correctamente'
else
    echo 'Advertencia: La aplicación podría no estar respondiendo en /health'
fi
"

# Limpiar archivos temporales
log "Limpiando archivos temporales..."
remote_exec "
cd $REMOTE_PATH
rm -rf .git/hooks/*
find . -name '*.log' -type f -mtime +7 -delete 2>/dev/null || true
"

# Mostrar información final
success "¡Despliegue completado exitosamente!"
log "Información del despliegue:"
log "  - Ambiente: $NODE_ENV"
log "  - Rama: $GIT_BRANCH"
log "  - Servidor: $EC2_IP"
log "  - Aplicación: $APP_NAME-$NODE_ENV"
log "  - Ruta: $REMOTE_PATH"

success "La aplicación está ejecutándose en el puerto 3000"
warning "Recuerda verificar que el Security Group permita el tráfico en el puerto 3000"

log "Para monitorear la aplicación:"
log "  pm2 status"
log "  pm2 logs $APP_NAME-$NODE_ENV"
log "  pm2 restart $APP_NAME-$NODE_ENV"
