import dotenv from 'dotenv';
import path from 'path';

const env = process.env.NODE_ENV || 'dev';

dotenv.config({ path: path.resolve(process.cwd(), `.env.${env}`) });

console.log(`Loaded env file: .env.${env}`);

export default env;
