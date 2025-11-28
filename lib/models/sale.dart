// File: lib/models/sale.dart

class Sale {
  final int id;
  final int userId;
  final int productId;
  final int quantity;
  final DateTime soldAt;

  Sale({
    required this.id,
    required this.userId,
    required this.productId,
    required this.quantity,
    required this.soldAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    try {
      return Sale(
        // Using snake_case exactly like your API response
        id: _parseId(json['id']),
        userId: _parseId(json['user_id']),
        productId: _parseId(json['product_id']),
        quantity: _parseInt(json['quantity']),
        soldAt: _parseDate(json['sold_at']),
      );
    } catch (e) {
      rethrow;
    }
  }

  static int _parseId(dynamic value) {
    if (value == null) throw FormatException('ID cannot be null');
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw FormatException('Invalid ID format: $value');
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.parse(value);
    return 0;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'sold_at': soldAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Sale(id: $id, userId: $userId, productId: $productId, quantity: $quantity)';
  }
}
