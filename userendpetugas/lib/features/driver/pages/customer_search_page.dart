import 'package:flutter/material.dart';
import 'weigh_waste_page.dart';

const primaryColor = Color(0xFF4CAF50);

class CustomerSearchPage extends StatefulWidget {
  final int driverId;
  final int orderId;

  const CustomerSearchPage({
    super.key,
    required this.driverId,
    required this.orderId,
  });

  @override
  State<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends State<CustomerSearchPage> {
  final TextEditingController kodeController = TextEditingController();

  Map<String, String>? dataUser;

  final Map<String, Map<String, String>> dummyDatabase = {
    "0025": {
      "nama": "Bodida",
      "alamat": "RT 10, Desa Sigungguan",
      "saldo": "Rp 75.000",
    },
    "0027": {
      "nama": "Slamet",
      "alamat": "Desa Kedungrejo",
      "saldo": "Rp 50.000",
    },
  };

  /// Auto search + validasi
  void cariUser() {
    String kode = kodeController.text.trim();

    if (kode.isEmpty) {
      setState(() => dataUser = null);
      return;
    }

    if (dummyDatabase.containsKey(kode)) {
      setState(() {
        dataUser = dummyDatabase[kode];
      });
    } else {
      setState(() {
        dataUser = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F1F1),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Center(
                child: Text(
                  "Pencarian Customer",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Input
              const Text("Masukkan Kode Customer"),
              const SizedBox(height: 8),

              TextField(
                controller: kodeController,
                onChanged: (value) => cariUser(),
                decoration: InputDecoration(
                  hintText: "Contoh: 0025",
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Result
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: dataUser != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Hasil Pencarian",
                            style: TextStyle(color: Colors.grey),
                          ),

                          const SizedBox(height: 10),

                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 35,
                                  backgroundColor: Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dataUser!["nama"]!,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dataUser!["alamat"]!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        dataUser!["saldo"]!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            "Masukkan kode untuk mencari customer",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 20),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dataUser == null
                        ? Colors.grey.shade400
                        : primaryColor,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: dataUser == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WeighWastePage(
                                user: dataUser!,
                                driverId: widget.driverId,
                                orderId: widget.orderId,
                              ),
                            ),
                          );
                        },
                  child: const Text(
                    "Lanjut Timbang",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
