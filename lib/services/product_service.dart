// File: lib/services/product_service.dart

import 'dart:convert';
import 'package:logger/logger.dart';
import '../models/product.dart';
import 'api_service.dart';

class ProductService {
  static final logger = Logger();

  // Get all products with search, filtering and pagination
  static Future<Map<String, dynamic>> getProducts({
    String? search,
    double? minPrice,
    double? maxPrice,
    int page = 1,
    int pageSize = 20,
    String sort = 'id',
  }) async {
    try {
      logger.i(
        'Fetching products - Page: $page, PageSize: $pageSize, Search: $search',
      );

      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'sort': sort,
      };

      if (search != null && search.isNotEmpty) queryParams['name'] = search;
      if (minPrice != null && minPrice > 0) {
        queryParams['min_price'] = minPrice.toString();
      }
      if (maxPrice != null && maxPrice > 0) {
        queryParams['max_price'] = maxPrice.toString();
      }

      final query = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final endpoint = query.isEmpty ? '/v1/products' : '/v1/products?$query';

      logger.d('Making request to: $endpoint');

      final response = await ApiService.getRequest(endpoint, includeAuth: true);

      logger.i('Products response status: ${response.statusCode}');
      logger.d('Products response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        logger.d('Parsed JSON keys: ${json.keys.toList()}');

        // Extract products array
        final productsData = json['products'];
        if (productsData == null) {
          logger.w('No products field found in response');
          return {'products': <Product>[], 'metadata': {}};
        }

        if (productsData is! List) {
          logger.e('Products data is not a list: ${productsData.runtimeType}');
          throw Exception(
            'Invalid response format: products field is not a list',
          );
        }

        final List<dynamic> productsList = productsData;
        logger.i('Found ${productsList.length} products in response');

        // Parse products
        final products = <Product>[];
        for (int i = 0; i < productsList.length; i++) {
          try {
            final productData = productsList[i];
            if (productData is Map<String, dynamic>) {
              final product = Product.fromJson(productData);
              products.add(product);
              logger.d(
                'Parsed product ${i + 1}: ${product.name} (\$${product.price})',
              );
            } else {
              logger.w(
                'Product data at index $i is not a map: ${productData.runtimeType}',
              );
            }
          } catch (e) {
            logger.e('Failed to parse product at index $i: $e');
            continue;
          }
        }

        // Extract metadata
        final metadata = json['metadata'] ?? {};
        logger.i(
          'Successfully parsed ${products.length} products with metadata: $metadata',
        );

        return {'products': products, 'metadata': metadata};
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Products access forbidden: $errorMsg');
        throw Exception('You do not have permission to view products');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to fetch products: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Get products exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to fetch products: $e');
      }
    }
  }

  // Get product by ID
  static Future<Product> getProduct(int productId) async {
    try {
      logger.i('Fetching product with ID: $productId');

      final response = await ApiService.getRequest(
        '/v1/products/$productId',
        includeAuth: true,
      );

      logger.i('Get product response status: ${response.statusCode}');
      logger.d('Get product response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final product = Product.fromJson(json['product']);
        logger.i(
          'Product fetched successfully: ${product.name} (\$${product.price})',
        );
        return product;
      } else if (response.statusCode == 404) {
        logger.w('Product not found: $productId');
        throw Exception('Product not found');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to fetch product: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Get product exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to fetch product: $e');
      }
    }
  }

  // Create product (cashier/admin only)
  static Future<Product> createProduct({
    required String name,
    required double price,
  }) async {
    try {
      logger.i('Creating product: $name (\$${price.toStringAsFixed(2)})');

      final response = await ApiService.postRequest('/v1/products', {
        'name': name,
        'price': price,
      }, includeAuth: true);

      logger.i('Create product response status: ${response.statusCode}');
      logger.d('Create product response body: ${response.body}');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final product = Product.fromJson(json['product']);
        logger.i(
          'Product created successfully: ${product.name} (ID: ${product.id})',
        );
        return product;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Create product forbidden: $errorMsg');
        throw Exception('You do not have permission to create products');
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Product validation failed: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to create product: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Create product exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to create product: $e');
      }
    }
  }

  // Update product (cashier/admin only)
  static Future<Product> updateProduct(
    int productId,
    Map<String, dynamic> updates,
  ) async {
    try {
      logger.i('Updating product: $productId with data: $updates');

      final response = await ApiService.putRequest(
        '/v1/products/$productId',
        updates,
        includeAuth: true,
      );

      logger.i('Update product response status: ${response.statusCode}');
      logger.d('Update product response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final product = Product.fromJson(json['product']);
        logger.i('Product updated successfully: ${product.name}');
        return product;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Update product forbidden: $errorMsg');
        throw Exception('You do not have permission to update products');
      } else if (response.statusCode == 404) {
        logger.w('Product not found for update: $productId');
        throw Exception('Product not found');
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Product validation failed: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to update product: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Update product exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to update product: $e');
      }
    }
  }

  // Delete product (cashier/admin only)
  static Future<void> deleteProduct(int productId) async {
    try {
      logger.i('Deleting product: $productId');

      final response = await ApiService.deleteRequest(
        '/v1/products/$productId',
        includeAuth: true,
      );

      logger.i('Delete product response status: ${response.statusCode}');
      logger.d('Delete product response body: ${response.body}');

      if (response.statusCode == 204) {
        logger.i('Product deleted successfully: $productId');
        return;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Delete product forbidden: $errorMsg');
        throw Exception('You do not have permission to delete products');
      } else if (response.statusCode == 404) {
        logger.w('Product not found for deletion: $productId');
        throw Exception('Product not found');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to delete product: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Delete product exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to delete product: $e');
      }
    }
  }
}
