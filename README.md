# K-TRASH

K-TRASH adalah sistem digital untuk layanan bank sampah yang menghubungkan pengguna, petugas, dan admin melalui satu backend terpusat, satu database, serta dua antarmuka frontend: website dan aplikasi mobile.

Project ini dirancang untuk mendukung alur seperti:
- pengguna membuat permintaan penjemputan sampah,
- petugas menerima dan memproses order,
- admin mengelola data, harga, saldo, dan transaksi,
- lokasi dan pelacakan order dapat dipantau secara real-time.

---

## 1. Gambaran Umum Sistem

K-TRASH terdiri dari 4 bagian utama:

1. Backend API
   - dibangun dengan Node.js + Express.js
   - menyediakan autentikasi, manajemen order, tracking lokasi, wallet, transaksi, dan endpoint admin
   - mendukung real-time communication melalui Socket.IO

2. Database
   - menggunakan MySQL / MariaDB
   - menyimpan data pengguna, order, lokasi driver, harga sampah, transaksi, dan wallet
   - schema utama tersedia pada file SQL di akar proyek

3. Frontend Website
   - dibangun dengan React.js
   - digunakan untuk panel admin dan antarmuka web utama

4. Frontend Mobile
   - dibangun dengan Flutter
   - digunakan untuk pengguna dan petugas dalam operasi lapangan

---

## 2. Arsitektur Aplikasi

```text
User / Petugas / Admin
        │
        ▼
Frontend Website (React)
        │
        ▼
Frontend Mobile (Flutter)
        │
        ▼
Backend API (Express.js + JWT + Socket.IO)
        │
        ▼
MySQL / MariaDB
```

Catatan penting:
- Website dan mobile menggunakan backend yang sama.
- Database yang dipakai juga sama.
- Tidak ada backend terpisah untuk mobile.

---

## 3. Struktur Folder

```text
K-TRASH/
├── backend/                  # API server Node.js/Express
├── pundesari/                # Frontend website React
├── userendpetugas/           # Frontend mobile Flutter
├── PRD.md                    # Dokumen PRD
├── IMPLEMENTATION_GUIDE.md   # Panduan implementasi
├── QUICK_FIX_GUIDE.md       # Panduan troubleshooting
└── README.md                 # Dokumentasi utama proyek
```

---

## 4. Backend

### Teknologi
- Node.js
- Express.js
- MySQL2
- JWT Authentication
- bcryptjs
- CORS + Helmet
- Socket.IO
- Google OAuth support
- Rate limiting

### Fitur Backend
- autentikasi login/register
- role-based access: user, petugas, admin
- pembuatan dan manajemen order penjemputan sampah
- penetapan petugas ke order
- update status order
- pelacakan lokasi driver secara real-time
- manajemen harga sampah
- transaksi dan wallet
- endpoint admin untuk monitoring dan approval

### Jalankan Backend
```bash
cd backend
npm install
npm run dev
```

Backend default berjalan pada:
```text
http://localhost:5000
```

### Environment Variables Backend
Backend membaca konfigurasi dari file .env di folder backend. Variabel yang umum dipakai:
```env
PORT=5000
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=
DB_NAME=bank_sampah
DB_PORT=3306
JWT_SECRET=your_secret
CORS_ALLOW_ORIGINS=http://localhost:3000
FRONTEND_URL=http://localhost:3000
```

---

## 5. Database

Database utama proyek adalah MySQL / MariaDB dengan nama database `bank_sampah`.

### Tabel utama
- `users` : data pengguna, role, login, kontak
- `orders` : data penjemputan sampah dan status order
- `driver_locations` : riwayat lokasi petugas saat mengantarkan/menjemput
- `harga_sampah` : daftar harga sampah per jenis/subjenis
- `transactions` : log transaksi
- `wallets` : saldo wallet pengguna
- `drivers` : data driver/petugas

### Import database
Jika database belum tersedia, import file SQL berikut:
```bash
mysql -u root -p < "bank_sampah (1).sql"
```

Atau melalui phpMyAdmin / MySQL Workbench.

---

## 6. Frontend Website

### Lokasi aplikasi
```text
pundesari/
```

### Teknologi
- React.js
- React Bootstrap
- React Router
- Leaflet / React Leaflet
- Socket.IO Client
- Axios
- Google OAuth

### Fitur website
- tampilan dashboard web untuk admin dan pengguna
- manajemen data sampah dan harga
- monitoring transaksi dan order
- integrasi dengan backend API yang sama

### Jalankan website
```bash
cd pundesari
npm install
npm start
```

Aplikasi biasanya berjalan di:
```text
http://localhost:3000
```

---

## 7. Frontend Mobile

### Lokasi aplikasi
```text
userendpetugas/
```

### Teknologi
- Flutter
- Provider
- Flutter Secure Storage
- http
- geolocator
- geocoding
- flutter_map
- latlong2
- socket_io_client
- google_sign_in

### Fitur mobile
- login/register
- dashboard pengguna dan petugas
- pembuatan order penjemputan sampah
- pemilihan lokasi dan alamat
- pelacakan petugas secara real-time
- update status order
- integrasi dengan backend yang sama

### Jalankan mobile
```bash
cd userendpetugas
flutter pub get
flutter run
```

Untuk emulator Android, endpoint backend biasanya diarahkan ke:
```text
http://10.0.2.2:5000
```

---

## 8. Alur Fitur Utama

### Untuk pengguna
- login/register
- membuat order penjemputan sampah
- melihat status order
- melihat riwayat transaksi

### Untuk petugas
- login ke akun petugas
- melihat order yang menunggu
- menerima atau menolak order
- memperbarui lokasi dan status pengerjaan

### Untuk admin
- mengelola pengguna
- mengelola harga sampah
- melihat transaksi dan saldo
- mengelola order dan approval

---

## 9. Dokumentasi Pendukung

Dokumen tambahan yang tersedia:
- PRD.md : dokumen requirements dan scope proyek
- IMPLEMENTATION_GUIDE.md : panduan implementasi fitur dan alur sistem
- QUICK_FIX_GUIDE.md : panduan cepat untuk troubleshooting

---

## 10. Catatan Pengembangan

- Backend dan frontend mobile mengandalkan API yang sama, sehingga perubahan backend akan langsung memengaruhi semua antarmuka.
- Untuk pengembangan lokal, pastikan database MySQL/MariaDB sudah aktif sebelum menjalankan backend.
- Jika ada error terkait koneksi database, cek konfigurasi .env di folder backend.

---

## 11. Ringkasan Singkat

K-TRASH adalah solusi digital bank sampah yang menggabungkan:
- backend API yang kuat,
- database relasional untuk data operasional,
- frontend website untuk admin dan web access,
- frontend mobile untuk pengguna dan petugas lapangan.

Dengan arsitektur ini, seluruh proses penjemputan sampah dapat dikelola dari satu ekosistem yang terintegrasi.
