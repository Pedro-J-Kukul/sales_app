// File: lib/models/product.dart

class Product {
  final int id;
  final String name;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      return Product(
        // Handle both PascalCase (Go default) and snake_case
        id: _parseId(json['ID'] ?? json['id']),
        name: json['Name'] ?? json['name'] ?? '',
        price: _parsePrice(json['Price'] ?? json['price']),
        createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
        updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
      );
    } catch (e) {
      rethrow;
    }
  }

  static int _parseId(dynamic value) {
    if (value == null) throw FormatException('Product ID cannot be null');
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw FormatException('Invalid ID format: $value');
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.parse(value);
    return 0.0;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: \$${price.toStringAsFixed(2)})';
  }
}
