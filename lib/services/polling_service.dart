import '../repositories/message_repository.dart';
import '../models/message.dart';
import '../core/logger/logger.dart';

/// Service that polls the server for final messages.
class PollingService {
  final MessageRepository repository;

  PollingService(this.repository);

  /// Fetches all messages from the server.
  /// Wraps repository call with logging and optional retry.
  Future<List<Message>> fetchFinalMessages() async {
    try {
      final messages = await repository.fetchMessages();
      AppLogger.info('Fetched ${messages.length} messages via polling');
      return messages;
    } catch (e) {
      AppLogger.error('PollingService failed to fetch messages', error: e);
      rethrow;
    }
  }

  /// Polls until the expected number of messages is reached or timeout.
  Future<List<Message>> waitForMessages({
    required int expectedCount,
    Duration pollInterval = const Duration(milliseconds: 500),
    int maxAttempts = 30,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final messages = await fetchFinalMessages();
      if (messages.length >= expectedCount) {
        AppLogger.info(
          'All $expectedCount messages received after $attempt attempts',
        );
        return messages;
      }
      AppLogger.info(
        'Polling attempt $attempt: ${messages.length}/$expectedCount messages',
      );
      await Future.delayed(pollInterval);
    }
    AppLogger.warning('Timeout waiting for $expectedCount messages');
    return await fetchFinalMessages(); // return whatever we have
  }
}
