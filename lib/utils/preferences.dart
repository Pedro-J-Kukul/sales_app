// File: lib/utils/preferences.dart

import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String _keyIpAddress = 'api_ip_address';
  static const String _keyPort = 'api_port';
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';

  // Default values
  static const String defaultIp = '127.0.0.1';
  static const String defaultPort = '8080';

  // Get IP address
  static Future<String> getIpAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIpAddress) ?? defaultIp;
  }

  // Set IP address
  static Future<void> setIpAddress(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIpAddress, ip);
  }

  // Get port
  static Future<String> getPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPort) ?? defaultPort;
  }

  // Set port
  static Future<void> setPort(String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPort, port);
  }

  // Get full API base URL
  static Future<String> getApiBaseUrl() async {
    final ip = await getIpAddress();
    final port = await getPort();
    return 'http://$ip:$port';
  }

  // Save auth token
  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthToken, token);
  }

  // Get auth token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAuthToken);
  }

  // Clear auth token
  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
  }

  // Save user ID
  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
  }

  // Get user ID
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  // Save user role
  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role);
  }

  // Get user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  // Clear all user data
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserRole);
  }
}
