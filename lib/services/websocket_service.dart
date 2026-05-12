import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/config/app_config.dart';
import '../core/exceptions/exceptions.dart';
import '../core/logger/logger.dart';
import '../models/message.dart';

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  StreamSubscription? _internalSubscription;

  final StreamController<Message> _messageController =
  StreamController<Message>.broadcast();
  final StreamController<WebSocketStatus> _statusController =
  StreamController<WebSocketStatus>.broadcast();

  Stream<Message> get messages => _messageController.stream;
  Stream<WebSocketStatus> get statusStream => _statusController.stream;

  WebSocketStatus _status = WebSocketStatus.disconnected;
  WebSocketStatus get status => _status;

  bool get isConnected => _status == WebSocketStatus.connected;

  void _updateStatus(WebSocketStatus status) {
    if (_status == status) return;
    _status = status;
    _statusController.add(status);
    AppLogger.info('WebSocket status: $status');
  }

  /// Connect with timeout and optional auto‑reconnect.
  Future<void> connect({bool autoReconnect = false}) async {
    if (isConnected) return;

    await _cleanupConnection(keepAutoReconnect: autoReconnect);
    _updateStatus(WebSocketStatus.connecting);

    final url = '${AppConfig.wsUrl}?token=${AppConfig.token}';
    _channel = WebSocketChannel.connect(Uri.parse(url));

    try {
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );
      _updateStatus(WebSocketStatus.connected);
      _startHeartbeat();
      _listenInternal();

      if (autoReconnect) {
        _setupReconnectOnFailure();
      }
    } catch (e) {
      _updateStatus(WebSocketStatus.failed);
      await _channel?.sink.close();
      _channel = null;
      AppLogger.error('WebSocket connection failed', error: e);
      throw WebSocketException('Failed to connect: $e');
    }
  }

  void _listenInternal() {
    _internalSubscription?.cancel();
    _internalSubscription = _channel?.stream.listen(
          (data) {
        _resetHeartbeat();
        try {
          final json = jsonDecode(data as String);
          _messageController.add(Message.fromJson(json));
        } catch (e) {
          AppLogger.error('Message parse error', error: e);
        }
      },
      onError: (error, stack) {
        _updateStatus(WebSocketStatus.failed);
        AppLogger.error('WebSocket error', error: error, stack: stack);
        _scheduleReconnect();
      },
      onDone: () {
        _stopHeartbeat();
        _updateStatus(WebSocketStatus.disconnected);
        AppLogger.info('WebSocket closed');
        if (_autoReconnectEnabled) {
          _scheduleReconnect();
        }
      },
      cancelOnError: true,
    );
  }

  // ----- Heartbeat -----
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _heartbeatTimeout = Duration(seconds: 10);
  Timer? _pongTimeoutTimer;

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendPing());
  }

  void _sendPing() {
    if (!isConnected) return;
    try {
      _channel!.sink.add('ping');
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = Timer(_heartbeatTimeout, () {
        AppLogger.warning('Heartbeat timeout – connection stale');
        _handleStaleConnection();
      });
    } catch (e) {
      AppLogger.error('Ping failed', error: e);
      _handleStaleConnection();
    }
  }

  void _resetHeartbeat() => _pongTimeoutTimer?.cancel();
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _pongTimeoutTimer?.cancel();
  }

  void _handleStaleConnection() async {
    AppLogger.warning('Stale connection detected, reconnecting...');
    await _cleanupConnection(keepAutoReconnect: true);
    if (_autoReconnectEnabled) _scheduleReconnect();
  }

  // ----- Auto‑reconnect -----
  bool _autoReconnectEnabled = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  void _setupReconnectOnFailure() {
    _autoReconnectEnabled = true;
  }

  void _scheduleReconnect() {
    if (!_autoReconnectEnabled) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _reconnectAttempt * 2);
    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempt++;
      AppLogger.info('Reconnect attempt $_reconnectAttempt');
      try {
        await connect(autoReconnect: true);
        _reconnectAttempt = 0;
      } catch (e) {
        // will retry again via next _scheduleReconnect call
      }
    });
  }

  // ----- Internal cleanup -----
  Future<void> _cleanupConnection({required bool keepAutoReconnect}) async {
    final autoReconnectFlag = _autoReconnectEnabled;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    await _internalSubscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    if (keepAutoReconnect) {
      _autoReconnectEnabled = autoReconnectFlag;
    } else {
      _autoReconnectEnabled = false;
    }
  }

  // ----- Public API -----
  /// Send with built‑in retry (max 5 attempts, waits for reconnect, timeout 10s)
  Future<void> safeSend(String text, {int maxRetries = 5}) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      if (isConnected) {
        try {
          _channel!.sink.add(text);
          AppLogger.info('Sent: $text');
          return;
        } catch (e) {
          AppLogger.error('Send failed on attempt $attempt', error: e);
          if (attempt >= maxRetries) break;
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
      }

      // Not connected – wait for connection (event‑based with timeout)
      AppLogger.warning('Waiting for connection (attempt $attempt)');
      try {
        await statusStream
            .firstWhere(
              (s) => s == WebSocketStatus.connected,
          orElse: () => throw TimeoutException('No connection'),
        )
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        throw WebSocketException('Connection not restored after 10 seconds');
      }
    }
    throw WebSocketException('Failed to send after $maxRetries attempts');
  }

  // Legacy send (throws if not connected)
  Future<void> send(String text) async {
    if (!isConnected || _channel == null) {
      throw WebSocketException('WebSocket not connected');
    }
    _channel!.sink.add(text);
    AppLogger.info('Sent: $text');
  }

  Future<void> disconnect() async {
    _autoReconnectEnabled = false;
    await _cleanupConnection(keepAutoReconnect: false);
    _updateStatus(WebSocketStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
  }
}