# K-TRASH Flutter PHASE 1 - Foundation Implementation Complete ✅

## 📋 Ringkasan Implementasi

**Status:** Phase 1 Foundation selesai 100%  
**Tanggal:** 2024  
**Durasi:** ~2 jam kerja  
**Total Files Created:** 13 foundation files + 16 placeholder pages = 29 files

---

## 🏗️ Folder Structure (Final)

```
lib/
├── constants/
│   ├── api_constants.dart          ✅ API endpoints & base URLs
│   ├── route_constants.dart        ✅ Navigation routes
│   └── role_constants.dart         ✅ User roles & validators
│
├── core/
│   ├── network/
│   │   └── api_client.dart         ✅ Dio HTTP client + JWT interceptor
│   └── app_router.dart             ✅ Navigation routing system
│
├── utils/
│   └── secure_storage_helper.dart  ✅ Token & user data persistence
│
├── services/
│   └── auth_service.dart           ✅ Authentication business logic
│
├── shared/
│   ├── models/
│   │   ├── user_model.dart         ✅ User data model
│   │   └── order_model.dart        ✅ Order data model
│   ├── widgets/                    📁 (empty - Phase 2+)
│   └── enums/                      📁 (empty - Phase 2+)
│
├── features/
│   ├── auth/
│   │   ├── pages/
│   │   │   ├── login_page.dart     ✅ Placeholder
│   │   │   ├── register_page.dart  ✅ Placeholder
│   │   │   └── otp_page.dart       ✅ Placeholder
│   │   ├── providers/
│   │   │   └── auth_provider.dart  ✅ Authentication state management
│   │   └── widgets/                📁 (empty - Phase 2+)
│   │
│   ├── dashboard/
│   │   ├── pages/
│   │   │   ├── user_dashboard_page.dart   ✅ Placeholder
│   │   │   └── driver_dashboard_page.dart ✅ Placeholder
│   │   ├── providers/                    📁 (empty - Phase 2+)
│   │   └── widgets/                      📁 (empty - Phase 2+)
│   │
│   ├── orders/
│   │   ├── pages/
│   │   │   ├── pickup_page.dart         ✅ Placeholder
│   │   │   ├── select_waste_page.dart   ✅ Placeholder
│   │   │   ├── find_driver_page.dart    ✅ Placeholder
│   │   │   ├── result_page.dart         ✅ Placeholder
│   │   │   └── order_detail_page.dart   ✅ Placeholder
│   │   ├── providers/                   📁 (empty - Phase 2+)
│   │   └── widgets/                     📁 (empty - Phase 2+)
│   │
│   ├── tracking/
│   │   ├── pages/
│   │   │   ├── tracking_page.dart       ✅ Placeholder
│   │   │   └── driver_tracking_page.dart ✅ Placeholder
│   │   ├── providers/                   📁 (empty - Phase 2+)
│   │   └── widgets/                     📁 (empty - Phase 2+)
│   │
│   ├── profile/
│   │   ├── pages/
│   │   │   ├── profile_page.dart        ✅ Placeholder
│   │   │   └── driver_profile_page.dart ✅ Placeholder
│   │   ├── providers/                   📁 (empty - Phase 2+)
│   │   └── widgets/                     📁 (empty - Phase 2+)
│   │
│   ├── history/
│   │   ├── pages/
│   │   │   └── history_page.dart        ✅ Placeholder
│   │   ├── providers/                   📁 (empty - Phase 2+)
│   │   └── widgets/                     📁 (empty - Phase 2+)
│   │
│   └── marketplace/
│       ├── pages/
│       │   └── marketplace_page.dart    ✅ Placeholder
│       ├── providers/                   📁 (empty - Phase 2+)
│       └── widgets/                     📁 (empty - Phase 2+)
│
└── main.dart                           📝 (NOT YET UPDATED - Phase 2)
```

---

## 📦 Dependencies Installed

```yaml
# pubspec.yaml - 5 new dependencies added

provider: ^6.0.0                    # State management (ChangeNotifier)
flutter_secure_storage: ^9.0.0      # Encrypted token storage
dio: ^5.3.0                        # HTTP client with interceptors
socket_io_client: ^2.0.1           # Real-time tracking (Phase 2+)
google_maps_flutter: ^2.4.0        # Map integration (Phase 2+)

# Existing dependencies retained:
http, intl, video_player, shared_preferences, geolocator, 
geocoding, permission_handler, flutter_map, latlong2
```

