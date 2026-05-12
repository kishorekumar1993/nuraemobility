import 'dart:async';
import 'dart:math';

/// Retry an asynchronous operation with exponential backoff and jitter.
///
/// Example:
/// ```dart
/// final result = await retry(
///   () => httpClient.get(url),
///   maxAttempts: 5,
///   initialDelay: Duration(milliseconds: 100),
///   maxDelay: Duration(seconds: 5),
///   onRetry: (attempt, error) => print('Retry $attempt after $error'),
/// );
/// ```
Future<T> retry<T>(
    Future<T> Function() action, {
      int maxAttempts = 3,
      Duration initialDelay = const Duration(milliseconds: 500),
      Duration maxDelay = const Duration(seconds: 10),
      double backoffFactor = 2.0,
      bool useJitter = true,
      void Function(int attempt, Object error)? onRetry,
    }) async {
  int attempt = 1;
  while (true) {
    try {
      return await action();
    } catch (e) {
      if (attempt >= maxAttempts) rethrow;

      // Calculate delay with exponential backoff
      var delay = initialDelay * pow(backoffFactor, attempt - 1).toInt();
      if (delay > maxDelay) delay = maxDelay;

      // Add jitter (±20%) to avoid thundering herd
      if (useJitter) {
        final jitter = Random().nextDouble() * 0.4 - 0.2; // -20% to +20%
        delay = Duration(microseconds: (delay.inMicroseconds * (1 + jitter)).round());
      }

      onRetry?.call(attempt, e);
      await Future.delayed(delay);
      attempt++;
    }
  }
}