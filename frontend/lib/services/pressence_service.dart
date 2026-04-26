import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart'; // Your API client

class PresenceService {
  Timer? _heartbeatTimer;
  final int _intervalSeconds = 30;

  // Start this when the user logs in or app comes to foreground
  void startHeartbeat() {
    if (_heartbeatTimer != null && _heartbeatTimer!.isActive) return;

    // Send initial heartbeat immediately
    _sendHeartbeat();

    // Schedule periodic pings
    _heartbeatTimer = Timer.periodic(Duration(seconds: _intervalSeconds), (_) {
      _sendHeartbeat();
    });
    debugPrint("💚 Presence heartbeat started.");
  }

  // Stop this when user logs out or app goes to background
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint("🛑 Presence heartbeat stopped.");
  }

  Future<void> _sendHeartbeat() async {
    try {
      await ApiClient.sendHeartbeat();
    } catch (e) {
      debugPrint("Failed to send heartbeat: $e");
    }
  }
}
