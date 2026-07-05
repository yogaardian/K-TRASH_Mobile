const express = require('express');
const router = express.Router();
const { authenticateToken, requireRole } = require('../middleware/auth');
const controller = require('../controllers/orderController');

router.patch('/orders/accept/:id', controller.acceptOrder);
router.patch('/orders/:id/cancel', controller.cancelOrder);
router.post('/orders/:id/reject', controller.rejectOrder);
router.get('/orders/driver/:driverId', authenticateToken, requireRole(['driver','petugas','admin']), controller.getDriverOrders);

module.exports = router;