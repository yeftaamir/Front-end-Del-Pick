// lib/services/realtime_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'core/api_constants.dart';
import 'core/token_service.dart';


class RealtimeService {
  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static final Map<String, List<Function(dynamic)>> _listeners = {};
  static bool _isConnected = false;
  static Timer? _heartbeatTimer;

  // Connect to WebSocket
  static Future<void> connect() async {
    try {
      if (_isConnected) {
        debugPrint('WebSocket already connected');
        return;
      }

      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token required for WebSocket connection');
      }

      // Convert HTTP URL to WebSocket URL
      String wsUrl = ApiConstants.baseUrl.replaceFirst('http', 'ws');
      wsUrl = '$wsUrl/ws?token=$token';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      _isConnected = true;
      _startHeartbeat();

      debugPrint('WebSocket connected successfully');
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _isConnected = false;
    }
  }

  // Disconnect from WebSocket
  static Future<void> disconnect() async {
    try {
      _heartbeatTimer?.cancel();
      _subscription?.cancel();
      await _channel?.sink.close();

      _isConnected = false;
      _listeners.clear();

      debugPrint('WebSocket disconnected');
    } catch (e) {
      debugPrint('WebSocket disconnection error: $e');
    }
  }

  // Subscribe to event
  static void subscribe(String event, Function(dynamic) callback) {
    if (!_listeners.containsKey(event)) {
      _listeners[event] = [];
    }
    _listeners[event]!.add(callback);

    // Send subscription message to server
    _sendMessage({
      'type': 'subscribe',
      'event': event,
    });
  }

  // Unsubscribe from event
  static void unsubscribe(String event, [Function(dynamic)? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
    } else {
      _listeners.remove(event);
    }

    // Send unsubscription message to server
    _sendMessage({
      'type': 'unsubscribe',
      'event': event,
    });
  }

  static void subscribeToOrderUpdates(String orderId, Function(Map<String, dynamic>) callback) {
    subscribe('order_update_$orderId', (dynamic data) => callback(data as Map<String, dynamic>));
  }

  static void subscribeToDriverLocation(String driverId, Function(Map<String, dynamic>) callback) {
    subscribe('driver_location_$driverId', (dynamic data) => callback(data as Map<String, dynamic>));
  }

  static void subscribeToStoreUpdates(String storeId, Function(Map<String, dynamic>) callback) {
    subscribe('store_update_$storeId', (dynamic data) => callback(data as Map<String, dynamic>));
  }

  static void subscribeToDriverRequests(Function(Map<String, dynamic>) callback) {
    subscribe('driver_request', (dynamic data) => callback(data as Map<String, dynamic>));
  }

  // Send message through WebSocket
  static void _sendMessage(Map<String, dynamic> message) {
    try {
      if (_isConnected && _channel != null) {
        _channel!.sink.add(json.encode(message));
      }
    } catch (e) {
      debugPrint('Send WebSocket message error: $e');
    }
  }

  // Handle incoming messages
  static void _handleMessage(dynamic data) {
    try {
      final message = json.decode(data) as Map<String, dynamic>;
      final event = message['event'] as String?;
      final payload = message['data'];

      if (event != null && _listeners.containsKey(event)) {
        for (final callback in _listeners[event]!) {
          callback(payload);
        }
      }
    } catch (e) {
      debugPrint('Handle WebSocket message error: $e');
    }
  }

  // Handle WebSocket errors
  static void _handleError(error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;

    // Attempt to reconnect after delay
    Timer(Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  // Handle WebSocket disconnection
  static void _handleDisconnection() {
    debugPrint('WebSocket disconnected');
    _isConnected = false;

    // Attempt to reconnect after delay
    Timer(Duration(seconds: 3), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  // Start heartbeat to keep connection alive
  static void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _sendMessage({'type': 'ping'});
      } else {
        timer.cancel();
      }
    });
  }

  // Check connection status
  static bool get isConnected => _isConnected;

  // Get connection status
  static Map<String, dynamic> getStatus() {
    return {
      'is_connected': _isConnected,
      'active_subscriptions': _listeners.keys.toList(),
      'listeners_count': _listeners.length,
    };
  }
}