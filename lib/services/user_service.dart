// File: lib/services/user_service.dart

import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:sales_app/utils/preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class UserService {
  static final logger = Logger();

  // Get all users with search and pagination
  static Future<Map<String, dynamic>> getUsers({
    String? search,
    String? email,
    String? role,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
    String sort = 'id',
  }) async {
    try {
      logger.i(
        'Fetching users list - Page: $page, PageSize: $pageSize, Search: $search',
      );

      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'sort': sort,
      };

      if (search != null && search.isNotEmpty) queryParams['name'] = search;
      if (email != null && email.isNotEmpty) queryParams['email'] = email;
      if (role != null && role.isNotEmpty) queryParams['role'] = role;
      if (isActive != null) queryParams['is_active'] = isActive.toString();

      final query = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final endpoint = query.isEmpty ? '/v1/user' : '/v1/user? $query';

      logger.d('Making request to: $endpoint');

      final response = await ApiService.getRequest(endpoint, includeAuth: true);

      logger.i('Users response status: ${response.statusCode}');
      logger.d('Users response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        logger.d('Parsed JSON keys: ${json.keys.toList()}');

        // Extract users array
        final usersData = json['users'];
        if (usersData == null) {
          logger.w('No users field found in response');
          return {'users': <User>[], 'metadata': {}};
        }

        if (usersData is! List) {
          logger.e('Users data is not a list: ${usersData.runtimeType}');
          throw Exception('Invalid response format: users field is not a list');
        }

        final List<dynamic> usersList = usersData;
        logger.i('Found ${usersList.length} users in response');

        // Parse users
        final users = <User>[];
        for (int i = 0; i < usersList.length; i++) {
          try {
            final userData = usersList[i];
            if (userData is Map<String, dynamic>) {
              final user = User.fromJson(userData);
              users.add(user);
              logger.d(
                'Parsed user ${i + 1}: ${user.firstName} ${user.lastName} (${user.role})',
              );
            } else {
              logger.w(
                'User data at index $i is not a map: ${userData.runtimeType}',
              );
            }
          } catch (e) {
            logger.e('Failed to parse user at index $i: $e');
            continue;
          }
        }

        // Extract metadata
        final metadata = json['metadata'] ?? {};
        logger.i(
          'Successfully parsed ${users.length} users with metadata: $metadata',
        );

        return {'users': users, 'metadata': metadata};
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Users access forbidden: $errorMsg');
        throw Exception('You do not have permission to view users');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to fetch users: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Get users exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to fetch users: $e');
      }
    }
  }

  // Get user by ID
  static Future<User> getUser(int userId) async {
    try {
      logger.i('Fetching user with ID: $userId');

      final response = await ApiService.getRequest(
        '/v1/user/$userId',
        includeAuth: true,
      );

      logger.i('Get user response status: ${response.statusCode}');
      logger.d('Get user response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final user = User.fromJson(json['user']);
        logger.i(
          'User fetched successfully: ${user.firstName} ${user.lastName} (${user.role})',
        );
        return user;
      } else if (response.statusCode == 404) {
        logger.w('User not found: $userId');
        throw Exception('User not found');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to fetch user: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Get user exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to fetch user: $e');
      }
    }
  }

  // Update user
  static Future<User> updateUser(
    int userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      logger.i('Updating user: $userId with data: $updates');

      final response = await ApiService.putRequest(
        '/v1/user/$userId',
        updates,
        includeAuth: true,
      );

      logger.i('Update user response status: ${response.statusCode}');
      logger.d('Update user response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final user = User.fromJson(json['user']);
        logger.i(
          'User updated successfully: ${user.firstName} ${user.lastName}',
        );
        return user;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Update user forbidden: $errorMsg');
        throw Exception('You do not have permission to update this user');
      } else if (response.statusCode == 404) {
        logger.w('User not found for update: $userId');
        throw Exception('User not found');
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Update user validation failed: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to update user: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Update user exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to update user: $e');
      }
    }
  }

  // Delete user (admin only)
  static Future<void> deleteUser(int userId) async {
    try {
      logger.i('Deleting user: $userId');

      final response = await ApiService.deleteRequest(
        '/v1/user/$userId',
        includeAuth: true,
      );

      logger.i('Delete user response status: ${response.statusCode}');
      logger.d('Delete user response body: ${response.body}');

      if (response.statusCode == 200) {
        logger.i('User deleted successfully: $userId');
        return;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Delete user forbidden: $errorMsg');
        throw Exception('You do not have permission to delete users');
      } else if (response.statusCode == 404) {
        logger.w('User not found for deletion: $userId');
        throw Exception('User not found');
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to delete user: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Delete user exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to delete user: $e');
      }
    }
  }

  // Update current user profile using the self endpoint
  static Future<User> updateProfile(Map<String, dynamic> updates) async {
    try {
      logger.i('Updating current user profile');
      logger.d(
        'Profile updates: ${updates.keys.toList()}',
      ); // Don't log actual values

      int userID = await AppPreferences.getUserId() as int;
      final response = await ApiService.putRequest(
        '/v1/users/profile/$userID',
        updates,
        includeAuth: true,
      );

      logger.i('Update profile response status: ${response.statusCode}');
      logger.d('Update profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final user = User.fromJson(json['user']);
        logger.i('Profile updated successfully');
        return user;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Update profile forbidden: $errorMsg');
        throw Exception('You do not have permission to update your profile');
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Profile validation failed: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to update profile: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Update profile exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to update profile: $e');
      }
    }
  }
}
