import { Product } from '../models/product.model';
import { ProductDTO } from '../models/dtos/product.dto';
import { Op } from 'sequelize';
import { HttpException } from '../utils/exceptions';
import { Category } from '../models/category.model';

const toDTO = (product: any): ProductDTO => ({
  name: product.name,
  description: product.description,
  price: product.price,
  image: product.image,
  stock: product.stock,
  category: product.Category?.name,
});

export class ProductService {
  async getAllProducts(): Promise<ProductDTO[]> {
    const products = await Product.findAll({
      where: { availability: 1 },
      include: [{ model: Category, attributes: ['name'] }],
    });
    return products.map(toDTO);
  }

  async getProductById(id: number): Promise<ProductDTO> {
    const product = await Product.findOne({
      where: { id, availability: 1 },
      include: [{ model: Category, attributes: ['name'] }],
    });
    if (!product) {
      throw new HttpException(404, 'Producto no encontrado');
    }
    return toDTO(product);
  }

  async getProductsByName(name: string): Promise<ProductDTO[]> {
    if (!name) {
      throw new HttpException(400, 'El nombre es requerido');
    }
    const products = await Product.findAll({
      where: {
        name: { [Op.like]: `%${name}%` },
        availability: 1,
      },
      include: [{ model: Category, attributes: ['name'] }],
    });
    return products.map(toDTO);
  }

  async getProductsByPriceRange(min: number, max: number): Promise<ProductDTO[]> {
    if (isNaN(min) || isNaN(max)) {
      throw new HttpException(400, 'El rango de precios no es válido');
    }
    const products = await Product.findAll({
      where: {
        price: { [Op.between]: [min, max] },
        availability: 1,
      },
      include: [{ model: Category, attributes: ['name'] }],
    });
    return products.map(toDTO);
  }

  async getProductsByCategory(categoryId: number): Promise<ProductDTO[]> {
    if (!categoryId) {
      throw new HttpException(400, 'La categoría es requerida');
    }
    const products = await Product.findAll({
      where: {
        availability: 1,
      },
      include: [{
        model: Category,
        attributes: ['name'],
        where: { id: categoryId },  
      }],
    });
    return products.map(toDTO);
  }
}
