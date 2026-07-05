import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';

class PriceListPage extends StatefulWidget {
  const PriceListPage({Key? key}) : super(key: key);

  @override
  State<PriceListPage> createState() => _PriceListPageState();
}

class _PriceListPageState extends State<PriceListPage> {
  // Filter kategori bersifat UI-only selama provider belum expose
  // state kategori (lihat Gap Analysis poin 1).
  String? _selectedKategori;

  String _formatCurrency(double value) {
    return 'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')}';
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();

    // TODO: sambungkan ke field provider Anda yang sebenarnya jika nama
    // berbeda, contoh: dashboard.isLoadingHarga / dashboard.hargaErrorMessage
    final bool isLoading = false; // ganti sesuai provider, jika ada
    final String? errorMessage = null; // ganti sesuai provider, jika ada

    final allItems = dashboard.hargaSampah;

    // Ambil daftar kategori unik dari data yang ada, hanya jika model
    // item punya getter `kategori`. Bungkus dengan try agar tidak crash
    // bila field tidak tersedia.
    List<String> kategoriList = [];
    try {
      kategoriList = allItems
          .map((e) => (e as dynamic).kategori as String?)
          .whereType<String>()
          .toSet()
          .toList();
    } catch (_) {
      kategoriList = [];
    }

    final filteredItems = _selectedKategori == null
        ? allItems
        : allItems.where((e) {
            try {
              return (e as dynamic).kategori == _selectedKategori;
            } catch (_) {
              return true;
            }
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harga Sampah'),
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Header (meniru .harga-header) =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daftar Harga Sampah',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lihat harga terkini untuk setiap jenis sampah yang bisa kami terima',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // ===== Filter kategori (meniru .kategori-filter) =====
            if (kategoriList.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: kategoriList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final kategori = kategoriList[i];
                    final isActive = _selectedKategori == kategori;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedKategori = isActive ? null : kategori;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF16A34A) : Colors.white,
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEDF2EE),
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          kategori,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // ===== Body: loading / error / empty / list =====
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? Center(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : filteredItems.isEmpty
                          ? const Center(child: Text('Data tidak ditemukan'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, index) {
                                final item = filteredItems[index];
                                String? kategoriLabel;
                                try {
                                  kategoriLabel = (item as dynamic).kategori as String?;
                                } catch (_) {
                                  kategoriLabel = null;
                                }

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // icon box, meniru .harga-card-icon
                                        Container(
                                          width: 48,
                                          height: 48,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            Icons.recycling_outlined,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.subJenis,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_formatCurrency(item.harga)} / kg',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF16A34A),
                                                ),
                                              ),
                                              if (kategoriLabel != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Kategori: $kategoriLabel',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}