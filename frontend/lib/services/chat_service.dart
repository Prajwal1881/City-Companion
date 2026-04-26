import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/api_endpoints.dart';

const _storage = FlutterSecureStorage();

class ChatService {
  WebSocketChannel? _channel;
  final _listeners = <void Function(Map<String, dynamic>)>[];

  Future<void> connect(String convId) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token for chat connection.');
    }
    final uri = buildChatWebSocketUri(token: token, conversationId: convId);
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen((data) {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      for (final cb in _listeners) {
        cb(msg);
      }
    });
  }

  void onMessage(void Function(Map<String, dynamic>) callback) {
    _listeners.add(callback);
  }

  void send(String content) {
    _channel?.sink.add(jsonEncode({'content': content}));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _listeners.clear();
  }
}
