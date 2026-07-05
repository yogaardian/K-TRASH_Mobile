-- PHASE 2: Marketplace CRUD & Enhanced Purchase Flow
-- Database Schema Migrations

-- ============================================
-- TABLE: product_stock_changes (NEW)
-- Purpose: Audit trail for stock movements
-- ============================================
CREATE TABLE IF NOT EXISTS product_stock_changes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  quantity_delta INT NOT NULL COMMENT 'Positive for restock, negative for sales',
  stock_before INT NOT NULL,
  stock_after INT NOT NULL,
  reason VARCHAR(100) NOT NULL COMMENT 'sale, restock, adjustment, refund_order, etc',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (product_id) REFERENCES products(id),
  INDEX idx_product_id (product_id),
  INDEX idx_created_at (created_at),
  INDEX idx_product_date (product_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- VERIFY: product_orders TABLE (should exist)
-- Expected columns for PHASE 2:
-- ============================================
-- id (PK)
-- user_id (FK to users)
-- product_id (FK to products)
-- jumlah (quantity)
-- total_harga (total price)
-- status (pending, processing, completed, cancelled, refunded)
-- transaction_id (FK to saldo_transactions - for audit trail)
-- catatan (customer notes)
-- created_at
-- processed_by (admin ID who processed)
-- processed_at (when processed)
-- refunded_by (admin ID who refunded)
-- refunded_at (when refunded)

-- Add missing columns if they don't exist:
ALTER TABLE product_orders 
ADD COLUMN IF NOT EXISTS transaction_id INT COMMENT 'Link to saldo_transactions for audit trail',
ADD COLUMN IF NOT EXISTS processed_by INT COMMENT 'Admin user ID who processed order',
ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP NULL COMMENT 'When order was processed',
ADD COLUMN IF NOT EXISTS refunded_by INT COMMENT 'Admin user ID who refunded',
ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMP NULL COMMENT 'When refund occurred';

-- Add foreign key constraint for transaction_id (if not exists)
ALTER TABLE product_orders
ADD CONSTRAINT fk_product_orders_transaction 
  FOREIGN KEY (transaction_id) REFERENCES saldo_transactions(id) 
  ON DELETE SET NULL;

-- Add index for common queries
ALTER TABLE product_orders
ADD INDEX IF NOT EXISTS idx_user_status (user_id, status),
ADD INDEX IF NOT EXISTS idx_status_created (status, created_at),
ADD INDEX IF NOT EXISTS idx_transaction_id (transaction_id);

-- ============================================
-- VERIFY: product_order_items TABLE (should exist)
-- Expected columns:
-- ============================================
-- id (PK)
-- order_id (FK to product_orders)
-- product_id (FK to products)
-- jumlah (quantity)
-- harga_satuan (unit price at time of purchase)
-- subtotal (jumlah * harga_satuan)

-- Add index for common queries if not exists
ALTER TABLE product_order_items
ADD INDEX IF NOT EXISTS idx_order_id (order_id),
ADD INDEX IF NOT EXISTS idx_product_id (product_id);

-- ============================================
-- VERIFY: products TABLE (must have)
-- Expected columns:
-- ============================================
-- id (PK)
-- nama (product name)
-- deskripsi (description)
-- harga (price)
-- kategori (category)
-- stok (current stock quantity)
-- gambar (image URL)
-- aktif (soft delete flag: 1 or 0)
-- created_by (admin ID who created)
-- created_at
-- updated_at

-- Add missing columns if needed
ALTER TABLE products
ADD COLUMN IF NOT EXISTS aktif BOOLEAN DEFAULT TRUE COMMENT 'Soft delete flag',
ADD COLUMN IF NOT EXISTS created_by INT COMMENT 'Admin user ID who created product',
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- Add indexes for performance
ALTER TABLE products
ADD INDEX IF NOT EXISTS idx_kategori (kategori),
ADD INDEX IF NOT EXISTS idx_aktif (aktif),
ADD INDEX IF NOT EXISTS idx_kategori_aktif (kategori, aktif),
ADD INDEX IF NOT EXISTS idx_nama (nama);

-- ============================================
-- VERIFY: saldo_transactions TABLE (must have - PHASE 1)
-- Expected columns for PHASE 2:
-- ============================================
-- All PHASE 1 columns plus:
-- source_type (should be: admin_topup, saldo_transaction, product_order, product_refund, product_order_reversal, etc)
-- source_id (ID of the source record)

-- These should already exist from PHASE 1 migration
-- If not, run wallet_migration.js first

-- ============================================
-- CLEANUP & VERIFICATION
-- ============================================

-- Verify all required tables exist
SELECT 
  't1' as table_name,
  'products' as table_name FROM information_schema.TABLES WHERE TABLE_NAME='products' AND TABLE_SCHEMA=DATABASE()
UNION ALL
SELECT 'product_orders' FROM information_schema.TABLES WHERE TABLE_NAME='product_orders' AND TABLE_SCHEMA=DATABASE()
UNION ALL
SELECT 'product_order_items' FROM information_schema.TABLES WHERE TABLE_NAME='product_order_items' AND TABLE_SCHEMA=DATABASE()
UNION ALL
SELECT 'saldo_transactions' FROM information_schema.TABLES WHERE TABLE_NAME='saldo_transactions' AND TABLE_SCHEMA=DATABASE()
UNION ALL
SELECT 'users' FROM information_schema.TABLES WHERE TABLE_NAME='users' AND TABLE_SCHEMA=DATABASE();

-- Verify key columns in saldo_transactions
SELECT COLUMN_NAME FROM information_schema.COLUMNS 
WHERE TABLE_NAME='saldo_transactions' 
AND TABLE_SCHEMA=DATABASE() 
AND COLUMN_NAME IN ('transaction_reference', 'balance_before', 'balance_after', 'source_type', 'source_id');
