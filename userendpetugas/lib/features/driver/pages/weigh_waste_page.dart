import 'package:flutter/material.dart';
import 'transaction_summary_page.dart';

class WeighWastePage extends StatelessWidget {
  final Map<String, String> user;
  final int driverId;
  final int orderId;

  const WeighWastePage({
    super.key,
    required this.user,
    required this.driverId,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F1F1),
      appBar: AppBar(
        title: const Text("Timbang Sampah"),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User info
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                ),
                title: Text(user["nama"]!),
                subtitle: Text(user["alamat"]!),
              ),
            ),

            const SizedBox(height: 20),

            // Categories
            _kategoriItem(context, "Organik"),
            const SizedBox(height: 12),
            _kategoriItem(context, "Anorganik"),
            const SizedBox(height: 12),
            _kategoriItem(context, "Lainnya"),

            const Spacer(),

            // Buttons
            Row(
              children: [
                // Cancel
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Batal"),
                  ),
                ),

                const SizedBox(width: 12),

                // Next
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionSummaryPage(
                            keranjang: [],
                            user: user,
                            driverId: driverId,
                            orderId: orderId,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "Selanjutnya",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kategoriItem(BuildContext context, String title) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$title: Data belum diperbarui"),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 5),
          ],
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
