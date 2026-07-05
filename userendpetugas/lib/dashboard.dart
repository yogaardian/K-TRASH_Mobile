import 'package:flutter/material.dart';
import 'pickup_page2.dart';
import 'hasil_simpan_page.dart';
import 'riwayat_page.dart';
import 'data/user_data.dart';
import 'profil_page.dart';

import 'services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// UNTUK BIASA (plastik, kertas, dll)

// Gunakan ApiService untuk semua API

Future<List<dynamic>> fetchHarga(String jenis) async {
  try {
    return await ApiService.getHarga(jenis);
  } catch (e) {
    return [];
  }
}

Future<List<dynamic>> fetchHargaSub(String jenis, String sub) async {
  try {
    return await ApiService.getHargaSub(jenis, sub);
  } catch (e) {
    return [];
  }
}

class DashboardPage extends StatefulWidget {
  final String username;
  final int userId;

  const DashboardPage({
    super.key,
    required this.username,
    required this.userId,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Variable untuk menyimpan kategori yang aktif
  String selectedCategory = 'Anorganik';

  // Wallet state
  double balance = 0.0;
  bool isBalanceLoading = true;
  String? balanceError;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final data = await ApiService.getUserBalance(widget.userId, token);
      final num balanceValue = (data['balance'] ?? data['saldo'] ?? data['total_balance'] ?? 0) as num;
      setState(() {
        balance = balanceValue.toDouble();
        isBalanceLoading = false;
        balanceError = null;
      });
    } catch (e) {
      setState(() {
        balanceError = e.toString();
        isBalanceLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // ===== CUSTOM APP BAR =====
            _buildHeader(),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildWalletCard(),
                    const SizedBox(height: 20),
                    _buildPickupBanner(),
                    const SizedBox(height: 24),

                    // Label Section
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Pilih Tipe Sampah',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Chips Kategori Interaktif
                    _buildCategoryChips(),

                    const SizedBox(height: 16),

                    // Daftar Item yang Dinamis
                    _buildWasteList(),

                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.green.shade600,
        child: const Icon(Icons.recycling, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // Header
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.assignment_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RiwayatPage(total: 0, data: riwayatGlobal),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, ${widget.username} 👋',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'ID: ${widget.userId}',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          const CircleAvatar(
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a'),
          ),
        ],
      ),
    );
  }

  // Card Saldo
  Widget _buildWalletCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saldo Poin Kamu',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (isBalanceLoading)
                const CircularProgressIndicator(color: Colors.white)
              else if (balanceError != null)
                const Text(
                  'Error loading balance',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                )
              else
                Text(
                  'Rp ${balance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }

  // Banner Jemput
  Widget _buildPickupBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PickupPage(username: widget.username),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_shipping_rounded,
              color: Colors.blue.shade700,
              size: 32,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Jemput Sampah',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Petugas akan datang ke lokasimu',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.blue.shade700,
            ),
          ],
        ),
      ),
    );
  }

  // Chips Kategori
  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _categoryChip('Anorganik'),
          const SizedBox(width: 8),
          _categoryChip('Organik'),
          const SizedBox(width: 8),
          _categoryChip('Lainnya'),
        ],
      ),
    );
  }

  Widget _categoryChip(String title) {
    bool isActive = selectedCategory == title;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedCategory = title;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.green.shade600 : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [BoxShadow(color: Colors.black12, blurRadius: 4)],
            border: isActive ? null : Border.all(color: Colors.grey.shade200),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // List Item Sampah
  Widget _buildWasteList() {
    if (selectedCategory == 'Anorganik') {
      return Column(
        children: [
          _item(
            'Sampah Plastik',
            'sampah yang bahanya terbuat dari plastik',
            Icons.shopping_bag_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PlasticDetailPage(),
              ),
            ),
          ),
          _item(
            'Sampah Kertas',
            'sampah yang bahannya dari kertas',
            Icons.inventory_2_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PaperDetailPage()),
            ),
          ),
          _item(
            'Logam dan besi ',
            'barang yang sudah tidak di gunakan',
            Icons.settings_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MetalDetailPage()),
            ),
          ),
          _item(
            'Sampah Kaca',
            'kaca yang pecah dan tidak di pakai',
            Icons.blur_on_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GlassDetailPage()),
            ),
          ),
        ],
      );
    } else if (selectedCategory == 'Organik') {
      return Column(
        children: [
          _item(
            'Sisa Makanan',
            'nasi, sayur, dan lauk pauk',
            Icons.restaurant_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FoodWasteDetailPage(),
              ),
            ),
          ),
          _item(
            'Sampah Kebun',
            'daun kering dan sisa tanaman',
            Icons.eco_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GardenWasteDetailPage(),
              ),
            ),
          ),
          _item(
            'Sampah Kayu',
            'ranting pohon dan serbuk kayu',
            Icons.grass,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WoodWasteDetailPage(),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _item(
            'Peralatan Komunikasi',
            'Smartphone, Radio, Telepon',
            Icons.phone_android,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OthersDetailPage(
                  jenis: "elektronik",
                  sub: "komunikasi",
                  title: "Peralatan Komunikasi",
                ),
              ),
            ),
          ),
          _item(
            'Rumah Tangga Kecil',
            'Mixer, Setrika, Blender',
            Icons.kitchen,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OthersDetailPage(
                  jenis: "elektronik",
                  sub: "rumah_tangga",
                  title: "Rumah Tangga Kecil",
                ),
              ),
            ),
          ),
          _item(
            'Lainnya',
            'barang bekas lainya ',
            Icons.battery_alert,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OthersDetailPage(
                  jenis: "lain",
                  sub: "lainnya",
                  title: "lainnya",
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _item(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.green.shade700, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Aktivitas Terbaru
  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktivitas Terbaru',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_run, color: Colors.orange),
              ),
              title: const Text(
                'Mitra sedang menuju lokasi',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Estimasi tiba 13:30 PM',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Nav
  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home_filled, color: Colors.green),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.assignment_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RiwayatPage(total: 0, data: riwayatGlobal),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- DETAIL PAGES ANORGANIK ---

class PlasticDetailPage extends StatelessWidget {
  const PlasticDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Jenis Sampah Plastik',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Divider(color: Colors.green, thickness: 2),
          Expanded(
            child: FutureBuilder(
              future: fetchHarga("plastik"),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data as List;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: data.map((item) {
                    return _priceItem(item['nama'], item['harga'].toString());
                  }).toList(),
                );
              },
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }
}

class PaperDetailPage extends StatelessWidget {
  const PaperDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Jenis Sampah Kertas',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Divider(color: Colors.green, thickness: 2),
          Expanded(
            child: FutureBuilder(
              future: fetchHarga("kertas"),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data as List;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: data.map((item) {
                    return _priceItem(item['nama'], item['harga'].toString());
                  }).toList(),
                );
              },
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }
}

