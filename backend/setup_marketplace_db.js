const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mysql = require('mysql2/promise');

async function main() {
  const dbName = process.env.DB_NAME || 'bank_sampah';
  const host = process.env.DB_HOST || 'localhost';
  const user = process.env.DB_USER || 'root';
  const password = process.env.DB_PASSWORD || '';
  const port = Number(process.env.DB_PORT) || 3306;

  const rootConnection = await mysql.createConnection({ host, user, password, port });
  await rootConnection.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci`);
  console.log(`Database ${dbName} ensured.`);
  await rootConnection.end();

  const db = await mysql.createConnection({ host, user, password, database: dbName, port });

  const createStatements = [
    `CREATE TABLE IF NOT EXISTS products (
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
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;`,

    `CREATE TABLE IF NOT EXISTS product_orders (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      product_id INT NOT NULL,
      jumlah INT NOT NULL DEFAULT 1,
      total_harga DECIMAL(15,2) NOT NULL,
      transaction_id INT NULL,
      status ENUM('pending','processing','completed','cancelled','refunded') NOT NULL DEFAULT 'pending',
      catatan TEXT,
      processed_by INT NULL,
      processed_at TIMESTAMP NULL,
      refunded_by INT NULL,
      refunded_at TIMESTAMP NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
      FOREIGN KEY (transaction_id) REFERENCES saldo_transactions(id) ON DELETE SET NULL,
      FOREIGN KEY (processed_by) REFERENCES users(id) ON DELETE SET NULL,
      FOREIGN KEY (refunded_by) REFERENCES users(id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;`,

    `CREATE TABLE IF NOT EXISTS product_order_items (
      id INT AUTO_INCREMENT PRIMARY KEY,
      order_id INT NOT NULL,
      product_id INT NOT NULL,
      jumlah INT NOT NULL,
      harga_satuan DECIMAL(15,2) NOT NULL,
      subtotal DECIMAL(15,2) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (order_id) REFERENCES product_orders(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;`,

    `CREATE TABLE IF NOT EXISTS product_stock_changes (
      id INT AUTO_INCREMENT PRIMARY KEY,
      product_id INT NOT NULL,
      quantity_delta INT NOT NULL,
      stock_before INT NOT NULL,
      stock_after INT NOT NULL,
      reason VARCHAR(100) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (product_id) REFERENCES products(id),
      INDEX idx_product_id (product_id),
      INDEX idx_created_at (created_at),
      INDEX idx_product_date (product_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;`,
  ];

  for (const sql of createStatements) {
    await db.query(sql);
  }

  const [productCount] = await db.query('SELECT COUNT(*) AS count FROM products');
  if (productCount[0].count === 0) {
    const defaultProducts = [
      { nama: 'Beras', deskripsi: 'Beras premium 5kg untuk kebutuhan rumah tangga.', harga: 20000, kategori: 'lokal', stok: 100 },
      { nama: 'Minyak', deskripsi: 'Minyak goreng kemasan 1 liter, siap pakai.', harga: 18000, kategori: 'lokal', stok: 100 },
      { nama: 'Telur', deskripsi: 'Telur ayam segar isi 10 butir.', harga: 22000, kategori: 'lokal', stok: 100 },
    ];

    for (const product of defaultProducts) {
      await db.query(
        'INSERT INTO products (nama, deskripsi, harga, kategori, stok, aktif) VALUES (?, ?, ?, ?, ?, TRUE)',
        [product.nama, product.deskripsi, product.harga, product.kategori, product.stok]
      );
    }
    console.log('Seeded default marketplace products.');
  } else {
    console.log('Marketplace products already seeded.');
  }

  console.log('Marketplace database setup complete.');
  await db.end();
}

main().catch((err) => {
  console.error('Marketplace DB setup failed:', err);
  process.exit(1);
});
