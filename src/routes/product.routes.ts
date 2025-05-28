// routes/product.routes.ts
import { Router } from 'express';
import { ProductController } from '../controllers/product.controller';

const router = Router();
const controller = new ProductController();

/**
 * @swagger
 * tags:
 *   name: Products
 *   description: Product management and filtering
 */

/**
 * @swagger
 * /products:
 *   get:
 *     summary: Get all available products
 *     tags: [Products]
 *     responses:
 *       200:
 *         description: List of products
 */
router.get('/', controller.getAll);

/**
 * @swagger
 * /products/product-details/{id}:
 *   get:
 *     summary: Get product details by ID
 *     tags: [Products]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Product ID (UUID)
 *     responses:
 *       200:
 *         description: Product found
 *       404:
 *         description: Product not found
 */
router.get('/product-details/:id', controller.getById);

/**
 * @swagger
 * /products/search/by-name:
 *   get:
 *     summary: Get products by name
 *     tags: [Products]
 *     parameters:
 *       - in: query
 *         name: name
 *         schema:
 *           type: string
 *         required: true
 *         description: Name or part of the name to search
 *     responses:
 *       200:
 *         description: List of matching products
 */
router.get('/search/by-name', controller.getByName);

/**
 * @swagger
 * /products/search/by-price:
 *   get:
 *     summary: Get products within a price range
 *     tags: [Products]
 *     parameters:
 *       - in: query
 *         name: min
 *         schema:
 *           type: number
 *         required: true
 *         description: Minimum price
 *       - in: query
 *         name: max
 *         schema:
 *           type: number
 *         required: true
 *         description: Maximum price
 *     responses:
 *       200:
 *         description: List of products within the price range
 */
router.get('/search/by-price', controller.getByPriceRange);

/**
 * @swagger
 * /products/search/by-category:
 *   get:
 *     summary: Get products by category
 *     tags: [Products]
 *     parameters:
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *           format: uuid
 *         required: true
 *         description: Category ID (UUID)
 *     responses:
 *       200:
 *         description: List of products by category
 */
router.get('/search/by-category', controller.getByCategory);

export default router;
