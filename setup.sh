#!/bin/bash

echo "Iniciando setup del proyecto..."

npm install swagger-jsdoc swagger-ui-express cross-env

npm install --save-dev @types/swagger-jsdoc @types/swagger-ui-express sequelize-cli ts-node-dev

for env in .env.example .env.prod .env.dev .env.qa; do
    if [ ! -f "$env" ]; then
        touch "$env"
        echo "# Archivo de entorno $env" > "$env"
    fi
done

# Inicializar .sequelizerc si no existe
if [ ! -f .sequelizerc ]; then
    npx sequelize-cli init
fi

# Crear tsconfig.json si no existe
if [ ! -f tsconfig.json ]; then
    npx tsc --init
fi
if [ ! -f package.json ]; then
    npm init -y
fi

# Instala dependencias principales
npm install express sequelize dotenv

# npm install pg pg-hstore         # Para PostgreSQL
npm install mysql2              # Para MySQL/MariaDB
# npm install sqlite3             # Para SQLite

npm install --save-dev typescript @types/node @types/express @types/sequelize nodemon

echo "Setup completado."

echo ""
echo "Para correr este script usa:"
echo "bash setup.sh"