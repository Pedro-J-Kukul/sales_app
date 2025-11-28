// File: lib/screens/chat/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/chatbot_service.dart';
import '../../services/auth_service.dart';
import '../../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static final logger = Logger();

  final messageController = TextEditingController();
  final scrollController = ScrollController();
  List<ChatMessage> messages = [];
  bool isLoading = false;
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      // Get current user role
      currentUserRole = await AuthService.getCurrentUserRole();
      logger.i('Chat initialized for role: $currentUserRole');

      // Add welcome message based on role
      String welcomeMessage;
      String quickActions;

      switch (currentUserRole) {
        case 'guest':
          welcomeMessage =
              "👋 Welcome!  I'm your product assistant. I can help you learn about our products, prices, and general information. ";
          quickActions =
              "Try asking: 'What products do you have? ', 'Show me prices', or 'Tell me about your business'";
          break;
        case 'cashier':
          welcomeMessage =
              "👋 Hello! I'm your sales assistant. I can help you with product information, sales data, and business analytics.";
          quickActions =
              "Try asking: 'How are sales today?', 'What are the top products?', or 'Show me recent transactions'";
          break;
        case 'admin':
          welcomeMessage =
              "👋 Welcome! I have full access to your business data and can provide comprehensive insights about products, sales, users, and performance.";
          quickActions =
              "Try asking: 'Business overview', 'Staff performance', 'Sales trends', or any other business question";
          break;
        default:
          welcomeMessage =
              "👋 Hello! I'm your sales assistant. How can I help you today?";
          quickActions = "Ask me about your business data! ";
      }

      _addMessage(
        ChatMessage(
          text: "$welcomeMessage\n\n$quickActions",
          isUser: false,
          timestamp: DateTime.now(),
          type: 'welcome',
        ),
      );
    } catch (e) {
      logger.e('Failed to initialize chat: $e');
      _addMessage(
        ChatMessage(
          text:
              "Hello! I'm your sales assistant. I'm ready to help with your business data.",
          isUser: false,
          timestamp: DateTime.now(),
          type: 'fallback',
        ),
      );
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isLoading) return;

    // Add user message
    _addMessage(
      ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
    );

    messageController.clear();
    setState(() {
      isLoading = true;
    });

    try {
      // Get bot response from API
      final response = await ChatbotService.sendMessage(text);

      _addMessage(
        ChatMessage(
          text: response.response,
          isUser: false,
          timestamp: response.timestamp,
          data: response.data,
          type: response.type,
        ),
      );
    } catch (e) {
      logger.e('Error getting chat response: $e');
      _addMessage(
        ChatMessage(
          text:
              "Sorry, I encountered an error: ${e.toString().replaceFirst('Exception: ', '')}",
          isUser: false,
          timestamp: DateTime.now(),
          type: 'error',
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildMessage(ChatMessage message) {
    final isPermissionDenied = message.isPermissionDenied;
    final isAI = message.isAIResponse;
    final isError = message.type == 'error';

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? Colors.blue
              : isPermissionDenied
              ? Colors.red.shade100
              : isError
              ? Colors.orange.shade100
              : isAI
              ? Colors.purple.shade100
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: isPermissionDenied
              ? Border.all(color: Colors.red.shade300, width: 1)
              : isError
              ? Border.all(color: Colors.orange.shade300, width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser)
              Row(
                children: [
                  Icon(
                    isPermissionDenied
                        ? Icons.security
                        : isError
                        ? Icons.warning
                        : isAI
                        ? Icons.smart_toy
                        : Icons.support_agent,
                    size: 16,
                    color: isPermissionDenied
                        ? Colors.red
                        : isError
                        ? Colors.orange
                        : isAI
                        ? Colors.purple
                        : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPermissionDenied
                        ? 'Access Control'
                        : isError
                        ? 'System Error'
                        : isAI
                        ? 'AI Assistant'
                        : 'Sales Assistant',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPermissionDenied
                          ? Colors.red
                          : isError
                          ? Colors.orange
                          : isAI
                          ? Colors.purple
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            if (!message.isUser) const SizedBox(height: 4),
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser
                    ? Colors.white
                    : isPermissionDenied
                    ? Colors.red.shade700
                    : isError
                    ? Colors.orange.shade700
                    : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: message.isUser ? Colors.white70 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    List<String> actions;

    switch (currentUserRole) {
      case 'guest':
        actions = [
          'What products do you have?',
          'Show me prices',
          'Tell me about your business',
        ];
        break;
      case 'cashier':
        actions = [
          'How are sales today?',
          'What are the top products?',
          'Show me recent sales',
          'Product information',
        ];
        break;
      case 'admin':
        actions = [
          'Business overview',
          'Staff performance',
          'Sales trends',
          'Top products',
          'User management',
        ];
        break;
      default:
        actions = ['Help me get started'];
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: actions
            .map(
              (action) => ActionChip(
                label: Text(action, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  messageController.text = action;
                  _sendMessage();
                },
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              currentUserRole == 'admin'
                  ? Icons.admin_panel_settings
                  : currentUserRole == 'cashier'
                  ? Icons.point_of_sale
                  : Icons.storefront,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sales Assistant', style: TextStyle(fontSize: 16)),
                if (currentUserRole != null)
                  Text(
                    '${currentUserRole!.toUpperCase()} ACCESS',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                messages.clear();
              });
              _initializeChat();
            },
            tooltip: 'Refresh Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          if (currentUserRole != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: currentUserRole == 'admin'
                  ? Colors.green.shade50
                  : currentUserRole == 'cashier'
                  ? Colors.blue.shade50
                  : Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: currentUserRole == 'admin'
                        ? Colors.green
                        : currentUserRole == 'cashier'
                        ? Colors.blue
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentUserRole == 'admin'
                          ? 'Full access: Products, Sales, Users & Analytics'
                          : currentUserRole == 'cashier'
                          ? 'Access: Products & Sales (User management restricted)'
                          : 'Limited access: Products only (Sales & Users restricted)',
                      style: TextStyle(
                        fontSize: 12,
                        color: currentUserRole == 'admin'
                            ? Colors.green.shade700
                            : currentUserRole == 'cashier'
                            ? Colors.blue.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (context, index) => _buildMessage(messages[index]),
            ),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('AI is thinking...'),
                ],
              ),
            ),

          if (!isLoading) _buildQuickActions(),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your business data...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: isLoading ? null : _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
