// File: lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/preferences.dart';

class ApiService {
  // Get the base URL from preferences
  static Future<String> getBaseUrl() async {
    return await AppPreferences.getApiBaseUrl();
  }

  // Helper method to create headers with authorization token
  static Future<Map<String, String>> getHeaders({
    // Whether to include the authorization token in the headers
    bool includeAuth = false,
  }) async {
    final headers = {'Content-Type': 'application/json'};

    // Include authorization token if required
    if (includeAuth) {
      final token = await AppPreferences.getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Generic GET request method
  static Future<http.Response> getRequest(
    String endpoint, {
    bool includeAuth = false,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(includeAuth: includeAuth);
    return await http.get(url, headers: headers);
  }

  // Generic POST request method
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

  // Generic PUT request method
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

  // Generic DELETE request method
  static Future<http.Response> deleteRequest(
    String endpoint, {
    bool includeAuth = false,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(includeAuth: includeAuth);
    return await http.delete(url, headers: headers);
  }

  // Parse Error from Response
  static String parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body);

      // Handle different error response formats
      if (json['error'] is Map<String, dynamic>) {
        // Validation errors (usually from 422 responses)
        final errorMap = json['error'] as Map<String, dynamic>;
        if (errorMap.isNotEmpty) {
          // Get the first error message
          final firstError = errorMap.values.first;
          return firstError.toString();
        }
      } else if (json['error'] is String) {
        // Simple error message
        return json['error'] as String;
      } else if (json['message'] is String) {
        // Some APIs use 'message' instead of 'error'
        return json['message'] as String;
      }
      // Fallback error message
      return json['error'] ?? 'Unknown error occurred';
    } catch (e) {
      return 'Unknown error occurred + response code: ${response.statusCode}';
    }
  }
}
