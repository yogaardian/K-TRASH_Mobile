import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';
import 'tracking_petugas_page.dart';

final String _backendBaseUrl = ApiConstants.baseUrl;

class MencariPetugasPage extends StatefulWidget {
  // 1. Tambahkan parameter username di constructor agar bisa menerima data dari halaman sebelumnya
  final String username;
  final int orderId;

  const MencariPetugasPage({
    super.key,
    required this.username,
    required this.orderId,
  });

  @override
  State<MencariPetugasPage> createState() => _MencariPetugasPageState();
}

class _MencariPetugasPageState extends State<MencariPetugasPage> {
  Timer? _orderStatusTimer;

  @override
  void initState() {
    super.initState();
    _orderStatusTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final res = await http.get(
          Uri.parse('$_backendBaseUrl/orders/${widget.orderId}'),
        );

        if (res.statusCode != 200) return;

        final data = jsonDecode(res.body);
        if (data['status'] == 'assigned') {
          timer.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingPetugasPage(
                username: widget.username,
                orderId: widget.orderId,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error polling order status: $e');
      }
    });
  }

  @override
  void dispose() {
    _orderStatusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF0F9F1,
      ), // Warna latar belakang hijau pucat
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 100),
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: const Color(
                0xFFB4BCB4,
              ), // Warna abu-abu transparan sesuai gambar
              child: const Column(
                children: [
                  Text(
                    'Mencari Petugas Terdekat .....',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Mohon tunggu',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Loading Animation Placeholder
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey, width: 2),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Loading..',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Information Text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Kami sedang mencari petugas yang tersedia di sekitar anda .',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),

            const Spacer(),

            // Cancel Button
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Kembali ke halaman sebelumnya
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(
                    color: Color(0xFF4CAF50),
                  ), // Border hijau
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 12,
                  ),
                ),
                child: const Text('Batalkan', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
