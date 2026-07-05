class Order {
  final int? id;
  final String nama;
  final String alamat;
  final String code;
  final String? jenisSampah;
  final String? catatan;
  final String? status;
  final double? userLat;
  final double? userLng;

  Order({
    this.id,
    required this.nama,
    required this.alamat,
    required this.code,
    this.jenisSampah,
    this.catatan,
    this.status,
    this.userLat,
    this.userLng,
  });
}
