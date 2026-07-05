class ProductModel {
  final int id;
  final String nama;
  final String deskripsi;
  final double harga;
  final String kategori;
  final int stok;
  final String? gambar;

  ProductModel({
    required this.id,
    required this.nama,
    required this.deskripsi,
    required this.harga,
    required this.kategori,
    required this.stok,
    this.gambar,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as int? ?? 0,
      nama: json['nama'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      harga: () {
        final raw = json['harga'];
        if (raw == null) return 0.0;
        if (raw is num) return raw.toDouble();
        if (raw is String) {
          final cleaned = raw.replaceAll(',', '');
          return double.tryParse(cleaned) ?? 0.0;
        }
        return 0.0;
      }(),
      kategori: json['kategori'] as String? ?? 'Sembako',
      stok: () {
        final raw = json['stok'];
        if (raw == null) return 0;
        if (raw is num) return raw.toInt();
        if (raw is String) {
          final cleaned = raw.replaceAll(',', '');
          return int.tryParse(cleaned) ?? 0;
        }
        return 0;
      }(),
      gambar: json['gambar'] as String?,
    );
  }
}
