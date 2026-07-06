const express = require('express');
const router = express.Router();
const { authenticateToken, requireRole } = require('../middleware/auth');
const controller = require('../controllers/orderController');

// Order Management
router.patch('/orders/accept/:id', controller.acceptOrder);
router.patch('/orders/:id/cancel', controller.cancelOrder);
router.post('/orders/:id/reject', controller.rejectOrder);
router.get('/orders/driver/:driverId', authenticateToken, requireRole(['driver','petugas','admin']), controller.getDriverOrders);
router.get('/orders/pending', authenticateToken, requireRole(['driver','petugas']), controller.getPendingOrders);
router.patch('/orders/:id/complete', authenticateToken, requireRole(['driver','petugas']), controller.completeOrder);

// Driver Location & Tracking (untuk mobile polling)
router.post('/driver/location', controller.updateLocation);
router.get('/tracking/:order_id', controller.getTracking);

module.exports = router;