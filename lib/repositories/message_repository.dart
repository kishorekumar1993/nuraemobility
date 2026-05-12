import '../core/logger/logger.dart';
import '../core/network/api_client.dart';
import '../models/message.dart';

/// Repository responsible for message-related API operations.
class MessageRepository {
  final ApiClient _apiClient;

  const MessageRepository(this._apiClient);

  /// Reset server state.
  Future<void> reset() async {
    try {
      await _apiClient
          .post('/reset')
          .timeout(const Duration(seconds: 10));

      AppLogger.info('Server reset successfully');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to reset server',
        error: error,
        stack: stackTrace,
      );

      rethrow;
    }
  }

  /// Fetch all messages from server.
  ///
  /// Supports:
  /// - { "messages": [] }
  /// - direct array response []
  Future<List<Message>> fetchMessages() async {
    try {
      final response = await _apiClient
          .get('/messages')
          .timeout(const Duration(seconds: 10));

      final rawMessages = _extractMessages(response);

      final messages = rawMessages
          .whereType<Map<String, dynamic>>()
          .map(_safeParseMessage)
          .whereType<Message>()
          .toList();

      final uniqueSortedMessages =
      _deduplicateAndSort(messages);

      AppLogger.info(
        'Fetched ${uniqueSortedMessages.length} '
            'valid messages out of ${rawMessages.length}',
      );

      return List.unmodifiable(uniqueSortedMessages);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch messages',
        error: error,
        stack: stackTrace,
      );

      rethrow;
    }
  }

  /// Fetch messages after a specific counter.
  Future<List<Message>> fetchMessagesSince(
      int fromCounter,
      ) async {
    try {
      final allMessages = await fetchMessages();

      final filtered = allMessages
          .where((m) => m.counter > fromCounter)
          .toList();

      AppLogger.info(
        'Fetched ${filtered.length} messages '
            'since counter=$fromCounter',
      );

      return List.unmodifiable(filtered);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch messages since $fromCounter',
        error: error,
        stack: stackTrace,
      );

      rethrow;
    }
  }

  /// Extract message array safely.
  List<dynamic> _extractMessages(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response['messages'] as List<dynamic>? ?? [];
    }

    if (response is List<dynamic>) {
      return response;
    }

    AppLogger.warning(
      'Unexpected response format: '
          '${response.runtimeType}',
    );

    return [];
  }

  /// Parse message safely.
  ///
  /// Returns null if parsing fails.
  Message? _safeParseMessage(
      Map<String, dynamic> json,
      ) {
    try {
      return Message.fromJson(json);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Skipping malformed message: $json',
      );

      AppLogger.error(
        'Message parsing failed',
        error: error,
        stack: stackTrace,
      );

      return null;
    }
  }

  /// Remove duplicates and sort by counter.
  List<Message> _deduplicateAndSort(
      List<Message> messages,
      ) {
    final uniqueMap = <int, Message>{};

    for (final message in messages) {
      uniqueMap[message.counter] = message;
    }

    final uniqueMessages = uniqueMap.values.toList()
      ..sort(
            (a, b) => a.counter.compareTo(b.counter),
      );

    return uniqueMessages;
  }
}
