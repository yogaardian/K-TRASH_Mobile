-- SQL schema for K-TRASH digital saldo system
-- Run these statements in the bank_sampah database.

-- 1. Update users table to store saldo and saldo_hold
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS saldo DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER role,
  ADD COLUMN IF NOT EXISTS saldo_hold DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER saldo,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER saldo_hold;

-- 2. Make sure orders status enum supports approval flow
ALTER TABLE orders
  MODIFY COLUMN status ENUM('pending','searching_driver','assigned','on_the_way','arrived','completed','cancelled','approved','rejected')
  COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'pending';

-- 3. Create app_settings table for global configuration
CREATE TABLE IF NOT EXISTS app_settings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  setting_key VARCHAR(100) UNIQUE NOT NULL,
  setting_value TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4. Seed minimum hold balance
INSERT INTO app_settings (setting_key, setting_value)
VALUES ('minimum_hold_balance', '50000')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 5. Create saldo_transactions table for pending/approved/rejected saldo mutations
CREATE TABLE IF NOT EXISTS saldo_transactions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  order_id INT NULL,
  type ENUM('waste_income','topup_manual','withdraw','adjustment','penalty') NOT NULL,
  amount DECIMAL(15,2) NOT NULL,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  description TEXT NULL,
  created_by INT NULL,
  approved_by INT NULL,
  approved_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 6. Backfill existing user hold balances using the default minimum hold
UPDATE users
SET saldo_hold = LEAST(saldo, 50000)
WHERE saldo_hold = 0;
