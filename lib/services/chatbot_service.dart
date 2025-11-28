// File: lib/services/chatbot_service. dart

import 'dart:convert';
import 'package:logger/logger.dart';
import 'api_service.dart';

class ChatbotService {
  static final logger = Logger();

  static Future<ChatResponse> sendMessage(String message) async {
    try {
      logger.i('Sending message to chatbot: $message');

      final response = await ApiService.postRequest('/v1/chatbot', {
        'message': message,
      }, includeAuth: true);

      logger.i('Chatbot response status: ${response.statusCode}');
      logger.d('Chatbot response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final chatResponse = ChatResponse.fromJson(json['chatbot']);
        logger.i('Chatbot response received successfully');
        return chatResponse;
      } else if (response.statusCode == 403) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Chatbot access forbidden: $errorMsg');
        throw Exception('You do not have permission to use the chatbot');
      } else if (response.statusCode == 422) {
        final errorMsg = ApiService.parseError(response);
        logger.w('Chatbot validation failed: $errorMsg');
        throw Exception(errorMsg);
      } else {
        final errorMsg = ApiService.parseError(response);
        logger.e('Failed to get chatbot response: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      logger.e('Chatbot service exception: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to get chatbot response: $e');
      }
    }
  }
}

class ChatResponse {
  final String response;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final String type;

  ChatResponse({
    required this.response,
    this.data,
    required this.timestamp,
    required this.type,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      response: json['response'] ?? '',
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'] ?? 'text',
    );
  }
}
