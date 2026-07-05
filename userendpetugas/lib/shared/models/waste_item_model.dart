class WasteItemModel {
  final int id;
  final String name;

  WasteItemModel({
    required this.id,
    required this.name,
  });

  /// Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  /// Create from JSON
  factory WasteItemModel.fromJson(Map<String, dynamic> json) {
    return WasteItemModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  /// Copy with
  WasteItemModel copyWith({
    int? id,
    String? name,
  }) {
    return WasteItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  String toString() {
    return 'WasteItemModel(id: $id, name: $name)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WasteItemModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
