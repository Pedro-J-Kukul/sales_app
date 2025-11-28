// File: lib/utils/network_helper.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class NetworkHelper {
  // Check if device has internet connectivity
  static Future<bool> hasConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Test connection to specific host and port
  static Future<bool> testConnection(
    String host,
    int port, {
    int timeoutSeconds = 5,
  }) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(seconds: timeoutSeconds),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Validate IP address format
  static bool isValidIpAddress(String ip) {
    final ipPattern = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipPattern.hasMatch(ip) || ip == 'localhost';
  }

  // Validate port number
  static bool isValidPort(String port) {
    final portNum = int.tryParse(port);
    return portNum != null && portNum > 0 && portNum <= 65535;
  }
}
