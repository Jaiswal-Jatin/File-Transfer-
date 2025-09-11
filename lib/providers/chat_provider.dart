import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final Map<String, List<ChatMessage>> _conversations = {};

  Map<String, List<ChatMessage>> get conversations => 
      Map.unmodifiable(_conversations);

  List<ChatMessage> getConversation(String deviceId) {
    return _conversations[deviceId] ?? [];
  }

  void addMessage(ChatMessage message) {
    if (!_conversations.containsKey(message.deviceId)) {
      _conversations[message.deviceId] = [];
    }
    _conversations[message.deviceId]!.add(message);
    notifyListeners();
  }

  void clearConversation(String deviceId) {
    _conversations[deviceId]?.clear();
    notifyListeners();
  }

  void clearAllConversations() {
    _conversations.clear();
    notifyListeners();
  }
}
