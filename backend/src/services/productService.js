const db = require('../db');

function safeNumber(value) {
  return Number(value) || 0;
}

/**
 * Get all products with optional filters
 * @param {Object} filters - Filter criteria (kategori, search, active)
 * @returns {Array} Product list
 */
async function getProducts(filters = {}) {
  let query = 'SELECT * FROM products WHERE 1=1';
  const params = [];

  // Filter by category
  if (filters.kategori) {
    query += ' AND kategori = ?';
    params.push(filters.kategori);
  }

  // Filter by search term (name or description)
  if (filters.search) {
    query += ' AND (nama LIKE ? OR deskripsi LIKE ?)';
    params.push(`%${filters.search}%`, `%${filters.search}%`);
  }

  // Filter by active status (default: active only)
  if (filters.active === true || filters.active === undefined) {
    query += ' AND aktif = TRUE';
  } else if (filters.active === false) {
    query += ' AND aktif = FALSE';
  }

  query += ' ORDER BY kategori ASC, nama ASC';

  const [rows] = await db.query(query, params);
  return rows;
}

/**
 * Get single product by ID
 * @param {number} id - Product ID
 * @returns {Object|null} Product or null
 */
async function getProductById(id) {
  const [rows] = await db.query(
    'SELECT * FROM products WHERE id = ? AND aktif = TRUE',
    [id]
  );
  return rows[0] || null;
}

/**
 * Get all categories
 * @returns {Array} Unique categories
 */
async function getCategories() {
  const [rows] = await db.query(
    'SELECT DISTINCT kategori FROM products WHERE aktif = TRUE ORDER BY kategori ASC'
  );
  return rows.map(r => r.kategori);
}

/**
 * Create new product
 * @param {Object} productData - Product details
 * @param {number} createdBy - Admin user ID
 * @returns {number} New product ID
 */
async function createProduct(productData, createdBy) {
  const { nama, deskripsi, harga, kategori, stok, gambar } = productData;

  // Validate required fields
  if (!nama || !kategori || safeNumber(harga) <= 0 || safeNumber(stok) < 0) {
    throw new Error('Invalid product data: nama, kategori, harga (>0), stok required');
  }

  const [result] = await db.query(
    `INSERT INTO products (nama, deskripsi, harga, kategori, stok, gambar, created_by, aktif, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, TRUE, NOW())`,
    [
      nama,
      deskripsi || '',
      safeNumber(harga),
      kategori,
      safeNumber(stok),
      gambar || '',
      createdBy
    ]
  );

  return result.insertId;
}

/**
 * Update existing product
 * @param {number} id - Product ID
 * @param {Object} productData - Updated product details
 * @returns {boolean} Success
 */
async function updateProduct(id, productData) {
  const { nama, deskripsi, harga, kategori, stok, gambar, aktif } = productData;

  // Get current product to ensure it exists
  const [currentRows] = await db.query(
    'SELECT id FROM products WHERE id = ?',
    [id]
  );

  if (currentRows.length === 0) {
    throw new Error('Product not found');
  }

  // Build dynamic update query (only update provided fields)
  let updateQuery = 'UPDATE products SET updated_at = NOW()';
  const updateParams = [];

  if (nama !== undefined) {
    updateQuery += ', nama = ?';
    updateParams.push(nama);
  }
  if (deskripsi !== undefined) {
    updateQuery += ', deskripsi = ?';
    updateParams.push(deskripsi);
  }
  if (harga !== undefined) {
    if (safeNumber(harga) <= 0) throw new Error('Harga must be positive');
    updateQuery += ', harga = ?';
    updateParams.push(safeNumber(harga));
  }
  if (kategori !== undefined) {
    updateQuery += ', kategori = ?';
    updateParams.push(kategori);
  }
  if (stok !== undefined) {
    if (safeNumber(stok) < 0) throw new Error('Stok cannot be negative');
    updateQuery += ', stok = ?';
    updateParams.push(safeNumber(stok));
  }
  if (gambar !== undefined) {
    updateQuery += ', gambar = ?';
    updateParams.push(gambar);
  }
  if (aktif !== undefined) {
    updateQuery += ', aktif = ?';
    updateParams.push(aktif ? 1 : 0);
  }

  updateQuery += ' WHERE id = ?';
  updateParams.push(id);

  await db.query(updateQuery, updateParams);
  return true;
}

