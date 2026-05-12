import '../models/message.dart';

/// Service that maintains a sorted list of messages and provides order validation.
class OrderedMessageService {
  List<Message> _finalMessages = [];

  /// Sets the final message list, automatically sorting by counter.
  void setFinalMessages(List<Message> messages) {
    _finalMessages = List.from(messages);
    _finalMessages.sort((a, b) => a.counter.compareTo(b.counter));
  }

  /// Immutable view of the sorted messages.
  List<Message> get finalMessages => List.unmodifiable(_finalMessages);

  /// Returns true if counters are strictly increasing (monotonic).
  bool verifyMonotonic() {
    for (int i = 1; i < _finalMessages.length; i++) {
      if (_finalMessages[i].counter <= _finalMessages[i - 1].counter) {
        return false;
      }
    }
    return true;
  }

  /// Returns true if we have exactly [expectedCount] messages.
  bool hasExpectedCount(int expectedCount) =>
      _finalMessages.length == expectedCount;

  /// Returns true if both monotonic and count match expected.
  bool isValid(int expectedCount) =>
      hasExpectedCount(expectedCount) && verifyMonotonic();

  /// Clears stored messages.
  void clear() => _finalMessages.clear();
}


