# Fitur Dashboard Mobile: History, Marketplace, Profile

## Ringkasan
Perubahan ini menambahkan fungsi navigasi dan halaman mobile yang terhubung dengan backend:

1. `History` sekarang mengarah ke halaman `HistoryPage` dan mengambil data riwayat pesanan pengguna dari endpoint backend `/orders/user/:userId`.
2. `Notifications` di bottom navigation diubah menjadi `Marketplace` dan mengarah ke halaman `MarketplacePage`.
3. `Profile` mengarah ke halaman `ProfilePage` yang menampilkan data pengguna dari `AuthProvider` dan dapat memperbarui profil melalui endpoint backend `/users/:id`.
4. Desain halaman dibuat responsif untuk berbagai ukuran layar dengan tata letak berbasis `LayoutBuilder`.

## File yang diubah

- `lib/features/dashboard/pages/user_dashboard_page.dart`
  - Perbarui ikon notifikasi menjadi marketplace.
  - Tetap mempertahankan tombol history dan profile.

- `lib/features/history/pages/history_page.dart`
  - Implementasi riwayat pesanan pengguna.
  - Tambahkan pemanggilan `OrderService.getUserOrders(userId)`.

- `lib/features/profile/pages/profile_page.dart`
  - Implementasi tampilan profil pengguna.
  - Tambahkan update profil dengan `UserService.updateProfile`.
  - Tambahkan refresh saldo backend via `UserService.getUserData`.

- `lib/features/marketplace/pages/marketplace_page.dart`
  - Implementasi daftar produk marketplace.
  - Tambahkan pencarian dan filter kategori.
  - Tambahkan pembelian produk melalui endpoint `/marketplace/products/:id/order`.

- `lib/services/marketplace_service.dart`
  - Tambahkan layanan marketplace untuk memanggil API backend.

- `lib/shared/models/product_model.dart`
  - Tambahkan model produk untuk marketplace.

## Endpoint Backend yang digunakan

- `GET /orders/user/:userId` — ambil riwayat pesanan pengguna.
- `GET /marketplace/products` — ambil daftar produk marketplace.
- `POST /marketplace/products/:id/order` — buat pesanan marketplace.
- `PATCH /users/:id` — perbarui data profile pengguna.
- `GET /user/balance/:id` — muat data saldo untuk profil dan marketplace.

## Tes dan verifikasi

1. Jalankan backend dan pastikan token autentikasi valid tersedia.
2. Jalankan aplikasi Flutter:
   - `flutter run`
3. Masuk sebagai pengguna.
4. Pastikan bottom navigation:
   - `Home` tetap di dashboard.
   - `History` membuka halaman riwayat pengguna.
   - `Marketplace` membuka halaman marketplace.
   - `Profile` membuka halaman profil pengguna.
5. Pada setiap halaman:
   - `History` menampilkan daftar pesanan atau pesan kosong jika belum ada.
   - `Marketplace` menampilkan daftar produk dan dapat melakukan pembelian.
   - `Profile` menampilkan data nama, email, role, dan saldo, serta dapat menyimpan perubahan profil.

## Catatan

- Semua panggilan API dilakukan melalui `ApiClient` dengan interceptor JWT.
- Halaman dibuat responsif menggunakan `LayoutBuilder` dan penentuan `crossAxisCount` dinamis.
- Komponen baru diformat menggunakan `dart format`.
