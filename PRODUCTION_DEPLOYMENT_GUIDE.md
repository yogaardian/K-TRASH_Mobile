# Production Deployment Checklist & Fixes

## ✅ BACKEND FIXES COMPLETED

### 1. **Missing API Endpoints - FIXED**
Added 4 critical endpoints to `/backend/src/routes/orderRoutes.js`:

```javascript
// GET /tracking/:order_id - Fetch latest driver location
router.get('/tracking/:order_id', controller.getTracking);

// POST /driver/location - Send driver location updates
router.post('/driver/location', controller.updateLocation);

// GET /orders/pending - Fetch available orders for drivers
router.get('/orders/pending', authenticateToken, requireRole(['driver','petugas']), controller.getPendingOrders);

// PATCH /orders/:id/complete - Complete order with waste data
router.patch('/orders/:id/complete', authenticateToken, requireRole(['driver','petugas']), controller.completeOrder);
```

### 2. **Missing Database Tables - FIXED**
Auto-created tables in `/backend/index.js` on server startup:
- `driver_locations` - Stores real-time driver GPS coordinates
- `driver_rejected_orders` - Tracks order rejections to prevent duplicates

### 3. **Migration Files Added**
Created in `/backend/migrations/`:
- `003_create_driver_locations_table.sql`
- `004_create_driver_rejected_orders_table.sql`

---

## 🔧 PRODUCTION CONFIGURATION REQUIRED

### For Production APK Build

When deploying backend to production (`https://api-ktrashuns.tifpsdku.com`):

#### ✋ CRITICAL: Update `.env` for Production

```env
# Production Environment
NODE_ENV=production
PORT=5000  # or your production port

# Database - UPDATE WITH PRODUCTION CREDENTIALS
DB_HOST=your-production-db-host
DB_USER=your-db-user
DB_PASSWORD=your-db-password
DB_NAME=bank_sampah
DB_PORT=3306

# CORS - MUST include production frontend URLs
CORS_ALLOW_ORIGINS=https://api-ktrashuns.tifpsdku.com,https://k-trash-olivia.vercel.app,http://localhost:3000

# Frontend URLs
FRONTEND_URL=https://k-trash-olivia.vercel.app

# JWT Secret - CHANGE FROM DEFAULT (security critical)
JWT_SECRET=your-secure-random-32-char-secret-key-here

# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id

# Email (optional if not using OTP)
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
```

### Production APK Build Command

```bash
cd userendpetugas
flutter build apk --release --dart-define=BACKEND_URL=https://api-ktrashuns.tifpsdku.com --dart-define=FLUTTER_ENVIRONMENT=production
```

---

## 📋 VERIFICATION CHECKLIST

After deploying backend changes:

### 1. Verify Backend is Running
```bash
curl https://api-ktrashuns.tifpsdku.com/ping
# Should return: {"status":"ok"}
```

### 2. Test Tracking Endpoint
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api-ktrashuns.tifpsdku.com/tracking/1
# Should return driver location data
```

### 3. Test Location Update (Driver)
```bash
curl -X POST https://api-ktrashuns.tifpsdku.com/driver/location \
  -H "Content-Type: application/json" \
  -d '{
    "driver_id": 1,
    "order_id": 1,
    "lat": -7.5445,
    "lng": 111.6625
  }'
```

### 4. Test Pending Orders (Driver)
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api-ktrashuns.tifpsdku.com/orders/pending
# Should return list of pending orders
```

---

## 🐛 WHY MAPS WERE FAILING IN MOBILE

**Root Cause:** Backend had functions but endpoints were NOT mounted in routes.

| Feature | Issue | Status |
|---------|-------|--------|
| Driver location tracking | Endpoint `/driver/location` didn't exist | ✅ FIXED |
| Get driver location | Endpoint `/tracking/:orderId` didn't exist | ✅ FIXED |
| Driver dashboard | Endpoint `/orders/pending` didn't exist | ✅ FIXED |
| Complete order | Endpoint `/orders/:id/complete` didn't exist | ✅ FIXED |
| Database tables | `driver_locations` table didn't exist | ✅ FIXED |
| Socket.io | ✅ Already working - real-time push | Already OK |

**Result:** 
- **Web** used Socket.io → worked ✅
- **Mobile** used HTTP polling → failed because endpoints missing ❌

---

## 📱 PRODUCTION APK NOTES

The production APK (`--dart-define=BACKEND_URL=https://api-ktrashuns.tifpsdku.com`) will:

1. ✅ Connect to production backend at `https://api-ktrashuns.tifpsdku.com`
2. ✅ Poll `/tracking/{orderId}` every 3 seconds for driver location
3. ✅ Send location updates via POST `/driver/location` when driver moves
4. ✅ Fetch pending orders from GET `/orders/pending`
5. ✅ Use Socket.io for real-time order status updates (when web is online)

---

## 🚀 DEPLOYMENT STEPS

1. **Pull latest backend changes** (with new routes and table creation)
2. **Update `.env` with production database credentials**
3. **Set `NODE_ENV=production` and `JWT_SECRET`**
4. **Restart backend server** (tables will auto-create on startup)
5. **Build new APK** with production BACKEND_URL
6. **Test endpoints** using curl commands above

---

## 📞 SUPPORT

If maps still don't work after deployment:
1. Check backend logs for errors
2. Verify database tables exist: `SHOW TABLES LIKE 'driver%';`
3. Verify CORS allows your frontend: `curl -v https://api-ktrashuns.tifpsdku.com`
4. Test endpoints manually using curl commands above
