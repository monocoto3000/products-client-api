import { Request, Response, NextFunction } from 'express';
import { ProductService } from '../services/product.service';

const productService = new ProductService();

export class ProductController {

  getAll = async (req: Request, res: Response, next: NextFunction) => {
    try {
    const products = await productService.getAllProducts();
      res.json(products);
    } catch (error) {
      next(error);
    }
  }

  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = parseInt(req.params.id);
      const product = await productService.getProductById(id);
      res.json(product);
    } catch (error) {
      next(error);
    }
  };

getByName = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const name = req.query.name as string;
      const products = await productService.getProductsByName(name);
      res.json(products);
    } catch (error) {
      next(error);
    }
  };

 getByPriceRange = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const min = parseFloat(req.query.min as string);
      const max = parseFloat(req.query.max as string);
      const products = await productService.getProductsByPriceRange(min, max);
      res.json(products);
    } catch (error) {
      next(error);
    }
  };

  getByCategory = async (req: Request, res: Response, next: NextFunction) => {
      try {
        const categoryIdRaw = req.query.category;
        
        if (typeof categoryIdRaw !== 'string') {
          throw new Error('Category query parameter must be a string');
        }
        
        const categoryId = Number(categoryIdRaw);
        if (isNaN(categoryId)) {
          throw new Error('Category query parameter must be a valid number');
        }

        const products = await productService.getProductsByCategory(categoryId);
        res.json(products);
      } catch (error) {
        next(error);
      }
    };
};



