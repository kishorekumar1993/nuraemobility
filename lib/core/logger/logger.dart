import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Lightweight, production‑grade logger with structured output and smart defaults.
class AppLogger {
  AppLogger._();

  // --------------------------------------------------------------------------
  // Configuration (can be changed at runtime)
  // --------------------------------------------------------------------------

  /// Enable/disable all logging entirely.
  static bool enabled = true;

  /// Minimum log level. In release builds, defaults to [Level.warning].
  static Level minLevel = kReleaseMode ? Level.warning : Level.debug;

  /// Optional prefix added to every log message (e.g., "[Auth]" or "[Payment]").
  static String? tag;

  /// Whether to print stack traces in debug mode (helps keep logs readable).
  static bool showFullStackInDebug = true;

  // --------------------------------------------------------------------------
  // Emoji helpers (optional – remove if you prefer plain text)
  // --------------------------------------------------------------------------
  static const Map<Level, String> _emoji = {
    Level.debug: '🐛',
    Level.info: 'ℹ️',
    Level.warning: '⚠️',
    Level.error: '❌',
  };

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  static void debug(String msg, {Object? error, StackTrace? stack}) =>
      _log(Level.debug, msg, error: error, stack: stack);

  static void info(String msg, {Object? error, StackTrace? stack}) =>
      _log(Level.info, msg, error: error, stack: stack);

  static void warning(String msg, {Object? error, StackTrace? stack}) =>
      _log(Level.warning, msg, error: error, stack: stack);

  static void error(String msg, {Object? error, StackTrace? stack}) =>
      _log(Level.error, msg, error: error, stack: stack);

  // --------------------------------------------------------------------------
  // Core logging logic
  // --------------------------------------------------------------------------

  static void _log(Level level, String msg, {Object? error, StackTrace? stack}) {
    if (!enabled) return;
    if (level.index < minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final emoji = _emoji[level] ?? '';
    final levelName = level.name.toUpperCase().padRight(7); // "DEBUG  ", etc.
    final tagPrefix = tag != null ? '[$tag] ' : '';
    final errorSuffix = error != null ? ' | ${_formatError(error)}' : '';
    final message = '$tagPrefix$msg$errorSuffix';

    final formatted = '[$timestamp] $emoji $levelName $message';

    // Output in debug mode (Android Studio, VS Code, console)
    if (kDebugMode) {
      debugPrint(formatted);
      if (showFullStackInDebug && stack != null) {
        debugPrintStack(stackTrace: stack, label: 'Stack trace');
      }
    } else {
      // Release mode: use developer.log (works with system logs, Crashlytics, etc.)
      developer.log(
        formatted,
        name: tag ?? 'AppLogger',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Formats an error object into a readable string.
  static String _formatError(Object error) {
    if (error is Exception) return error.toString();
    if (error is String) return error;
    return error.runtimeType.toString();
  }
}

// --------------------------------------------------------------------------
// Log levels (order matters – higher index = more severe)
// --------------------------------------------------------------------------
enum Level {
  debug,
  info,
  warning,
  error,
}
