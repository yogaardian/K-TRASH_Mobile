import 'dart:convert';

class UserModel {
  final int id;
  final String nama;
  final String email;
  final String role;
  final String? nomorHp;
  final String? profilePhoto;
  final double? saldo;
  final double? saldoHold;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    this.nomorHp,
    this.profilePhoto,
    this.saldo,
    this.saldoHold,
    this.createdAt,
    this.updatedAt,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'email': email,
      'role': role,
      'nomor_hp': nomorHp,
      'profile_photo': profilePhoto,
      'saldo': saldo,
      'saldo_hold': saldoHold,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      nama: json['nama'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      nomorHp: json['nomor_hp'] as String?,
      profilePhoto: json['profile_photo'] as String?,
      saldo: (json['saldo'] as num?)?.toDouble(),
      saldoHold: (json['saldo_hold'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  // Copy with
  UserModel copyWith({
    int? id,
    String? nama,
    String? email,
    String? role,
    String? nomorHp,
    String? profilePhoto,
    double? saldo,
    double? saldoHold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      role: role ?? this.role,
      nomorHp: nomorHp ?? this.nomorHp,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      saldo: saldo ?? this.saldo,
      saldoHold: saldoHold ?? this.saldoHold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, nama: $nama, email: $email, role: $role)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
