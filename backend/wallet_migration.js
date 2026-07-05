/**
 * WALLET SERVICE DATABASE MIGRATION
 * PHASE 1: Add transaction_reference, balance tracking, and audit fields
 * 
 * Run this ONCE to upgrade schema:
 * node wallet_migration.js
 * 
 * Safe to run multiple times (uses IF NOT EXISTS)
 */

const mysql = require('mysql2/promise');
const fs = require('fs');
require('dotenv').config();

async function runMigration() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'bank_sampah',
  });

  try {
    console.log('[MIGRATION] Starting wallet service schema upgrade...\n');

    // ========== ALTER 1: Add transaction_reference column ==========
    console.log('[1/5] Adding transaction_reference column...');
    try {
      await connection.execute(
        `ALTER TABLE saldo_transactions 
         ADD COLUMN transaction_reference VARCHAR(255) UNIQUE AFTER id`,
      );
      console.log('     ✓ transaction_reference added (with UNIQUE constraint)');
    } catch (err) {
      if (err.code === 'ER_DUPLICATE_COLUMN_NAME') {
        console.log('     ✓ transaction_reference already exists');
      } else {
        throw err;
      }
    }

    // ========== ALTER 2: Add balance_before column ==========
    console.log('[2/5] Adding balance_before column...');
    try {
      await connection.execute(
        `ALTER TABLE saldo_transactions 
         ADD COLUMN balance_before DECIMAL(15,2) AFTER amount`,
      );
      console.log('     ✓ balance_before added');
    } catch (err) {
      if (err.code === 'ER_DUPLICATE_COLUMN_NAME') {
        console.log('     ✓ balance_before already exists');
      } else {
        throw err;
      }
    }

    // ========== ALTER 3: Add balance_after column ==========
    console.log('[3/5] Adding balance_after column...');
    try {
      await connection.execute(
        `ALTER TABLE saldo_transactions 
         ADD COLUMN balance_after DECIMAL(15,2) AFTER balance_before`,
      );
      console.log('     ✓ balance_after added');
    } catch (err) {
      if (err.code === 'ER_DUPLICATE_COLUMN_NAME') {
        console.log('     ✓ balance_after already exists');
      } else {
        throw err;
      }
    }

    // ========== ALTER 4: Add source_type column ==========
    console.log('[4/5] Adding source_type column...');
    try {
      await connection.execute(
        `ALTER TABLE saldo_transactions 
         ADD COLUMN source_type VARCHAR(50) AFTER balance_after`,
      );
      console.log('     ✓ source_type added');
    } catch (err) {
      if (err.code === 'ER_DUPLICATE_COLUMN_NAME') {
        console.log('     ✓ source_type already exists');
      } else {
        throw err;
      }
    }

    // ========== ALTER 5: Add source_id column ==========
    console.log('[5/5] Adding source_id column...');
    try {
      await connection.execute(
        `ALTER TABLE saldo_transactions 
         ADD COLUMN source_id INT AFTER source_type`,
      );
      console.log('     ✓ source_id added');
    } catch (err) {
      if (err.code === 'ER_DUPLICATE_COLUMN_NAME') {
        console.log('     ✓ source_id already exists');
      } else {
        throw err;
      }
    }

    // ========== ALTER 6: Add approved_at column ==========
    console.log('[6/6] Adding approved_at column...');
    try {
      await connection.execute(
        `ALTER TABLE saldo_transactions 
         ADD COLUMN approved_at TIMESTAMP NULL AFTER approved_by`,
      );
      console.log('     ✓ approved_at added');
    } catch (err) {
      if (err.code === 'ER_DUPLICATE_COLUMN_NAME') {
        console.log('     ✓ approved_at already exists');
      } else {
        throw err;
      }
    }

    // ========== CREATE INDEX ==========
    console.log('[+] Creating indexes for performance...');
    try {
      await connection.execute(
        `CREATE INDEX idx_saldo_txn_reference 
         ON saldo_transactions(transaction_reference)`,
      );
      console.log('     ✓ Index on transaction_reference created');
    } catch (err) {
      if (err.code === 'ER_DUP_KEYNAME') {
        console.log('     ✓ Index already exists');
      } else {
        throw err;
      }
    }

    try {
      await connection.execute(
        `CREATE INDEX idx_saldo_txn_user_created 
         ON saldo_transactions(user_id, created_at)`,
      );
      console.log('     ✓ Index on user_id, created_at created');
    } catch (err) {
      if (err.code === 'ER_DUP_KEYNAME') {
        console.log('     ✓ Index already exists');
      } else {
        throw err;
      }
    }

    console.log('\n✅ MIGRATION COMPLETE - Schema upgraded successfully!');
    console.log('\nNew columns:');
    console.log('  - transaction_reference: Idempotency key (UNIQUE)');
    console.log('  - balance_before: Audit trail (balance before mutation)');
    console.log('  - balance_after: Audit trail (balance after mutation)');
    console.log('  - source_type: Source tracking (order, manual, product_order, etc)');
    console.log('  - source_id: Source ID (order_id, product_order_id, etc)');
    console.log('  - approved_at: Timestamp when transaction was approved');
    console.log('\nReady for walletService deployment!');
  } catch (err) {
    console.error('\n❌ MIGRATION FAILED:');
    console.error(err.message);
    process.exit(1);
  } finally {
    await connection.end();
  }
}

// Run migration
runMigration();
