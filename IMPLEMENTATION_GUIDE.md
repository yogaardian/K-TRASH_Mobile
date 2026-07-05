# 🗑️ Trash Pickup App - Implementation Guide

## 📋 Overview
Complete trash pickup system dengan role-based access (User & Petugas), location tracking via OpenStreetMap, dan real-time order management.

---

## ✅ Features Implemented

### 1. **User Flow (Login → Order Creation → Tracking)**
- ✅ Login/Register dengan role selection
- ✅ PickupPage: Auto-location detection + flutter_map visualization
- ✅ Ngawi district/village dropdowns dengan auto address filling
- ✅ PilihSampahPage: Waste type selection + order creation
- ✅ MencariPetugasPage: Search for nearest driver (4s delay)
- ✅ TrackingPetugasPage: Live location tracking dengan flutter_map + OpenStreetMap

### 2. **Petugas Flow (Dashboard → Accept Order → Location Update)**
- ✅ DashboardPetugas: Fetch pending orders dari backend
- ✅ DetailOrderPage: Accept order dan update status ke "assigned"
- ✅ Real-time location updates setiap 5 detik ke `/driver/location`
- ✅ Live marker visualization di TrackingPetugasPage

### 3. **Backend Integration**
- ✅ `/login` - User authentication dengan role
- ✅ `/register` - User registration
- ✅ `/harga/:jenis` - Waste prices by type
- ✅ `/harga/:jenis/:sub` - Sub-category prices
- ✅ `/orders` (POST) - Create new order
- ✅ `/orders/pending` (GET) - List pending orders
- ✅ `/orders/accept/:id` (PATCH) - Accept order
- ✅ `/orders/status/:id` (PATCH) - Update order status
- ✅ `/driver/location` (POST) - Update driver location
- ✅ `/tracking/:order_id` (GET) - Get latest tracking

### 4. **Database**
- ✅ users table: id, nama, email, password, role, nomor_hp
- ✅ orders table: id, user_id, driver_id, address, lat, lng, jenis_sampah, catatan, status, created_at
- ✅ driver_locations table: driver_id, order_id, lat, lng
- ✅ harga_sampah table: nama, harga, jenis, sub

---

## 🚀 How to Run

### Backend
```bash
cd c:\trash2\backend
node index.js
# Server runs on http://localhost:3000
```

### Frontend
```bash
cd c:\trash2\userendpetugas
flutter pub get
flutter run
```

---

## 🧪 Test Scenarios

### Scenario 1: User Creates Order
1. Login dengan `user@test.com` / `123456`
2. Click "Jemput Sampah" banner
3. Pick location (auto-detected or manual Ngawi location)
4. Select waste type (Organik/Anorganik/Lainnya)
5. Submit order → Order created in database

**Expected Result**: 
- Order appears in petugas dashboard
- Order status = "pending"
- Location saved in database

---

### Scenario 2: Petugas Accepts Order
1. Login dengan `petugas@test.com` / `123456`
2. View pending orders in DashboardPetugas
3. Click "Terima" button on order
4. Order status updates to "assigned"
5. Driver ID linked to order

**Expected Result**:
- Order moves from pending list
- DetailOrderPage shows order details
- Next page navigates to location tracking

---

### Scenario 3: Real-time Tracking
1. After petugas accepts order
2. TrackingPetugasPage shows live map
3. Location updates every 5 seconds
4. Backend receives POST `/driver/location` calls
5. Green marker shows current driver position

**Expected Result**:
- Map updates smoothly
- No console errors
- Location stored in driver_locations table

---

## 🔌 API Endpoints

### Authentication
```
POST /login
Body: { email, password }
Returns: { status, id, nama, role }

POST /register
Body: { nama, email, password, role, nomor_hp }
Returns: { status }
```

### Waste Prices
```
GET /harga/plastik
Returns: [{ nama, harga }, ...]

GET /harga/elektronik/komunikasi
Returns: [{ nama, harga }, ...]
```

### Orders
```
POST /orders
Body: { user_id, address, user_lat, user_lng, jenis_sampah, catatan }
Returns: { status, order_id }

GET /orders/pending
Returns: [{ id, user_id, address, status, ... }, ...]

PATCH /orders/accept/:id
Body: { driver_id }
Returns: { status }

PATCH /orders/status/:id
Body: { status: 'on_the_way'|'arrived'|'completed' }
Returns: { status }
```

### Location Tracking
```
POST /driver/location
Body: { driver_id, order_id, lat, lng }
Returns: { status }

GET /tracking/:order_id
Returns: { location: { lat, lng, created_at }, status }
```

---

## 📱 Key Files Modified

### Frontend
- [lib/pickup_page.dart](../../lib/pickup_page.dart) - flutter_map integration
- [lib/pilih_sampah_page.dart](../../lib/pilih_sampah_page.dart) - Order creation
- [lib/tracking_petugas_page.dart](../../lib/tracking_petugas_page.dart) - Live tracking
- [lib/petugas/dashboard_petugas.dart](../../lib/petugas/dashboard_petugas.dart) - Fetch orders
- [lib/petugas/detail_order.dart](../../lib/petugas/detail_order.dart) - Accept order
- [lib/petugas/models/order.dart](../../lib/petugas/models/order.dart) - Order model

### Backend
- [backend/index.js](../../backend/index.js) - All API endpoints

---

## 📦 Dependencies
```yaml
flutter_map: ^6.0.0          # Maps rendering
latlong2: ^0.9.0              # Coordinate system
geolocator: ^10.1.0            # GPS location
geocoding: ^2.1.1              # Address lookup
permission_handler: ^12.0.1    # Permissions
http: ^1.6.0                   # API calls
intl: ^0.18.1                  # Localization
shared_preferences: ^2.2.2     # Local storage
video_player: ^2.8.2           # Video playback
```

---

## 🔑 Test Credentials
```
User Account:
  Email: emailanda
  Password: passwordanda
  Role: user

Driver Account:
  Email: emailpetugasanda
  Password: passwordanda
  Role: driver
```

---

## 📍 Location References
- Base URL: `http://10.0.2.2:3000` (Android emulator)
- Madiun
- Caruban

---

## ⚠️ Known Limitations
- Notifications not yet implemented
- Chat/Phone features are UI placeholders

---

## 🔄 Next Steps (Future Enhancement)
1. [ ] Firebase Cloud Messaging for notifications
2. [ ] Real SMS/Call integration
3. [ ] Payment gateway integration
4. [ ] Rating/Review system
5. [ ] Analytics dashboard
6. [ ] Multi-language support

---

## 🐛 Troubleshooting

### Map not showing
- Check flutter_map dependencies are installed
- Ensure OpenStreetMap endpoint is accessible
- Verify MapController initialization

### Location not updating
- Enable location services on device/emulator
- Grant location permissions
- Check geolocator configuration

### Backend connection fails
- Verify backend server is running (`node index.js`)
- Check database connection
- Ensure emulator can reach host machine (10.0.2.2)

### Orders not appearing
- Verify order was created (check database)
- Ensure user_id matches login user
- Check `/orders/pending` endpoint returns data

---

## ✨ Status
- **Date**: May 4, 2026
- **Version**: 1.0.0
- **Status**: ✅ READY FOR TESTING

Last Updated: [timestamp when this guide was created]
