import './config/env';  
import express from 'express';
import productRoutes from './routes/product.routes';
import { errorMiddleware } from './middlewares/error.middleware';
import { swaggerUi, swaggerSpec } from './utils/swagger';
import { sequelize } from './config/database';

const app = express();
app.use(express.json());

sequelize.sync()
  .then(() => console.log('Database synced'))
  .catch(error => console.error('Database sync error:', error));

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
app.use('/products', productRoutes);
app.use(errorMiddleware);

export default app;