class MetalDetailPage extends StatelessWidget {
  const MetalDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Jenis Sampah logam dan besi',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Divider(color: Colors.green, thickness: 2),
          Expanded(
            child: FutureBuilder(
              future: fetchHarga("logam"),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data as List;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: data.map((item) {
                    return _priceItem(item['nama'], item['harga'].toString());
                  }).toList(),
                );
              },
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }
}

class GlassDetailPage extends StatelessWidget {
  const GlassDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Jenis Sampah Kaca',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Divider(color: Colors.green, thickness: 2),
          Expanded(
            child: FutureBuilder(
              future: fetchHarga("kaca"),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data as List;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: data.map((item) {
                    return _priceItem(item['nama'], item['harga'].toString());
                  }).toList(),
                );
              },
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }
}

// --- DETAIL PAGES ORGANIK (BERDASARKAN GAMBAR TERBARU) ---

class FoodWasteDetailPage extends StatelessWidget {
  const FoodWasteDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Jenis Sisa Makanan',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Divider(color: Colors.green, thickness: 2),
          Expanded(
            child: FutureBuilder(
              future: fetchHarga("makanan"),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data as List;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: data.map((item) {
                    return _priceItem(item['nama'], item['harga'].toString());
                  }).toList(),
                );
              },
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }
}

class GardenWasteDetailPage extends StatelessWidget {
  const GardenWasteDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Jenis Sampah kebun',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Divider(color: Colors.green, thickness: 2),
          Expanded(
            child: FutureBuilder(
              future: fetchHarga("kebun"),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data as List;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: data.map((item) {
                    return _priceItem(item['nama'], item['harga'].toString());
                  }).toList(),
                );
              },
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }
}

class WoodWasteDetailPage extends StatelessWidget {
  const WoodWasteDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Jenis sampah Kayu',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Divider(color: Colors.green, thickness: 2),
          Expanded(
            child: FutureBuilder(
              future: fetchHarga("kayu"),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data as List;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: data.map((item) {
                    return _priceItem(item['nama'], item['harga'].toString());
                  }).toList(),
                );
              },
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }
}

class OthersDetailPage extends StatelessWidget {
  final String jenis;
  final String sub;
  final String title;

  const OthersDetailPage({
    super.key,
    required this.jenis,
    required this.sub,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder(
        future: fetchHargaSub(jenis, sub),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data as List;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: data.map((item) {
              return _priceItem(item['nama'], item['harga'].toString());
            }).toList(),
          );
        },
      ),
    );
  }
}

// --- HELPER WIDGETS ---
Map<String, int> jumlahKg = {};

Widget _priceItem(String name, String price) {
  jumlahKg.putIfAbsent(name, () => 0);

  return StatefulBuilder(
    builder: (context, setState) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 BAGIAN ASLI (TIDAK DIUBAH)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'harga per kg',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '$price/Kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (jumlahKg[name]! > 0) {
                          jumlahKg[name] = jumlahKg[name]! - 1;
                        }
                      });
                    },
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                  ),

                  Text("${jumlahKg[name]} Kg"),

                  IconButton(
                    onPressed: () {
                      setState(() {
                        jumlahKg[name] = jumlahKg[name]! + 1;
                      });
                    },
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildBottomButtons(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(20.0),
    child: Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Kembali', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => simpanData(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    ),
  );
}

void simpanData(BuildContext context) {
  List<Map<String, dynamic>> hasil = [];

  jumlahKg.forEach((nama, kg) {
    if (kg > 0) {
      hasil.add({"nama": nama, "kg": kg});
    }
  });

  if (hasil.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Belum ada yang dipilih")));
    return;
  }

  // 🔥 PINDAH KE HALAMAN HASIL
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => HasilSimpanPage(data: hasil)),
  );
}
