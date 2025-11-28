// File: lib/models/chat_message.dart

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final String? type;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.data,
    this.type,
  });

  bool get isAIResponse => type == 'ai';
  bool get isDataResponse => type == 'data';
  bool get isHelpResponse => type == 'help';
  bool get isPermissionDenied => type == 'permission_denied';
  bool get isFallback => type == 'fallback';
}
