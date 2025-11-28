// File: lib/services/sale_service.dart

import 'dart:convert';
import 'package:logger/logger.dart';
import '../models/sale.dart';
import '../models/user.dart';
import '../models/product.dart';
import 'api_service.dart';

class SaleService {
  static final logger = Logger();

  // Get all sales with search, filtering and pagination (copied from ProductService)
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
    try {
      logger.i('Fetching sales - Page: $page, PageSize: $pageSize');

      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'sort': sort,
      };

      if (userId != null && userId > 0) {
        queryParams['user_id'] = userId.toString();
      }
      if (productId != null && productId > 0) {
        queryParams['product_id'] = productId.toString();
      }
      if (minQuantity != null && minQuantity > 0) {
        queryParams['min_qty'] = minQuantity.toString();
      }
      if (maxQuantity != null && maxQuantity > 0) {
        queryParams['max_qty'] = maxQuantity.toString();
      }
      if (startDate != null) {
        queryParams['min_date'] = startDate.toIso8601String();
      }
      if (endDate != null) queryParams['max_date'] = endDate.toIso8601String();

      final query = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final endpoint = query.isEmpty ? '/v1/sales' : '/v1/sales?$query';

      logger.d('Making request to: $endpoint');

      final response = await ApiService.getRequest(endpoint, includeAuth: true);

      logger.i('Sales response status: ${response.statusCode}');
      logger.d('Sales response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        logger.d('Parsed JSON keys: ${json.keys.toList()}');

        // Extract sales array (exactly like products)
        final salesData = json['sales'];
        if (salesData == null) {
          logger.w('No sales field found in response');
          return {'sales': <Sale>[], 'metadata': {}};
        }

        if (salesData is! List) {
          logger.e('Sales data is not a list: ${salesData.runtimeType}');
          throw Exception('Invalid response format: sales field is not a list');
        }

        final List<dynamic> salesList = salesData;
        logger.i('Found ${salesList.length} sales in response');

        // Parse sales (exactly like products)
        final sales = <Sale>[];
        for (int i = 0; i < salesList.length; i++) {
          try {
            final saleData = salesList[i];
            if (saleData is Map<String, dynamic>) {
              final sale = Sale.fromJson(saleData);
              sales.add(sale);
              logger.d(
                'Parsed sale ${i + 1}: ID ${sale.id}, Cashier ${sale.userId}, Product ${sale.productId}',
              );
            } else {
              logger.w(
                'Sale data at index $i is not a map: ${saleData.runtimeType}',
              );
            }
          } catch (e) {
            logger.e('Failed to parse sale at index $i: $e');
            continue;
          }
        }

        // Extract metadata (exactly like products)
        final metadata = json['metadata'] ?? {};
        logger.i(
          'Successfully parsed ${sales.length} sales with metadata: $metadata',
        );

        return {'sales': sales, 'metadata': metadata};
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Sales access forbidden: $errorMsg');
        throw Exception('You do not have permission to view sales');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to fetch sales: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Get sales exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to fetch sales: $e');
      }
    }
  }

  // Create sale (copied from ProductService pattern)
  static Future<Sale> createSale({
    required int userId,
    required int productId,
    required int quantity,
  }) async {
    try {
      logger.i(
        'Creating sale: User $userId, Product $productId, Qty $quantity',
      );

      final response = await ApiService.postRequest('/v1/sales', {
        'user_id': userId,
        'product_id': productId,
        'quantity': quantity,
      }, includeAuth: true);

      logger.i('Create sale response status: ${response.statusCode}');
      logger.d('Create sale response body: ${response.body}');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final sale = Sale.fromJson(json['sale']); // Exactly like products
        logger.i('Sale created successfully: ${sale.id}');
        return sale;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Create sale forbidden: $errorMsg');
        throw Exception('You do not have permission to create sales');
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Sale validation failed: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to create sale: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Create sale exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to create sale: $e');
      }
    }
  }

  // Get sale by ID (copied from ProductService pattern)
  static Future<Sale> getSale(int saleId) async {
    try {
      logger.i('Fetching sale with ID: $saleId');

      final response = await ApiService.getRequest(
        '/v1/sales/$saleId',
        includeAuth: true,
      );

      logger.i('Get sale response status: ${response.statusCode}');
      logger.d('Get sale response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final sale = Sale.fromJson(json['sale']); // Exactly like products
        logger.i('Sale fetched successfully: ID ${sale.id}');
        return sale;
      } else if (response.statusCode == 404) {
        logger.w('Sale not found: $saleId');
        throw Exception('Sale not found');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to fetch sale: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Get sale exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to fetch sale: $e');
      }
    }
  }

  // Update sale (copied from ProductService pattern)
  static Future<Sale> updateSale(
    int saleId,
    Map<String, dynamic> updates,
  ) async {
    try {
      logger.i('Updating sale: $saleId with data: $updates');

      final response = await ApiService.putRequest(
        '/v1/sales/$saleId',
        updates,
        includeAuth: true,
      );

      logger.i('Update sale response status: ${response.statusCode}');
      logger.d('Update sale response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final sale = Sale.fromJson(json['sale']); // Exactly like products
        logger.i('Sale updated successfully: ID ${sale.id}');
        return sale;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Update sale forbidden: $errorMsg');
        throw Exception('You do not have permission to update sales');
      } else if (response.statusCode == 404) {
        logger.w('Sale not found for update: $saleId');
        throw Exception('Sale not found');
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Sale validation failed: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to update sale: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Update sale exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to update sale: $e');
      }
    }
  }

  // Delete sale (copied from ProductService pattern)
  static Future<void> deleteSale(int saleId) async {
    try {
      logger.i('Deleting sale: $saleId');

      final response = await ApiService.deleteRequest(
        '/v1/sales/$saleId',
        includeAuth: true,
      );

      logger.i('Delete sale response status: ${response.statusCode}');
      logger.d('Delete sale response body: ${response.body}');

      if (response.statusCode == 200) {
        // Your API returns 200, not 204 like products
        logger.i('Sale deleted successfully: $saleId');
        return;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Delete sale forbidden: $errorMsg');
        throw Exception('You do not have permission to delete sales');
      } else if (response.statusCode == 404) {
        logger.w('Sale not found for deletion: $saleId');
        throw Exception('Sale not found');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to delete sale: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Delete sale exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to delete sale: $e');
      }
    }
  }

  // Helper methods for dropdowns
  static Future<List<User>> getUsers() async {
    try {
      final response = await ApiService.getRequest(
        '/v1/user',
        includeAuth: true,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> usersJson = json['users'] ?? [];
        return usersJson.map((u) => User.fromJson(u)).toList();
      }
      return [];
    } catch (e) {
      logger.w('Failed to fetch users for dropdown: $e');
      return [];
    }
  }

  static Future<List<Product>> getProducts() async {
    try {
      final response = await ApiService.getRequest(
        '/v1/products',
        includeAuth: true,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> productsJson = json['products'] ?? [];
        return productsJson.map((p) => Product.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      logger.w('Failed to fetch products for dropdown: $e');
      return [];
    }
  }
}
