// File: lib/models/user.dart

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int version;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    required this.version,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: _parseId(json['ID'] ?? json['id']),
        firstName: json['FirstName'] ?? json['first_name'] ?? '',
        lastName: json['LastName'] ?? json['last_name'] ?? '',
        email: json['Email'] ?? json['email'] ?? '',
        role: json['Role'] ?? json['role'] ?? 'guest',
        isActive: json['IsActive'] ?? json['is_active'] ?? false,
        createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
        updatedAt: _parseOptionalDate(json['UpdatedAt'] ?? json['updated_at']),
        version: json['Version'] ?? json['version'] ?? 1,
      );
    } catch (e) {
      throw FormatException('Error parsing User JSON: $e');
    }
  }

  static int _parseId(dynamic value) {
    if (value == null) throw FormatException('User ID cannot be null');
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw FormatException('Invalid ID format: $value');
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.parse(value);
    return null;
  }

  @override
  String toString() {
    return 'User(id: $id, firstName: $firstName, lastName: $lastName, email: $email, role: $role)';
  }
}
