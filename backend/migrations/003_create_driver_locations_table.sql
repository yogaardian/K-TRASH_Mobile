-- Migration: Create driver_locations table
-- Date: 2026-07-06
-- Purpose: Store real-time driver location updates for order tracking

CREATE TABLE IF NOT EXISTS driver_locations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  driver_id INT NOT NULL,
  order_id INT NOT NULL,
  lat DECIMAL(10, 8) NOT NULL COMMENT 'Latitude coordinate',
  lng DECIMAL(11, 8) NOT NULL COMMENT 'Longitude coordinate',
  accuracy DECIMAL(8, 2) DEFAULT NULL COMMENT 'GPS accuracy in meters',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Indexes for common queries
  INDEX idx_order_id (order_id),
  INDEX idx_driver_id (driver_id),
  INDEX idx_driver_order (driver_id, order_id),
  INDEX idx_created_at (created_at),
  
  -- Foreign keys
  CONSTRAINT fk_driver_locations_driver 
    FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_driver_locations_order 
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Create index for finding latest location per order
CREATE INDEX idx_driver_locations_order_recent 
  ON driver_locations(order_id, created_at DESC);
