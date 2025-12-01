import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:sales_app/models/product.dart';
import 'package:sales_app/models/sale.dart';
import 'package:sales_app/models/user.dart';
import 'package:sales_app/services/chatbot_service.dart';
import 'package:sales_app/utils/preferences.dart';

class ApiClient {
  static final logger = Logger();

  // ---------------------------------------------------------------------------
  // Generic API Methods
  // ---------------------------------------------------------------------------

  static Future<String> getBaseUrl() async {
    return await AppPreferences.getApiBaseUrl();
  }

  static Future<Map<String, String>> getHeaders({
    bool includeAuth = false,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    if (includeAuth) {
      final token = await AppPreferences.getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<http.Response> getRequest(
    String endpoint, {
    bool includeAuth = false,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(includeAuth: includeAuth);
    return await http.get(url, headers: headers);
  }

  static Future<http.Response> postRequest(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(includeAuth: includeAuth);
    return await http.post(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> putRequest(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(includeAuth: includeAuth);
    return await http.put(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> deleteRequest(
    String endpoint, {
    bool includeAuth = false,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(includeAuth: includeAuth);
    return await http.delete(url, headers: headers);
  }

  static String parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      if (json['error'] is Map<String, dynamic>) {
        final errorMap = json['error'] as Map<String, dynamic>;
        if (errorMap.isNotEmpty) {
          return errorMap.values.first.toString();
        }
      } else if (json['error'] is String) {
        return json['error'] as String;
      } else if (json['message'] is String) {
        return json['message'] as String;
      }
      return json['error'] ?? 'Unknown error occurred';
    } catch (e) {
      return 'Unknown error occurred + response code: ${response.statusCode}';
    }
  }

  // ---------------------------------------------------------------------------
  // Auth Methods
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      logger.i('Attempting login for email: $email');
      final response = await postRequest('/v1/tokens/authentication', {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final authToken = json['authentication_token'] as String;
        await AppPreferences.saveAuthToken(authToken);
        
        final user = await getCurrentUser();
        await AppPreferences.saveUserId(user.id);
        await AppPreferences.saveUserRole(user.role);
        
        return {'token': authToken, 'user': user};
      } else {
        throw Exception(parseError(response));
      }
    } catch (e) {
      await AppPreferences.clearUserData();
      rethrow;
    }
  }

  static Future<User> getCurrentUser() async {
    final response = await getRequest('/v1/users/profile', includeAuth: true);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return User.fromJson(json['user']);
    } else if (response.statusCode == 401) {
      await AppPreferences.clearUserData();
      throw Exception('Authentication required');
    } else {
      throw Exception(parseError(response));
    }
  }

  static Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await postRequest('/v1/users', {
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
    });
    if (response.statusCode != 201) {
      throw Exception(parseError(response));
    }
  }

  static Future<void> logout() async {
    try {
      await deleteRequest('/v1/tokens/authentication', includeAuth: true);
    } finally {
      await AppPreferences.clearUserData();
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await AppPreferences.getAuthToken();
    if (token == null || token.isEmpty) return false;
    try {
      await getCurrentUser();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getCurrentUserRole() async {
    return await AppPreferences.getUserRole();
  }

  // ---------------------------------------------------------------------------
  // Product Methods
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getProducts({
    String? search,
    double? minPrice,
    double? maxPrice,
    int page = 1,
    int pageSize = 20,
    String sort = 'id',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort': sort,
    };
    if (search != null && search.isNotEmpty) queryParams['name'] = search;
    if (minPrice != null) queryParams['min_price'] = minPrice.toString();
    if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();

    final query = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final endpoint = query.isEmpty ? '/v1/products' : '/v1/products?$query';

    final response = await getRequest(endpoint, includeAuth: true);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final productsList = (json['products'] as List)
          .map((p) => Product.fromJson(p))
          .toList();
      return {'products': productsList, 'metadata': json['metadata'] ?? {}};
    } else {
      throw Exception(parseError(response));
    }
  }

  static Future<Product> createProduct({
    required String name,
    required double price,
  }) async {
    final response = await postRequest(
      '/v1/products',
      {'name': name, 'price': price},
      includeAuth: true,
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Product.fromJson(json['product']);
    } else {
      throw Exception(parseError(response));
    }
  }

  // ---------------------------------------------------------------------------
  // Sale Methods
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getSales({
    int? userId,
    int? productId,
    int? minQuantity,
    int? maxQuantity,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
    String sort = 'id',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort': sort,
    };
    if (userId != null) queryParams['user_id'] = userId.toString();
    if (productId != null) queryParams['product_id'] = productId.toString();
    if (minQuantity != null) queryParams['min_qty'] = minQuantity.toString();
    if (maxQuantity != null) queryParams['max_qty'] = maxQuantity.toString();
    if (startDate != null) queryParams['min_date'] = startDate.toIso8601String();
    if (endDate != null) queryParams['max_date'] = endDate.toIso8601String();

    final query = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final endpoint = query.isEmpty ? '/v1/sales' : '/v1/sales?$query';

    final response = await getRequest(endpoint, includeAuth: true);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final salesList = (json['sales'] as List)
          .map((s) => Sale.fromJson(s))
          .toList();
      return {'sales': salesList, 'metadata': json['metadata'] ?? {}};
    } else {
      throw Exception(parseError(response));
    }
  }

  static Future<Sale> createSale({
    required int userId,
    required int productId,
    required int quantity,
  }) async {
    final response = await postRequest(
      '/v1/sales',
      {'user_id': userId, 'product_id': productId, 'quantity': quantity},
      includeAuth: true,
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Sale.fromJson(json['sale']);
    } else {
      throw Exception(parseError(response));
    }
  }

  // ---------------------------------------------------------------------------
  // User Methods
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getUsers({
    String? search,
    String? email,
    String? role,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
    String sort = 'id',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort': sort,
    };
    if (search != null) queryParams['name'] = search;
    if (email != null) queryParams['email'] = email;
    if (role != null) queryParams['role'] = role;
    if (isActive != null) queryParams['is_active'] = isActive.toString();

    final query = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final endpoint = query.isEmpty ? '/v1/user' : '/v1/user?$query';

    final response = await getRequest(endpoint, includeAuth: true);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final usersList = (json['users'] as List)
          .map((u) => User.fromJson(u))
          .toList();
      return {'users': usersList, 'metadata': json['metadata'] ?? {}};
    } else {
      throw Exception(parseError(response));
    }
  }

  // ---------------------------------------------------------------------------
  // Chatbot Methods
  // ---------------------------------------------------------------------------

  static Future<ChatResponse> sendChatbotMessage(String message) async {
    final response = await postRequest(
      '/v1/chatbot',
      {'message': message},
      includeAuth: true,
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return ChatResponse.fromJson(json['chatbot']);
    } else {
      throw Exception(parseError(response));
    }
  }
}
