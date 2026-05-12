
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/config/app_config.dart';
import '../core/logger/logger.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../services/polling_service.dart';
import '../services/ordered_message_service.dart';
import 'task_state.dart';

class TaskCubit extends Cubit<TaskState> {
  final WebSocketService _webSocket;
  final PollingService _polling;
  final OrderedMessageService _orderedService;

  TaskCubit(this._webSocket, this._polling, this._orderedService)
      : super(const TaskState());

  Future<void> run() async {
    if (state.status == TaskStatus.loading) return;
    emit(const TaskState(status: TaskStatus.loading, logs: [], messages: []));

    StreamSubscription<Message>? wsSubscription;

    try {
      _log('🔄 Resetting server...');
      await _polling.repository.reset();
      _log('✅ Server reset.');

      _log('🔌 Connecting WebSocket with auto‑reconnect...');
      await _webSocket.connect(autoReconnect: true);

      wsSubscription = _webSocket.messages.listen((msg) {
        _log('📨 WS response: counter=${msg.counter}, echo=${msg.echoMessage}');
      });

      _log('📤 Sending ${AppConfig.messageCount} messages with safeSend...');
      for (int i = 1; i <= AppConfig.messageCount; i++) {
        final msg = 'ping $i';
        await _webSocket.safeSend(msg, maxRetries: 5);
        _log('   Sent: "$msg"');
        await Future.delayed(AppConfig.sendDelay);
      }

      // Polling (unchanged but reliable)
      const maxPollAttempts = 60;
      const pollInterval = Duration(seconds: 1);
      List<Message> finalMessages = [];
      _log('📡 Polling for final messages...');

      for (int attempt = 1; attempt <= maxPollAttempts; attempt++) {
        if (attempt > 1) await Future.delayed(pollInterval);
        finalMessages = await _polling.fetchFinalMessages();
        _log('   Attempt $attempt: got ${finalMessages.length}/${AppConfig.messageCount} messages');
        if (finalMessages.length >= AppConfig.messageCount) break;
      }

      if (finalMessages.length < AppConfig.messageCount) {
        _log('⚠️ Only ${finalMessages.length} of ${AppConfig.messageCount} messages persisted');
      }

      _orderedService.setFinalMessages(finalMessages);
      _log('=== FINAL ORDER (sorted by counter) ===');
      for (final msg in _orderedService.finalMessages) {
        _log('Counter ${msg.counter}: "${msg.echoMessage}" (ts: ${msg.ts})');
      }

      final isMonotonic = _orderedService.verifyMonotonic();
      final counters = _orderedService.finalMessages.map((m) => m.counter).join(', ');
      final actualCount = _orderedService.finalMessages.length;
      _log('\n✅ Total: $actualCount');
      _log('✅ Counters: $counters');
      _log('✅ Monotonic: $isMonotonic');

      if (_orderedService.isValid(AppConfig.messageCount)) {
        emit(state.copyWith(
          status: TaskStatus.success,
          messages: _orderedService.finalMessages,
        ));
      } else {
        final errorMsg = 'Got $actualCount/${AppConfig.messageCount} messages, monotonic=$isMonotonic';
        _log('❌ Validation failed: $errorMsg');
        emit(state.copyWith(status: TaskStatus.failure, error: errorMsg));
      }
    } catch (e) {
      AppLogger.error('Task failed', error: e);
      if (!isClosed) {
        emit(state.copyWith(status: TaskStatus.failure, error: e.toString()));
      }
    } finally {
      await wsSubscription?.cancel();
      await _webSocket.disconnect();
    }
  }

  void _log(String msg) {
    if (isClosed) return;
    // Optimised log emission (no spread operator)
    final updatedLogs = List<String>.from(state.logs)..add(msg);
    emit(state.copyWith(logs: updatedLogs));
    AppLogger.info(msg);
  }

  void clearLogs() {
    if (isClosed) return;
    emit(state.copyWith(logs: []));
  }
}