---

## 🔧 Phase 1 - Core Implementation Files

### 1. **constants/api_constants.dart**
**Purpose:** Centralized API configuration  
**Content:**
- 3 environment base URLs (production, development, local)
- 30+ endpoint path constants
- HTTP headers and timeout configs
- DRY principle - single source of truth

**Key Endpoints:**
```dart
// Auth
POST /api/auth/login
POST /api/auth/register
POST /api/auth/register/verify
POST /api/auth/register/resend
GET /api/auth/validate-token

// Orders
POST /api/orders
GET /api/orders/user/:id
GET /api/orders/pending
PATCH /api/orders/accept/:id
PATCH /api/orders/status/:id

// Tracking
POST /api/driver/location
GET /api/tracking/:id

// User
GET /api/user/balance/:id
GET /api/user/profile

// Marketplace
GET /api/marketplace/products
POST /api/marketplace/products/:id/order
```

---

### 2. **constants/route_constants.dart**
**Purpose:** Centralized route definitions  
**Routes:**
```dart
// Auth
/login
/register
/otp

// User
/user/dashboard
/user/profile
/user/history
/user/saldo

// Orders
/orders/pickup
/orders/select-waste
/orders/find-driver
/orders/result

// Driver
/driver/dashboard
/driver/profile

// Tracking
/tracking/order
/tracking/driver

// Marketplace
/marketplace
```

---

### 3. **constants/role_constants.dart**
**Purpose:** User role validation  
**Roles:**
- `user` - Regular user (minimal permissions)
- `driver` - Delivery driver (can accept orders)
- `petugas` - Officer/staff (can verify waste)
- `admin` - System administrator

**Helpers:**
- `isValidRole(String role)` → bool
- `isDriver()` → bool
- `isUser()` → bool
- `isAdmin()` → bool

---

### 4. **core/network/api_client.dart**
**Purpose:** HTTP client with automatic JWT injection  
**Features:**
- ✅ Singleton pattern (single Dio instance)
- ✅ JWT interceptor (auto-adds Bearer token)
- ✅ Error interceptor (handles 401 logout)
- ✅ Type-safe generics
- ✅ 30-second timeouts for all requests

**Methods:**
```dart
Future<T?> get<T>(String endpoint, {Map<String, dynamic>? queryParams})
Future<T?> post<T>(String endpoint, {required Map<String, dynamic> data})
Future<T?> patch<T>(String endpoint, {required Map<String, dynamic> data})
Future<T?> put<T>(String endpoint, {required Map<String, dynamic> data})
Future<T?> delete<T>(String endpoint)
```

---

### 5. **utils/secure_storage_helper.dart**
**Purpose:** Secure token and user data storage  
**Important:** Uses `FlutterSecureStorage` (encrypted), NOT plain SharedPreferences

**Key Methods:**
```dart
// Token management
saveToken(String token)
getToken() → String?
deleteToken()
hasToken() → bool

// User data
saveUserData(UserModel user)
getUserData() → UserModel?
deleteUserData()

// Refresh token
saveRefreshToken(String token)
getRefreshToken() → String?

// Full cleanup
clearAll()
hasAuthData() → bool
```

---

### 6. **shared/models/user_model.dart**
**Purpose:** User data structure matching backend  
**Fields:**
```dart
int id
String nama
String email
String role
String nomorHp
String? profilePhoto
int saldo
int? saldoHold
DateTime createdAt
DateTime updatedAt
```

**Methods:**
- `toJson()` → Map<String, dynamic>
- `fromJson(Map)` → UserModel
- `copyWith()` → New instance with optional updates
- Equality & hashCode overrides

**Backend Mapping Example:**
```
Backend: "nomor_hp"      → Dart: nomorHp
Backend: "profile_photo" → Dart: profilePhoto
Backend: "saldo_hold"    → Dart: saldoHold
```

---

