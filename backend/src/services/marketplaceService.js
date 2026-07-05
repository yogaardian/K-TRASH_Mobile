const db = require('../db');
const walletService = require('./walletService');

function safeNumber(value) {
  return Number(value) || 0;
}

async function getProducts(filters = {}) {
  let query = 'SELECT * FROM products WHERE aktif = TRUE';
  const params = [];

  if (filters.kategori) {
    query += ' AND kategori = ?';
    params.push(filters.kategori);
  }

  if (filters.search) {
    query += ' AND (nama LIKE ? OR deskripsi LIKE ?)';
    params.push(`%${filters.search}%`, `%${filters.search}%`);
  }

  query += ' ORDER BY created_at DESC';

  const [rows] = await db.query(query, params);
  return rows;
}

async function getProductById(id) {
  const [rows] = await db.query('SELECT * FROM products WHERE id = ? AND aktif = TRUE', [id]);
  return rows[0] || null;
}

async function createProduct(productData, createdBy) {
  const { nama, deskripsi, harga, kategori, stok, gambar } = productData;

  const [result] = await db.query(
    `INSERT INTO products (nama, deskripsi, harga, kategori, stok, gambar, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [nama, deskripsi || '', safeNumber(harga), kategori, safeNumber(stok), gambar || '', createdBy]
  );

  return result.insertId;
}

async function updateProduct(id, productData) {
  const { nama, deskripsi, harga, kategori, stok, gambar, aktif } = productData;

  await db.query(
    `UPDATE products SET
     nama = ?, deskripsi = ?, harga = ?, kategori = ?, stok = ?, gambar = ?, aktif = ?,
     updated_at = CURRENT_TIMESTAMP
     WHERE id = ?`,
    [nama, deskripsi || '', safeNumber(harga), kategori, safeNumber(stok), gambar || '', aktif ? 1 : 0, id]
  );

  return true;
}

async function deleteProduct(id) {
  await db.query('UPDATE products SET aktif = FALSE WHERE id = ?', [id]);
  return true;
}

async function createProductOrder(userId, productId, jumlah, catatan = '') {
  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    // ========== GET & LOCK PRODUCT ==========
    const [products] = await connection.query(
      'SELECT id, nama, harga, stok FROM products WHERE id = ? AND aktif = TRUE FOR UPDATE',
      [productId]
    );
    if (products.length === 0) {
      throw new Error('Product not found');
    }

    const product = products[0];
    if (product.stok < jumlah) {
      throw new Error('Insufficient stock');
    }

    const totalHarga = safeNumber(product.harga) * safeNumber(jumlah);

    // ========== CHECK USER BALANCE ==========
    const [users] = await connection.query(
      'SELECT saldo, saldo_hold FROM users WHERE id = ? FOR UPDATE',
      [userId]
    );
    if (users.length === 0) {
      throw new Error('User not found');
    }

    const user = users[0];
    const availableBalance = safeNumber(user.saldo) - safeNumber(user.saldo_hold);

    if (availableBalance < totalHarga) {
      throw new Error('Insufficient balance');
    }

    // Release lock before executing wallet transaction
    // (to prevent lock timeout on nested connection)
    await connection.commit();
    connection.release();

    // ========== DEDUCT THROUGH WALLET SERVICE (Centralized) ==========
    // This ensures all saldo mutations go through walletService
    const transactionReference = `marketplace_${userId}_${productId}_${Date.now()}`;
    const walletResult = await walletService.executeTransaction({
      userId,
      amount: -totalHarga, // negative = debit
      type: 'marketplace_purchase',
      transactionReference,
      sourceType: 'product_order',
      sourceId: productId,
      description: `Purchase: ${product.nama} x${jumlah}`,
      createdBy: userId, // user initiated this
    });

    // ========== NOW UPDATE INVENTORY & CREATE ORDERS ==========
    // Use fresh connection for these operations
    const connection2 = await db.getConnection();
    try {
      await connection2.beginTransaction();

      // Reduce stock with safety check to prevent race conditions
      const [stockResult] = await connection2.query(
        'UPDATE products SET stok = stok - ? WHERE id = ? AND stok >= ?',
        [jumlah, productId, jumlah]
      );

      if (stockResult.affectedRows === 0) {
        throw new Error('Stock tidak mencukupi saat finalisasi pesanan');
      }

      // Create product order with completed status because saldo sudah dibayarkan
      const [orderResult] = await connection2.query(
        `INSERT INTO product_orders (user_id, product_id, jumlah, total_harga, status, catatan, processed_by, processed_at, transaction_id)
         VALUES (?, ?, ?, ?, 'completed', ?, ?, NOW(), ?)`,
        [userId, productId, jumlah, totalHarga, catatan, userId, walletResult.transactionId]
      );

      // Create order item
      await connection2.query(
        `INSERT INTO product_order_items (order_id, product_id, jumlah, harga_satuan, subtotal)
         VALUES (?, ?, ?, ?, ?)`,
        [orderResult.insertId, productId, jumlah, product.harga, totalHarga]
      );

      await connection2.commit();

      return {
        orderId: orderResult.insertId,
        totalHarga,
        newBalance: walletResult.balanceAfter,
        transactionId: walletResult.transactionId,
      };
    } catch (err) {
      await connection2.rollback();

      // If the order failed after the wallet debit, reverse the transaction so user funds remain consistent.
      if (walletResult && walletResult.transactionId) {
        try {
          const reversalReference = `product_order_reversal_${userId}_${productId}_${Date.now()}`;
          await walletService.executeTransaction({
            userId,
            amount: safeNumber(totalHarga),
            type: 'marketplace_order_reversal',
            transactionReference: reversalReference,
            sourceType: 'product_order_reversal',
            sourceId: null,
            description: `Rollback pembelian ${product.nama} x${jumlah}`,
            createdBy: userId,
          });
        } catch (refundError) {
          console.error('Gagal mengembalikan saldo setelah kegagalan order:', refundError);
        }
      }

      throw err;
    } finally {
      connection2.release();
    }
  } catch (err) {
    await connection.rollback();
    throw err;
  }
}

async function getUserProductOrders(userId) {
  const [rows] = await db.query(
    `SELECT po.*, p.nama as product_name, p.gambar as product_image
     FROM product_orders po
     JOIN products p ON po.product_id = p.id
     WHERE po.user_id = ?
     ORDER BY po.created_at DESC`,
    [userId]
  );

  return rows;
}

async function getAllProductOrders() {
  const [rows] = await db.query(
    `SELECT po.*, p.nama as product_name, p.gambar as product_image,
            u.nama as user_name, u.email as user_email
     FROM product_orders po
     JOIN products p ON po.product_id = p.id
     JOIN users u ON po.user_id = u.id
     ORDER BY po.created_at DESC`
  );

  return rows;
}

async function updateProductOrderStatus(orderId, status, processedBy) {
  const validStatuses = ['pending', 'processing', 'completed', 'cancelled'];

  if (!validStatuses.includes(status)) {
    throw new Error('Invalid status');
  }

  await db.query(
    `UPDATE product_orders SET status = ?, processed_by = ?, processed_at = CURRENT_TIMESTAMP
     WHERE id = ?`,
    [status, processedBy, orderId]
  );

  return true;
}

/**
 * Process marketplace refund via reversal transaction
 * @param {number} orderId - Product order ID to refund
 * @param {number} adminId - Admin user ID processing refund
 * @param {string} reason - Reason for refund
 * @returns {Object} Refund result with new balance
 */
async function refundProductOrder(orderId, adminId, reason = 'Admin refund') {
  // Get order details
  const [orderRows] = await db.query(
    `SELECT po.id, po.user_id, po.product_id, po.total_harga, po.jumlah, po.status,
            p.nama as product_name, po.transaction_id
     FROM product_orders po
     JOIN products p ON po.product_id = p.id
     WHERE po.id = ?`,
    [orderId]
  );

  if (orderRows.length === 0) {
    throw new Error('Order not found');
  }

  const order = orderRows[0];

  // Only allow refund for completed or cancelled orders
  if (!['completed', 'cancelled', 'pending'].includes(order.status)) {
    throw new Error(`Cannot refund order with status: ${order.status}`);
  }

  // Check if already refunded
  const [existingRefund] = await db.query(
    `SELECT id FROM saldo_transactions 
     WHERE source_type = 'product_refund' AND source_id = ? LIMIT 1`,
    [orderId]
  );

  if (existingRefund.length > 0) {
    throw new Error('Order already refunded');
  }

  // Generate unique reference for refund reversal
  const transactionReference = `refund_${orderId}_${adminId}_${Date.now()}`;

  // Execute refund through walletService (positive amount = credit)
  const walletResult = await walletService.executeTransaction({
    userId: order.user_id,
    amount: safeNumber(order.total_harga), // positive = credit (refund)
    type: 'marketplace_refund',
    transactionReference,
    sourceType: 'product_refund',
    sourceId: orderId,
    description: `Refund: ${order.product_name} x${order.jumlah}. Reason: ${reason}`,
    createdBy: adminId
  });

  // Update order status to refunded
  await db.query(
    'UPDATE product_orders SET status = ?, refunded_at = NOW(), refunded_by = ? WHERE id = ?',
    ['refunded', adminId, orderId]
  );

  // Restore stock
  await db.query(
    'UPDATE products SET stok = stok + ? WHERE id = ?',
    [order.jumlah, order.product_id]
  );

  // Log refund in stock changes
  await db.query(
    `INSERT INTO product_stock_changes (product_id, quantity_delta, stock_before, stock_after, reason, created_at)
     VALUES (?, ?, ?, ?, ?, NOW())`,
    [order.product_id, order.jumlah, 0, order.jumlah, `refund_order_${orderId}`]
  );

  return {
    success: true,
    orderId,
    userId: order.user_id,
    refundAmount: order.total_harga,
    newBalance: walletResult.balanceAfter,
    availableBalance: walletResult.availableAfter,
    transactionId: walletResult.transactionId,
    reason
  };
}

/**
 * Get user purchase history with detailed info
 * @param {number} userId - User ID
 * @param {Object} filters - Filter options (status, limit, offset)
 * @returns {Array} Purchase history
 */
async function getUserPurchaseHistory(userId, filters = {}) {
  const { status, limit = 50, offset = 0 } = filters;

  let query = `
    SELECT 
      po.id, po.user_id, po.product_id, po.jumlah, po.total_harga,
      po.status, po.catatan, po.created_at, po.processed_at, po.refunded_at,
      p.nama as product_name, p.kategori, p.gambar as product_image,
      st.id as transaction_id, st.balance_before, st.balance_after
    FROM product_orders po
    JOIN products p ON po.product_id = p.id
    LEFT JOIN saldo_transactions st ON po.transaction_id = st.id
    WHERE po.user_id = ?
  `;

  const params = [userId];

  if (status) {
    query += ' AND po.status = ?';
    params.push(status);
  }

  query += ' ORDER BY po.created_at DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const [rows] = await db.query(query, params);
  return rows;
}

/**
 * Get marketplace statistics for admin
 * @returns {Object} Marketplace stats
 */
async function getMarketplaceStats() {
  const [stats] = await db.query(`
    SELECT
      COUNT(DISTINCT po.id) as total_orders,
      COUNT(DISTINCT po.user_id) as unique_buyers,
      COALESCE(SUM(po.total_harga), 0) as total_revenue,
      COALESCE(SUM(CASE WHEN po.status = 'completed' THEN po.total_harga ELSE 0 END), 0) as completed_revenue,
      COALESCE(SUM(CASE WHEN po.status = 'pending' THEN po.total_harga ELSE 0 END), 0) as pending_revenue,
      COALESCE(SUM(CASE WHEN po.status = 'refunded' THEN po.total_harga ELSE 0 END), 0) as refunded_amount,
      COUNT(CASE WHEN po.status = 'completed' THEN 1 END) as completed_count,
      COUNT(CASE WHEN po.status = 'pending' THEN 1 END) as pending_count,
      COUNT(CASE WHEN po.status = 'refunded' THEN 1 END) as refunded_count
    FROM product_orders po
  `);

  return stats[0];
}

/**
 * Get pending orders for admin processing
 * @param {Object} filters - Filter options (limit, offset)
 * @returns {Array} Pending orders
 */
async function getPendingOrders(filters = {}) {
  const { limit = 50, offset = 0 } = filters;

  const [rows] = await db.query(`
    SELECT 
      po.id, po.user_id, po.product_id, po.jumlah, po.total_harga,
      po.status, po.catatan, po.created_at,
      p.nama as product_name, p.kategori, p.harga,
      u.nama as user_name, u.email as user_email
    FROM product_orders po
    JOIN products p ON po.product_id = p.id
    JOIN users u ON po.user_id = u.id
    WHERE po.status = 'pending'
    ORDER BY po.created_at ASC
    LIMIT ? OFFSET ?
  `, [limit, offset]);

  return rows;
}

/**
 * Get single product order with full details
 * @param {number} orderId - Product order ID
 * @returns {Object} Order details
 */
async function getProductOrder(orderId) {
  const [rows] = await db.query(`
    SELECT 
      po.id, po.user_id, po.product_id, po.jumlah, po.total_harga,
      po.status, po.catatan, po.created_at, po.processed_at, po.refunded_at,
      p.nama as product_name, p.kategori, p.harga, p.gambar,
      u.nama as user_name, u.email as user_email, u.saldo,
      st.id as transaction_id, st.balance_before, st.balance_after
    FROM product_orders po
    JOIN products p ON po.product_id = p.id
    JOIN users u ON po.user_id = u.id
    LEFT JOIN saldo_transactions st ON po.transaction_id = st.id
    WHERE po.id = ?
  `, [orderId]);

  if (rows.length === 0) {
    throw new Error('Order not found');
  }

  return rows[0];
}

/**
 * Mark order as completed (admin action)
 * @param {number} orderId - Product order ID
 * @param {number} adminId - Admin user ID
 * @returns {boolean} Success
 */
async function completeProductOrder(orderId, adminId) {
  const order = await getProductOrder(orderId);

  if (order.status !== 'pending') {
    throw new Error(`Cannot complete order with status: ${order.status}`);
  }

  await db.query(
    `UPDATE product_orders 
     SET status = 'completed', processed_by = ?, processed_at = NOW()
     WHERE id = ?`,
    [adminId, orderId]
  );

  return true;
}

/**
 * Cancel order and reverse transaction (admin action)
 * @param {number} orderId - Product order ID
 * @param {number} adminId - Admin user ID
 * @param {string} reason - Reason for cancellation
 * @returns {Object} Cancellation result
 */
async function cancelProductOrder(orderId, adminId, reason = 'Admin cancellation') {
  const order = await getProductOrder(orderId);

  // Only allow cancelling pending orders
  if (order.status !== 'pending') {
    throw new Error(`Cannot cancel order with status: ${order.status}`);
  }

  // Check if already has reversal
  const [existingReversal] = await db.query(
    `SELECT id FROM saldo_transactions 
     WHERE source_type = 'product_order_reversal' AND source_id = ? LIMIT 1`,
    [orderId]
  );

  if (existingReversal.length > 0) {
    throw new Error('Order already cancelled');
  }

  // Generate unique reference for order cancellation
  const transactionReference = `cancel_order_${orderId}_${adminId}_${Date.now()}`;

  // Reverse the transaction (credit back to user)
  const walletResult = await walletService.executeTransaction({
    userId: order.user_id,
    amount: safeNumber(order.total_harga), // positive = credit
    type: 'marketplace_order_reversal',
    transactionReference,
    sourceType: 'product_order_reversal',
    sourceId: orderId,
    description: `Order cancellation: ${order.product_name} x${order.jumlah}. Reason: ${reason}`,
    createdBy: adminId
  });

  // Update order status
  await db.query(
    `UPDATE product_orders 
     SET status = 'cancelled', processed_by = ?, processed_at = NOW()
     WHERE id = ?`,
    [adminId, orderId]
  );

  // Restore stock
  await db.query(
    'UPDATE products SET stok = stok + ? WHERE id = ?',
    [order.jumlah, order.product_id]
  );

  return {
    success: true,
    orderId,
    userId: order.user_id,
    refundAmount: order.total_harga,
    newBalance: walletResult.balanceAfter,
    reason
  };
}

module.exports = {
  getProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
  createProductOrder,
  getUserProductOrders,
  getAllProductOrders,
  updateProductOrderStatus,
  refundProductOrder,
  getUserPurchaseHistory,
  getMarketplaceStats,
  getPendingOrders,
  getProductOrder,
  completeProductOrder,
  cancelProductOrder
};