/**
 * WALLET SERVICE - Centralized Saldo Engine (PHASE 1)
 * 
 * Purpose: Single source of truth for all saldo mutations
 * Architecture: All balance changes flow through executeTransaction()
 * 
 * PHASE 1 ONLY:
 * - Centralized transaction execution
 * - Idempotency via transaction_reference (UNIQUE)
 * - Balance before/after tracking for audit
 * - FOR UPDATE locks for consistency
 * - Immutable ledger (append-only)
 * 
 * PHASE 2: Marketplace integration
 * PHASE 3: Optimization based on real usage
 */

const db = require('../db');

// Safe number conversion
function safeNumber(value) {
  return Number(value) || 0;
}

/**
 * CORE WALLET ENGINE
 * 
 * All saldo mutations MUST go through this function
 * 
 * @param {Object} params
 * @param {number} params.userId - User ID (required)
 * @param {number} params.amount - Amount (positive=credit, negative=debit)
 * @param {string} params.type - Transaction type (waste_income, topup_manual, marketplace_purchase, marketplace_refund, etc)
 * @param {string} params.transactionReference - Unique reference for idempotency (required, UNIQUE)
 * @param {string} params.sourceType - Source type (order, manual, product_order, etc)
 * @param {number} params.sourceId - Source ID (order_id, product_order_id, etc)
 * @param {string} params.description - Human readable description
 * @param {number} params.createdBy - User ID of creator (user_id, admin_id, etc)
 * 
 * @returns {Object} { success, transactionId, balanceBefore, balanceAfter, holdBefore, holdAfter, message }
 * @throws {Error} on validation failure or database error
 */
async function executeTransaction(params) {
  const {
    userId,
    amount,
    type,
    transactionReference,
    sourceType,
    sourceId,
    description,
    createdBy,
  } = params;

  // ========== VALIDATION ==========
  if (!userId) throw new Error('userId is required');
  if (typeof amount !== 'number') throw new Error('amount must be number');
  if (!type) throw new Error('type is required');
  if (!transactionReference) throw new Error('transactionReference is required');
  if (!createdBy) throw new Error('createdBy is required');

  const connection = await db.getConnection();

  try {
    // ========== IDEMPOTENCY CHECK ==========
    // If same reference exists, return cached result (don't process again)
    const [existingTxn] = await connection.query(
      `SELECT id, amount, balance_before, balance_after 
       FROM saldo_transactions 
       WHERE transaction_reference = ?
       LIMIT 1`,
      [transactionReference],
    );

    if (existingTxn.length > 0) {
      // Idempotency: same reference = same result
      console.log(
        `[IDEMPOTENCY] Reference ${transactionReference} already exists, returning cached result`,
      );
      return {
        success: true,
        isIdempotent: true,
        transactionId: existingTxn[0].id,
        balanceBefore: safeNumber(existingTxn[0].balance_before),
        balanceAfter: safeNumber(existingTxn[0].balance_after),
        holdAfter: 0,
        message: 'Transaction already processed (idempotent)',
      };
    }

    // ========== BEGIN ATOMIC TRANSACTION ==========
    await connection.beginTransaction();

    // ========== LOCK USER ROW (FOR UPDATE) ==========
    // Serialize all saldo mutations for same user
    const [userRows] = await connection.query(
      'SELECT id, saldo, saldo_hold FROM users WHERE id = ? FOR UPDATE',
      [userId],
    );

    if (userRows.length === 0) {
      throw new Error(`User ${userId} not found`);
    }

    const user = userRows[0];
    const balanceBefore = safeNumber(user.saldo);
    const holdBefore = safeNumber(user.saldo_hold);

    // ========== CALCULATE NEW BALANCE ==========
    const balanceAfter = balanceBefore + safeNumber(amount);

    // Prevent negative balance (unless explicitly allowed)
    if (balanceAfter < 0) {
      throw new Error(
        `Insufficient balance: have ${balanceBefore}, need ${Math.abs(amount)}`,
      );
    }

    // ========== RECALCULATE HOLD ==========
    // Get minimum hold setting
    const [holdSettings] = await connection.query(
      'SELECT setting_value FROM app_settings WHERE setting_key = ?',
      ['minimum_hold_balance'],
    );

    const minimumHold = safeNumber(holdSettings[0]?.setting_value || 50000);
    const holdAfter = Math.min(balanceAfter, minimumHold);

    // ========== UPDATE USERS TABLE ==========
    // Single atomic update: saldo + hold
    await connection.query(
      'UPDATE users SET saldo = ?, saldo_hold = ?, updated_at = NOW() WHERE id = ?',
      [balanceAfter, holdAfter, userId],
    );

    // ========== INSERT TRANSACTION LEDGER ==========
    // Immutable ledger entry with full audit trail
    const [txnResult] = await connection.query(
      `INSERT INTO saldo_transactions (
        user_id, 
        order_id, 
        type, 
        amount, 
        status, 
        description, 
        created_by, 
        approved_by,
        created_at,
        transaction_reference,
        balance_before,
        balance_after,
        saldo_hold,
        source_type,
        source_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?, ?)`,
      [
        userId,
        null, // order_id (NULL for now, can link later if needed)
        type,
        amount,
        'approved', // PHASE 1: All transactions approved immediately
        description,
        createdBy,
        createdBy, // admin user who created this
        transactionReference,
        balanceBefore,
        balanceAfter,
        holdAfter,
        sourceType || null,
        sourceId || null,
      ],
    );

    // ========== COMMIT TRANSACTION ==========
    await connection.commit();

    console.log(
      `[WALLET] Transaction created: ref=${transactionReference}, user=${userId}, amount=${amount}, balance=${balanceBefore}→${balanceAfter}`,
    );

    // ========== RETURN SUCCESS RESULT ==========
    return {
      success: true,
      isIdempotent: false,
      transactionId: txnResult.insertId,
      balanceBefore,
      balanceAfter,
      holdBefore,
      holdAfter,
      availableBefore: balanceBefore - holdBefore,
      availableAfter: balanceAfter - holdAfter,
      message: 'Transaction executed successfully',
    };
  } catch (err) {
    // ========== ROLLBACK ON ERROR ==========
    await connection.rollback();
    console.error(`[WALLET ERROR] ${err.message}`);
    throw err;
  } finally {
    // ========== RELEASE CONNECTION ==========
    connection.release();
  }
}