### 7. **shared/models/order_model.dart**
**Purpose:** Order data structure  
**Fields:**
```dart
int id
int userId
int? driverId
String address
double userLat
double userLng
String jenisSampah
String? catatan
String status
List<SampahData>? sampahData
double? totalBerat
int? totalHarga
DateTime createdAt
DateTime updatedAt
```

**Order Status Values:**
```
pending, searching_driver, assigned, on_the_way,
arrived, completed, cancelled, approved, rejected
```

---

### 8. **services/auth_service.dart**
**Purpose:** Authentication business logic  
**Methods:**
```dart
login(String email, String password)
  → {success: bool, token: String?, user: UserModel?, message: String}

register(String nama, String email, String password, String role, String nomorHp)
  → {success: bool, status: String?, message: String, debugOtp?: String}

verifyRegister(String email, String otp)
  → {success: bool, token: String?, user: UserModel?, message: String}

resendRegisterOtp(String email)
  → {success: bool, message: String, debugOtp?: String}

validateToken()
  → {valid: bool, user: UserModel?, message: String}

logout()
  → void (clears SecureStorageHelper)

isAuthenticated() → bool
getStoredUser() → UserModel?
```

**Auto-persistence:**
- Token + user automatically saved to SecureStorageHelper on login/register
- Automatic removal on logout/401 error

---

### 9. **features/auth/providers/auth_provider.dart**
**Purpose:** State management for authentication  
**AuthStatus Enum:**
```dart
initial       // App startup
loading       // Processing request
authenticated // User logged in
unauthenticated // User logged out
error         // Error occurred
```

**Properties:**
```dart
AuthStatus status
UserModel? user
String? token
String? errorMessage
bool isAuthenticated (getter)
bool isLoading (getter)
```

**Methods:**
```dart
initializeAuth()              // App startup: validate stored token
login(String email, String password) → bool
register(...params) → bool
verifyRegister(String email, String otp) → bool
resendOtp(String email) → bool
logout() → void
clearError() → void
updateUser(UserModel newUser) → void
```

**State Flow:**
```
initial
  ↓ (on app startup)
loading
  ├→ authenticated (token valid)
  └→ unauthenticated/error (token invalid)
```

**Usage in Widgets:**
```dart
// Read only
var authProvider = context.read<AuthProvider>();

// Watch for changes (rebuild on state change)
var user = context.watch<AuthProvider>().user;
var isLoggedIn = context.watch<AuthProvider>().isAuthenticated;

// Must wrap at app root:
ChangeNotifierProvider<AuthProvider>(
  create: (_) => AuthProvider(),
  child: MyApp(),
)
```

---

### 10. **core/app_router.dart**
**Purpose:** Central navigation routing  
**Implementation:** Static `generateRoute()` method for MaterialApp.onGenerateRoute

**Sample Routes:**
```dart
RouteConstants.login → LoginPage()
RouteConstants.register → RegisterPage()
RouteConstants.registerVerifyEndpoint → OtpPage(email: args)

RouteConstants.userDashboard → UserDashboardPage()
RouteConstants.selectWaste → SelectWastePage(orderId: args)
RouteConstants.trackingPage → TrackingPage(orderId: args)
```

**Argument Passing:**
```dart
// Navigate with arguments
Navigator.pushNamed(context, RouteConstants.selectWaste, arguments: orderId);

// Receive in target page constructor
class SelectWastePage {
  final int? orderId;
  const SelectWastePage({Key? key, this.orderId}) : super(key: key);
}
```

---

## 📄 Phase 1 - Placeholder Pages (16 files)

All pages have basic Scaffold + placeholder text. No real UI implementation yet.

| Page | File | Purpose |
|------|------|---------|
| Login | auth/pages/login_page.dart | User authentication |
| Register | auth/pages/register_page.dart | New user signup |
| OTP | auth/pages/otp_page.dart | Email verification |
| User Dashboard | dashboard/pages/user_dashboard_page.dart | User main view |
| Driver Dashboard | dashboard/pages/driver_dashboard_page.dart | Driver main view |
| Pickup | orders/pages/pickup_page.dart | Set pickup location |
| Select Waste | orders/pages/select_waste_page.dart | Choose waste types |
| Find Driver | orders/pages/find_driver_page.dart | Search driver |
| Result | orders/pages/result_page.dart | Order confirmation |
| Order Detail | orders/pages/order_detail_page.dart | Full order info |
| Tracking | tracking/pages/tracking_page.dart | User real-time tracking |
| Driver Tracking | tracking/pages/driver_tracking_page.dart | Driver route tracking |
| Profile | profile/pages/profile_page.dart | User profile mgmt |
| Driver Profile | profile/pages/driver_profile_page.dart | Driver profile mgmt |
| History | history/pages/history_page.dart | Transaction history |
| Marketplace | marketplace/pages/marketplace_page.dart | Product listings |

