// File: lib/services/auth_service.dart

import 'dart:convert';
import 'package:logger/logger.dart';
import '../models/user.dart';
import '../utils/preferences.dart';
import 'api_service.dart';

class AuthService {
  static final logger = Logger();

  // Login user - only gets token, then fetches user profile
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      logger.i('Attempting login for email: $email');

      // Step 1: Get authentication token
      final response = await ApiService.postRequest(
        '/v1/tokens/authentication',
        {'email': email, 'password': password},
      );

      logger.i('Login response status: ${response.statusCode}');
      logger.d('Login response body: ${response.body}');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final authToken = json['authentication_token'] as String;

        // Save token first so we can make authenticated requests
        await AppPreferences.saveAuthToken(authToken);
        logger.i('Auth token saved successfully');

        // Step 2: Fetch user profile using the token
        final user = await getCurrentUser();

        // Step 3: Save additional user info
        await AppPreferences.saveUserId(user.id);
        await AppPreferences.saveUserRole(user.role);

        logger.i(
          'Login successful for user: ${user.firstName} ${user.lastName}',
        );
        return {'token': authToken, 'user': user};
      } else if (response.statusCode == 401) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Login failed - Unauthorized: $errorMsg');
        throw Exception(errorMsg);
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Login failed - Validation error: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Login failed with status ${response.statusCode}: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Login exception: $e');
      // Clear any partial data on error
      await AppPreferences.clearUserData();

      // Re-throw the exception to preserve the original error message
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Login error: $e');
      }
    }
  }

  // Get current authenticated user profile
  static Future<User> getCurrentUser() async {
    try {
      logger.i('Fetching current user profile');

      final response = await ApiService.getRequest(
        '/v1/users/profile',
        includeAuth: true,
      );

      logger.d('Profile response status: ${response.statusCode}');
      logger.d('Profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final user = User.fromJson(json['user']);
        logger.i(
          'User profile fetched successfully: ${user.firstName} ${user.lastName}',
        );
        return user;
      } else if (response.statusCode == 401) {
        // Token is invalid, clear user data
        await AppPreferences.clearUserData();
        final errorMsg = ApiService.parseError(response);
        logger.w('Authentication required: $errorMsg');
        throw Exception('Authentication required. Please login again.');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to get user profile: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Get current user exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to get user profile: $e');
      }
    }
  }

  // Register user
  static Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      logger.i('Attempting registration for email: $email');

      final response = await ApiService.postRequest('/v1/users', {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      });

      logger.i('Registration response status: ${response.statusCode}');
      logger.d('Registration response body: ${response.body}');

      if (response.statusCode == 201) {
        logger.i('Registration successful for: $firstName $lastName');
        return;
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Registration validation failed: $errorMsg');
        throw Exception(errorMsg);
      } else if (response.statusCode == 400) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Registration bad request: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e(
          'Registration failed with status ${response.statusCode}: $errorMsg',
        );
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Registration exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Registration error: $e');
      }
    }
  }

  // Activate user account
  static Future<void> activate(String token) async {
    try {
      logger.i(
        'Attempting account activation with token: ${token.substring(0, 8)}...',
      );

      final response = await ApiService.putRequest('/v1/users/activate', {
        'token': token,
      });

      logger.i('Activation response status: ${response.statusCode}');
      logger.d('Activation response body: ${response.body}');

      if (response.statusCode == 200) {
        logger.i('Account activation successful');
        return;
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Activation validation failed: $errorMsg');
        throw Exception(errorMsg);
      } else if (response.statusCode == 400) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Activation bad request: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e(
          'Activation failed with status ${response.statusCode}: $errorMsg',
        );
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Activation exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Activation error: $e');
      }
    }
  }

  // Logout user
  static Future<void> logout() async {
    try {
      logger.i('Attempting logout');

      final response = await ApiService.deleteRequest(
        '/v1/tokens/authentication',
        includeAuth: true,
      );

      logger.i('Logout response status: ${response.statusCode}');

      if (response.statusCode == 204) {
        logger.i('Logout successful');
      } else if (response.statusCode == 401) {
        logger.w('Logout - token already invalid');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.w('Logout failed with status ${response.statusCode}: $errorMsg');
        // Don't throw error for logout - just log it
      }

      // Always clear local data regardless of server response
      await AppPreferences.clearUserData();
      logger.i('Local user data cleared');
    } catch (e) {
      logger.e('Logout exception: $e');
      // Always clear local data even if server request fails
      await AppPreferences.clearUserData();
      logger.i('Local user data cleared after error');
      // Don't throw error for logout
    }
  }

  // Check if user is logged in and token is valid
  static Future<bool> isLoggedIn() async {
    final token = await AppPreferences.getAuthToken();
    if (token == null || token.isEmpty) {
      logger.d('No auth token found');
      return false;
    }

    // Verify token is still valid by trying to get user profile
    try {
      await getCurrentUser();
      logger.d('User is logged in and token is valid');
      return true;
    } catch (e) {
      logger.d('User is not logged in or token is invalid: $e');
      return false;
    }
  }

  // Get current user role
  static Future<String?> getCurrentUserRole() async {
    return await AppPreferences.getUserRole();
  }

  // Refresh user data (useful for profile updates)
  static Future<User> refreshUserData() async {
    logger.i('Refreshing user data');
    final user = await getCurrentUser();
    await AppPreferences.saveUserId(user.id);
    await AppPreferences.saveUserRole(user.role);
    logger.i('User data refreshed successfully');
    return user;
  }
}
