class OrderModel {
  final int id;
  final int userId;
  final int? driverId;
  final String address;
  final double? userLat;
  final double? userLng;
  final String jenisSampah;
  final String? catatan;
  final String status;
  final String? sampahData;
  final double? totalBerat;
  final double? totalHarga;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderModel({
    required this.id,
    required this.userId,
    this.driverId,
    required this.address,
    this.userLat,
    this.userLng,
    required this.jenisSampah,
    this.catatan,
    required this.status,
    this.sampahData,
    this.totalBerat,
    this.totalHarga,
    this.createdAt,
    this.updatedAt,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'driver_id': driverId,
      'address': address,
      'user_lat': userLat,
      'user_lng': userLng,
      'jenis_sampah': jenisSampah,
      'catatan': catatan,
      'status': status,
      'sampah_data': sampahData,
      'total_berat': totalBerat,
      'total_harga': totalHarga,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Create from JSON
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      driverId: json['driver_id'] as int?,
      address: json['address'] as String? ?? '',
      userLat: (json['user_lat'] as num?)?.toDouble(),
      userLng: (json['user_lng'] as num?)?.toDouble(),
      jenisSampah: json['jenis_sampah'] as String? ?? '',
      catatan: json['catatan'] as String?,
      status: json['status'] as String? ?? 'pending',
      sampahData: json['sampah_data'] as String?,
      totalBerat: (json['total_berat'] as num?)?.toDouble(),
      totalHarga: (json['total_harga'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  // Copy with
  OrderModel copyWith({
    int? id,
    int? userId,
    int? driverId,
    String? address,
    double? userLat,
    double? userLng,
    String? jenisSampah,
    String? catatan,
    String? status,
    String? sampahData,
    double? totalBerat,
    double? totalHarga,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      driverId: driverId ?? this.driverId,
      address: address ?? this.address,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      jenisSampah: jenisSampah ?? this.jenisSampah,
      catatan: catatan ?? this.catatan,
      status: status ?? this.status,
      sampahData: sampahData ?? this.sampahData,
      totalBerat: totalBerat ?? this.totalBerat,
      totalHarga: totalHarga ?? this.totalHarga,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'OrderModel(id: $id, userId: $userId, status: $status)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}
