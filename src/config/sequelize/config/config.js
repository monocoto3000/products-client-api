const dotenv = require('dotenv');
dotenv.config(); 

const env = process.env.NODE_ENV || 'dev';
const upperEnv = env.toUpperCase(); 

console.log('NODE_ENV:', process.env.NODE_ENV);
console.log('Using DB_USER:', process.env[`DB_USER_${upperEnv}`]);

module.exports = {
  [env]: {
    username: process.env[`DB_USER_${upperEnv}`],
    password: process.env[`DB_PASSWORD_${upperEnv}`],
    database: process.env[`DB_NAME_${upperEnv}`],
    host: process.env[`DB_HOST_${upperEnv}`],
    port: process.env.DB_PORT,
    dialect: 'mysql',
  },
};