/**
 * GET USER BALANCE
 * Read-only query for user's current balance
 */
async function getUserBalance(userId) {
  const [rows] = await db.query(
    'SELECT saldo, saldo_hold FROM users WHERE id = ?',
    [userId],
  );

  if (rows.length === 0) {
    throw new Error('User not found');
  }

  const saldo = safeNumber(rows[0].saldo);
  const saldo_hold = safeNumber(rows[0].saldo_hold);

  return {
    saldo,
    saldo_hold,
    available_balance: saldo - saldo_hold,
  };
}

/**
 * GET TRANSACTION HISTORY
 * Immutable ledger read (for audit)
 */
async function getTransactionHistory(userId, limit = 50) {
  const [rows] = await db.query(
    `SELECT 
      id,
      user_id,
      type,
      amount,
      status,
      description,
      created_by,
      approved_by,
      created_at,
      transaction_reference,
      balance_before,
      balance_after,
      saldo_hold,
      source_type,
      source_id
    FROM saldo_transactions 
    WHERE user_id = ? 
    ORDER BY created_at DESC 
    LIMIT ?`,
    [userId, limit],
  );

  return rows;
}

/**
 * VERIFY LEDGER CONSISTENCY
 * Check if sum of ledger equals current saldo (reconciliation)
 * Used for auditing, not critical path
 */
async function verifyLedgerConsistency(userId) {
  const [userRows] = await db.query('SELECT saldo FROM users WHERE id = ?', [userId]);

  if (userRows.length === 0) {
    throw new Error('User not found');
  }

  const currentSaldo = safeNumber(userRows[0].saldo);

  // Sum all transactions from ledger
  const [sumRows] = await db.query(
    'SELECT COALESCE(SUM(amount), 0) as total FROM saldo_transactions WHERE user_id = ?',
    [userId],
  );

  const ledgerSum = safeNumber(sumRows[0].total);

  const isConsistent = currentSaldo === ledgerSum;

  return {
    currentSaldo,
    ledgerSum,
    isConsistent,
    discrepancy: currentSaldo - ledgerSum,
  };
}

module.exports = {
  executeTransaction,
  getUserBalance,
  getTransactionHistory,
  verifyLedgerConsistency,
};
