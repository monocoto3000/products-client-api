import dotenv from 'dotenv';

dotenv.config();

const env = process.env.NODE_ENV || 'dev';
const upperEnv = env.toUpperCase();

console.log(`Uppercase Environment: ${upperEnv}`);

export const config = {
  env,
  db: {
    user: process.env[`DB_USER_${upperEnv}`]!,
    password: process.env[`DB_PASSWORD_${upperEnv}`]!,
    name: process.env[`DB_NAME_${upperEnv}`]!,
    host: process.env[`DB_HOST_${upperEnv}`]!,
    port: Number(process.env.DB_PORT || 3306),
  },
};