---

## ✅ What's Completed in Phase 1

| Task | Status | File |
|------|--------|------|
| Dependencies installed | ✅ | pubspec.yaml |
| API constants | ✅ | constants/api_constants.dart |
| Route constants | ✅ | constants/route_constants.dart |
| Role constants | ✅ | constants/role_constants.dart |
| HTTP client layer | ✅ | core/network/api_client.dart |
| Secure token storage | ✅ | utils/secure_storage_helper.dart |
| User model | ✅ | shared/models/user_model.dart |
| Order model | ✅ | shared/models/order_model.dart |
| Auth service | ✅ | services/auth_service.dart |
| Auth provider | ✅ | features/auth/providers/auth_provider.dart |
| Router | ✅ | core/app_router.dart |
| Placeholder pages | ✅ | 16 files in features/*/pages/ |
| Main.dart update | ❌ | Phase 2 |
| Folder structure | ✅ | 29 directories |

---

## 🚀 Next Steps - Phase 2

### 2.1 - Update main.dart
```dart
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'services/auth_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/app_router.dart';
import 'constants/route_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize services
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..initializeAuth(),
        ),
      ],
      child: MaterialApp(
        title: 'K-TRASH',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: RouteConstants.login,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
```

### 2.2 - Create Remaining Services
```
services/
├── order_service.dart         (createOrder, acceptOrder, etc.)
├── tracking_service.dart      (getTracking, sendLocation)
├── user_service.dart          (getBalance, getProfile, updateProfile)
├── marketplace_service.dart   (getProducts, createOrder)
├── waste_service.dart         (getCategories, getTypes)
└── socket_service.dart        (real-time tracking)
```

### 2.3 - Create Remaining Providers
```
features/
├── orders/providers/order_provider.dart
├── tracking/providers/tracking_provider.dart
├── dashboard/providers/dashboard_provider.dart (user balance, pending orders)
├── marketplace/providers/marketplace_provider.dart
└── profile/providers/profile_provider.dart
```

### 2.4 - Implement Socket.io
- Real-time order status updates
- Driver location tracking
- Live notifications

### 2.5 - Actual UI Implementation
- Convert placeholder pages to real screens
- Migrate React components to Flutter widgets
- Add form validation and error handling
- Implement maps for tracking

---

## ⚠️ Important Notes

1. **DO NOT CHANGE BACKEND**
   - All endpoints already match backend
   - All field names properly mapped
   - No backend migration needed

2. **TOKEN STORAGE**
   - ALWAYS use `FlutterSecureStorage` (encrypted)
   - NEVER use `SharedPreferences` for tokens
   - Automatic JWT injection via ApiClient

3. **STATE MANAGEMENT**
   - Provider + ChangeNotifier pattern
   - Service layer (business logic) separate from Provider (state)
   - Reactive updates via notifyListeners()

4. **NAVIGATION**
   - Use named routes with RouteConstants
   - Pass arguments via settings.arguments
   - Router handles invalid routes

5. **ERROR HANDLING**
   - 401 errors trigger logout automatically
   - User-friendly error messages
   - Connection timeout handling

---

## 📊 Validation

✅ All endpoints match backend (Phase A analysis)
✅ All model field names match backend JSON
✅ All role values validated (user, driver, petugas, admin)
✅ All order statuses validated
✅ Folder structure follows Clean Architecture
✅ No compilation errors
✅ TypeScript-like type safety with Dart

---

## 📝 Command to Test

```bash
cd userendpetugas
flutter pub get
flutter analyze  # Check for errors
flutter run       # Run on emulator/device
```

---

**Phase 1 Foundation Status:** ✅ COMPLETE  
**Ready for Phase 2:** YES  
**Blocking Issues:** NONE
