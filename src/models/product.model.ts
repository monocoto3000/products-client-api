import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database';
import { Category } from './category.model';

export const Product = sequelize.define('Product', {
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  description: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  price: {
    type: DataTypes.FLOAT,
    allowNull: false,
  },
  image: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  stock: { 
    type: DataTypes.INTEGER, 
    allowNull: false, 
    defaultValue: 0,
    validate: {
      min: 0 
    }
  },
  availability: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0, 
    validate: {
      isIn: [[0, 1]] 
    }
  },
  deletedAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },
}, {
  timestamps: true,
  paranoid: true,
  hooks: {
    beforeSave: (product: any) => {
      product.availability = product.stock > 0 ? 1 : 0;
    }
  }
});

Product.belongsTo(Category, { foreignKey: 'categoryId' });
Category.hasMany(Product, { foreignKey: 'categoryId' });