/**
 * Soft delete product (set aktif=FALSE)
 * @param {number} id - Product ID
 * @returns {boolean} Success
 */
async function deleteProduct(id) {
  const [result] = await db.query(
    'UPDATE products SET aktif = FALSE, updated_at = NOW() WHERE id = ?',
    [id]
  );

  if (result.affectedRows === 0) {
    throw new Error('Product not found');
  }

  return true;
}

/**
 * Update product stock (add/subtract)
 * @param {number} productId - Product ID
 * @param {number} quantityDelta - Positive to add, negative to subtract
 * @param {string} reason - Reason for stock change (sale, restock, adjustment, etc)
 * @returns {Object} {newStock, success}
 */
async function updateStock(productId, quantityDelta, reason = 'manual') {
  const delta = Math.round(safeNumber(quantityDelta)); // Ensure integer

  if (delta === 0) {
    throw new Error('Stock change must be non-zero');
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // Get current stock with lock
    const [products] = await connection.query(
      'SELECT id, stok FROM products WHERE id = ? FOR UPDATE',
      [productId]
    );

    if (products.length === 0) {
      throw new Error('Product not found');
    }

    const currentStock = safeNumber(products[0].stok);
    const newStock = currentStock + delta;

    if (newStock < 0) {
      throw new Error(`Insufficient stock: current=${currentStock}, requested=${Math.abs(delta)}`);
    }

    // Update stock
    await connection.query(
      'UPDATE products SET stok = ?, updated_at = NOW() WHERE id = ?',
      [newStock, productId]
    );

    // Log stock change (for audit trail)
    await connection.query(
      `INSERT INTO product_stock_changes (product_id, quantity_delta, stock_before, stock_after, reason, created_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [productId, delta, currentStock, newStock, reason]
    );

    await connection.commit();

    return {
      success: true,
      productId,
      stockBefore: currentStock,
      stockAfter: newStock,
      delta
    };
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}

/**
 * Get product stock info
 * @param {number} productId - Product ID
 * @returns {Object} Stock information
 */
async function getProductStock(productId) {
  const [rows] = await db.query(
    'SELECT id, nama, stok, harga, kategori FROM products WHERE id = ?',
    [productId]
  );

  if (rows.length === 0) {
    throw new Error('Product not found');
  }

  const product = rows[0];
  return {
    productId: product.id,
    nama: product.nama,
    stok: safeNumber(product.stok),
    harga: safeNumber(product.harga),
    kategori: product.kategori,
    available: safeNumber(product.stok) > 0
  };
}

/**
 * Get low stock products (admin alert)
 * @param {number} threshold - Stock level threshold (default: 10)
 * @returns {Array} Products below threshold
 */
async function getLowStockProducts(threshold = 10) {
  const [rows] = await db.query(
    `SELECT id, nama, stok, kategori, harga 
     FROM products 
     WHERE aktif = TRUE AND stok <= ?
     ORDER BY stok ASC`,
    [threshold]
  );
  return rows;
}

/**
 * Get product sales summary
 * @param {number} productId - Product ID
 * @returns {Object} Sales data
 */
async function getProductSales(productId) {
  const [rows] = await db.query(
    `SELECT 
       p.id, p.nama, 
       COUNT(poi.id) as total_orders,
       COALESCE(SUM(poi.subtotal), 0) as total_revenue,
       COALESCE(SUM(poi.jumlah), 0) as total_units_sold
     FROM products p
     LEFT JOIN product_order_items poi ON p.id = poi.product_id
     LEFT JOIN product_orders po ON poi.order_id = po.id
     WHERE p.id = ? AND po.status IN ('completed', 'pending', 'approved')
     GROUP BY p.id`,
    [productId]
  );

  if (rows.length === 0) {
    throw new Error('Product not found');
  }

  return rows[0];
}

module.exports = {
  getProducts,
  getProductById,
  getCategories,
  createProduct,
  updateProduct,
  deleteProduct,
  updateStock,
  getProductStock,
  getLowStockProducts,
  getProductSales
};
