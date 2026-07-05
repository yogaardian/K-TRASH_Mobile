require('dotenv').config();
const mysql = require('mysql2/promise');
const { URL } = require('url');

const databaseUrl = process.env.DATABASE_URL;
let dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'bank_sampah',
  port: Number(process.env.DB_PORT) || 3306,
  waitForConnections: true,
  connectionLimit: Number(process.env.DB_CONNECTION_LIMIT) || 10,
  queueLimit: Number(process.env.DB_QUEUE_LIMIT) || 0,
};

if (databaseUrl) {
  const parsed = new URL(databaseUrl);
  dbConfig = {
    ...dbConfig,
    host: parsed.hostname,
    user: parsed.username,
    password: parsed.password,
    database: parsed.pathname ? parsed.pathname.slice(1) : dbConfig.database,
    port: Number(parsed.port) || dbConfig.port,
  };
}

const pool = mysql.createPool(dbConfig);

// Log the resolved DB config at startup (omit password)
try {
  const { host, user, database, port } = dbConfig;
  console.log('DB config resolved:', { host, user, database, port });
} catch (e) {
  console.warn('Could not log DB config:', e && e.message);
}

pool.on('error', (err) => {
  console.error('DB pool error', err);
});

module.exports = pool;