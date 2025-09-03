import 'package:flutter/material.dart';
import '../model/chat_message.dart';
import '../network/open_ai_client.dart';

class ChatViewModel extends ChangeNotifier {
  final OpenAiClient _client;

  bool _loading = false;
  bool get loading => _loading;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatViewModel(this._client) {
    // Initialize with default items
    _messages.add(ChatMessage(role: ChatRole.user, text: 'Hello'));
    _messages.add(ChatMessage(role: ChatRole.openai, text: 'Good Bye'));
  }

  Future<void> sendMessage(String text) async {
    _loading = true;
    notifyListeners();

    try {
      _messages.add(ChatMessage(role:ChatRole.user, text:text));
      final json = await _client.chat(text);
      final reply = json['choices']?[0]?['message']?['content'] ?? '';
      _messages.add(ChatMessage(role:ChatRole.openai, text:reply));
    } catch (e) {
      _messages.add(ChatMessage(role:ChatRole.openai, text:e.toString()));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}