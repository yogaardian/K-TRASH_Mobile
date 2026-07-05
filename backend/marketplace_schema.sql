-- Marketplace schema for K-TRASH
-- Run these statements in the bank_sampah database.

-- 1. Create products table
CREATE TABLE IF NOT EXISTS products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nama VARCHAR(255) NOT NULL,
  deskripsi TEXT,
  harga DECIMAL(15,2) NOT NULL,
  kategori ENUM('lokal','digital','pulsa','token_listrik','paket_data') NOT NULL DEFAULT 'lokal',
  stok INT NOT NULL DEFAULT 0,
  gambar VARCHAR(500),
  aktif BOOLEAN NOT NULL DEFAULT TRUE,
  created_by INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 2. Create product_orders table
CREATE TABLE IF NOT EXISTS product_orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  product_id INT NOT NULL,
  jumlah INT NOT NULL DEFAULT 1,
  total_harga DECIMAL(15,2) NOT NULL,
  status ENUM('pending','processing','completed','cancelled') NOT NULL DEFAULT 'pending',
  catatan TEXT,
  processed_by INT,
  processed_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  FOREIGN KEY (processed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 3. Create product_order_items table (for future extensibility)
CREATE TABLE IF NOT EXISTS product_order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  jumlah INT NOT NULL,
  harga_satuan DECIMAL(15,2) NOT NULL,
  subtotal DECIMAL(15,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES product_orders(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4. Seed initial products
INSERT INTO products (nama, deskripsi, harga, kategori, stok, gambar, aktif) VALUES
('Tepung Beras 500G', 'Tepung beras berkualitas tinggi dari padi pilihan', 15000, 'lokal', 50, 'https://images.unsplash.com/photo-1585707572336-c9b5b0e5e1f0?w=500&h=300&fit=crop', TRUE),
('Indomilk Coklat 545 G', 'Minuman coklat siap minum dengan rasa coklat yang lezat', 13000, 'lokal', 87, 'https://images.unsplash.com/photo-1599599810694-b5ac4dd0ea1f?w=500&h=300&fit=crop', TRUE),
('Indomilk Putih 545 G', 'Minuman putih siap minum dengan nutrisi lengkap', 13000, 'lokal', 88, 'https://images.unsplash.com/photo-1599599810508-fb5e8e1e5f0a?w=500&h=300&fit=crop', TRUE),
('Gula 1 KG', 'Gula kristal putih berkualitas premium', 20000, 'lokal', 87, 'https://images.unsplash.com/photo-1599599810962-e5e5e5e5e5e5?w=500&h=300&fit=crop', TRUE),
('Kecap 550 ML', 'Kecap manis dengan rasa gurih yang kaya', 12000, 'lokal', 60, 'https://images.unsplash.com/photo-1585707572336-c9b5b0e5e1f0?w=500&h=300&fit=crop', TRUE),
('Mie Sedaap Goreng 6pcs', 'Paket mie instan goreng sedaap dengan 6 bungkus', 22000, 'lokal', 100, 'https://images.unsplash.com/photo-1599599810962-e5e5e5e5e5e5?w=500&h=300&fit=crop', TRUE),
('Beras 5 KG', 'Beras premium pilihan untuk keluarga', 54000, 'lokal', 40, 'https://images.unsplash.com/photo-1585707572336-c9b5b0e5e1f1?w=500&h=300&fit=crop', TRUE),
('Tepung Terigu 1 KG', 'Tepung terigu protein tinggi untuk kue dan roti', 12000, 'lokal', 75, 'https://images.unsplash.com/photo-1599599810962-e5e5e5e5e5e5?w=500&h=300&fit=crop', TRUE),
('Telur 1 KG', 'Telur ayam segar grade A berkualitas tinggi', 28000, 'lokal', 45, 'https://images.unsplash.com/photo-1585707572336-c9b5b0e5e1f2?w=500&h=300&fit=crop', TRUE),
('Minyak Goreng 2L', 'Minyak goreng premium untuk masak sehari-hari', 35000, 'lokal', 60, 'https://images.unsplash.com/photo-1599599810508-fb5e8e1e5f0a?w=500&h=300&fit=crop', TRUE);