import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/secure_storage_helper.dart';
import './models/order.dart';
import 'driver_journey_page.dart';

const primaryColor = Color(0xFF4CAF50);

class DetailOrderPage extends StatelessWidget {
  final Order order;
  final int driverId;

  const DetailOrderPage({
    super.key,
    required this.order,
    required this.driverId,
  });

  Future<void> _acceptOrder(BuildContext context) async {
    try {
      final token = await SecureStorageHelper.getToken();
      final data = await ApiService.acceptOrder(order.id!, driverId, token);

      if (data['status'] == 'success') {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DriverJourneyPage(
                driverId: driverId,
                orderId: order.id!,
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Gagal menerima order')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F1F1),

      body: SafeArea(
        child: Column(
          children: [
            /// 🔙 HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Detail Order",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            /// 🗺️ MAP
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset("assets/image.png", fit: BoxFit.cover),
                ),
              ),
            ),

            /// 📄 CONTENT
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 👤 PROFIL
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: primaryColor,
                          child: Text(
                            order.nama[0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.nama,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(order.alamat),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// 📋 INFO ORDER
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xffF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          infoRow("Kode Customer", order.code),
                          infoRow(
                            "Jenis Sampah",
                            order.jenisSampah ?? "Tidak ada",
                          ),
                          infoRow(
                            "Catatan",
                            order.catatan ?? "Tidak ada catatan",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// 📞 ACTION BUTTON
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                            ),
                            onPressed: () {},
                            child: const Text("Chat"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                            onPressed: () {},
                            child: const Text("Telepon"),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    /// 🚚 BUTTON UTAMA
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _acceptOrder(context),
                        child: const Text(
                          "Ambil order",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔧 WIDGET BIAR RAPI
  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
