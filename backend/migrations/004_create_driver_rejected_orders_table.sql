-- Migration: Create driver_rejected_orders table
-- Date: 2026-07-06
-- Purpose: Track which orders drivers have rejected to prevent duplicate rejections

CREATE TABLE IF NOT EXISTS driver_rejected_orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  driver_id INT NOT NULL,
  order_id INT NOT NULL,
  reason VARCHAR(255) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Ensure one rejection per driver per order
  UNIQUE KEY unique_driver_order (driver_id, order_id),
  
  -- Indexes
  INDEX idx_driver_id (driver_id),
  INDEX idx_order_id (order_id),
  INDEX idx_created_at (created_at),
  
  -- Foreign keys
  CONSTRAINT fk_rejected_driver 
    FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_rejected_order 
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
