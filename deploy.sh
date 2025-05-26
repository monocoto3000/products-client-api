#!/bin/bash
set -e

if [[ -z "$SSH_KEY" || -z "$EC2_USER" || -z "$EC2_IP" || -z "$REMOTE_PATH" || -z "$REPO_URL" || -z "$APP_NAME" || -z "$NODE_ENV" || -z "$GIT_BRANCH" || -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_PASS" || -z "$DB_NAME" ]]; then
  echo "Faltan variables de entorno necesarias."
  exit 1
fi

# Load utility functions to pass to the remote environment
source "$(dirname "$0")/deploy-utils.sh"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" "
  $(typeset -f install_node_and_pm2)
  $(typeset -f ensure_remote_path)
  install_node_and_pm2
  ensure_remote_path --path $REMOTE_PATH
  cd $REMOTE_PATH
  
  if [ ! -d .git ]; then
    git clone $REPO_URL .
    git checkout $GIT_BRANCH
  else
    git fetch
    git checkout $GIT_BRANCH
    git pull
  fi
  
  npm ci
  npm run build
  
  # Crear el archivo .env según el entorno
  ENV_FILE=\".env.\$NODE_ENV\"
  if [ \"\$NODE_ENV\" = \"development\" ]; then
    ENV_FILE=\".env.dev\"
    SEQUELIZE_ENV=\"dev\"
  elif [ \"\$NODE_ENV\" = \"production\" ]; then
    ENV_FILE=\".env.prod\"
    SEQUELIZE_ENV=\"prod\"
  elif [ \"\$NODE_ENV\" = \"qa\" ]; then
    ENV_FILE=\".env.qa\"
    SEQUELIZE_ENV=\"qa\"
  else
    SEQUELIZE_ENV=\"\$NODE_ENV\"
  fi
  
  echo \"Creando archivo de configuración: \$ENV_FILE\"
  echo \"NODE_ENV=\$NODE_ENV\" > \$ENV_FILE
  echo \"PORT=3000\" >> \$ENV_FILE
  echo \"DB_NAME=$DB_NAME\" >> \$ENV_FILE
  echo \"DB_PORT=3306\" >> \$ENV_FILE
  echo \"DB_USER=$DB_USER\" >> \$ENV_FILE
  echo \"DB_PASSWORD=$DB_PASS\" >> \$ENV_FILE
  echo \"DB_HOST=$DB_HOST\" >> \$ENV_FILE
  
  # Verificar que existe la configuración de Sequelize
  if [ ! -f .sequelizerc ]; then
    echo \"Error: .sequelizerc no encontrado\"
    exit 1
  fi
  
  # Ejecutar migraciones usando sequelize-cli directamente
  echo \"Ejecutando migraciones para entorno: \$SEQUELIZE_ENV\"
  NODE_ENV=\$SEQUELIZE_ENV npx sequelize-cli db:migrate --env \$SEQUELIZE_ENV
  
  # Reiniciar o iniciar la aplicación con PM2
  # Cambiar dist/main.js por dist/server.js según tu estructura
  pm2 restart $APP_NAME || pm2 start dist/server.js --name $APP_NAME
"