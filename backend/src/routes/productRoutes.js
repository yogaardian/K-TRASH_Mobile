const express = require('express');
const router = express.Router();
const productService = require('../services/productService');
const { authenticateToken, requireRole } = require('../middleware/auth');

/**
 * GET /products - List all active products
 * Query params: kategori, search
 */
router.get('/products', async (req, res) => {
  try {
    const { kategori, search } = req.query;
    const filters = {
      kategori,
      search,
      active: true
    };

    const products = await productService.getProducts(filters);

    res.json({
      status: 'success',
      count: products.length,
      data: products
    });
  } catch (err) {
    console.error('Error fetching products:', err);
    res.status(500).json({
      status: 'error',
      message: err.message || 'Failed to fetch products'
    });
  }
});

/**
 * GET /products/categories - Get all product categories
 */
router.get('/products/categories', async (req, res) => {
  try {
    const categories = await productService.getCategories();

    res.json({
      status: 'success',
      count: categories.length,
      data: categories
    });
  } catch (err) {
    console.error('Error fetching categories:', err);
    res.status(500).json({
      status: 'error',
      message: err.message || 'Failed to fetch categories'
    });
  }
});

/**
 * GET /products/:id - Get single product
 */
router.get('/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const product = await productService.getProductById(id);

    if (!product) {
      return res.status(404).json({
        status: 'error',
        message: 'Product not found'
      });
    }

    res.json({
      status: 'success',
      data: product
    });
  } catch (err) {
    console.error('Error fetching product:', err);
    res.status(500).json({
      status: 'error',
      message: err.message || 'Failed to fetch product'
    });
  }
});

/**
 * POST /products - Create new product (admin only)
 * Body: { nama, deskripsi, harga, kategori, stok, gambar }
 */
router.post('/products', authenticateToken, requireRole(['admin']), async (req, res) => {
  try {
    const { nama, deskripsi, harga, kategori, stok, gambar } = req.body;

    const productId = await productService.createProduct(
      { nama, deskripsi, harga, kategori, stok, gambar },
      req.user.id
    );

    res.status(201).json({
      status: 'success',
      message: 'Product created successfully',
      productId,
      data: await productService.getProductById(productId)
    });
  } catch (err) {
    console.error('Error creating product:', err);
    res.status(400).json({
      status: 'error',
      message: err.message || 'Failed to create product'
    });
  }
});

/**
 * PUT /products/:id - Update product (admin only)
 * Body: { nama, deskripsi, harga, kategori, stok, gambar, aktif }
 */
router.put('/products/:id', authenticateToken, requireRole(['admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    await productService.updateProduct(id, updateData);

    const updatedProduct = await productService.getProductById(id);

    res.json({
      status: 'success',
      message: 'Product updated successfully',
      data: updatedProduct
    });
  } catch (err) {
    console.error('Error updating product:', err);
    res.status(400).json({
      status: 'error',
      message: err.message || 'Failed to update product'
    });
  }
});

/**
 * DELETE /products/:id - Soft delete product (admin only)
 */
router.delete('/products/:id', authenticateToken, requireRole(['admin']), async (req, res) => {
  try {
    const { id } = req.params;

    await productService.deleteProduct(id);

    res.json({
      status: 'success',
      message: 'Product deleted successfully'
    });
  } catch (err) {
    console.error('Error deleting product:', err);
    res.status(400).json({
      status: 'error',
      message: err.message || 'Failed to delete product'
    });
  }
});

/**
 * GET /products/:id/stock - Get product stock info
 */
router.get('/products/:id/stock', async (req, res) => {
  try {
    const { id } = req.params;
    const stockInfo = await productService.getProductStock(id);

    res.json({
      status: 'success',
      data: stockInfo
    });
  } catch (err) {
    console.error('Error fetching stock:', err);
    res.status(400).json({
      status: 'error',
      message: err.message || 'Failed to fetch stock'
    });
  }
});

/**
 * POST /products/:id/stock - Update product stock (admin only)
 * Body: { quantityDelta, reason }
 */
router.post('/products/:id/stock', authenticateToken, requireRole(['admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const { quantityDelta, reason } = req.body;

    const result = await productService.updateStock(id, quantityDelta, reason || 'admin_adjustment');

    res.json({
      status: 'success',
      message: 'Stock updated successfully',
      data: result
    });
  } catch (err) {
    console.error('Error updating stock:', err);
    res.status(400).json({
      status: 'error',
      message: err.message || 'Failed to update stock'
    });
  }
});

/**
 * GET /admin/products/low-stock - Get low stock products (admin only)
 * Query params: threshold (default: 10)
 */
router.get('/admin/products/low-stock', authenticateToken, requireRole(['admin']), async (req, res) => {
  try {
    const { threshold = 10 } = req.query;
    const products = await productService.getLowStockProducts(threshold);

    res.json({
      status: 'success',
      count: products.length,
      data: products
    });
  } catch (err) {
    console.error('Error fetching low stock products:', err);
    res.status(500).json({
      status: 'error',
      message: err.message || 'Failed to fetch low stock products'
    });
  }
});

/**
 * GET /products/:id/sales - Get product sales summary (admin only)
 */
router.get('/products/:id/sales', authenticateToken, requireRole(['admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const salesData = await productService.getProductSales(id);

    res.json({
      status: 'success',
      data: salesData
    });
  } catch (err) {
    console.error('Error fetching sales data:', err);
    res.status(400).json({
      status: 'error',
      message: err.message || 'Failed to fetch sales data'
    });
  }
});

module.exports = router;
