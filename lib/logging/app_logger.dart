import 'dart:async';

import 'package:hyperion_flutter/logging/log_entry.dart';
import 'package:hyperion_flutter/logging/log_level.dart';
import 'package:hyperion_flutter/logging/app_logger_io.dart'
    if (dart.library.html) 'package:hyperion_flutter/logging/app_logger_stub.dart'
    as file_impl;
import 'package:flutter/foundation.dart';

/// Centralized logger: console + file + in-memory structured entries.
///
/// Existing callers use [log]; new code may use [logStructured] for explicit
/// level and source tagging.
///
/// The in-memory store is consumed by [LogsService] for the in-app log viewer.
class AppLogger {
  AppLogger._();

  // -- Config --
  static const int _maxEntries = 1000;
  // Cap pre-init buffer to avoid unbounded growth during slow startup.
  static const int _maxPending = 500;

  // -- File-init state --
  static bool _initDone = false;
  static final List<String> _pending = [];

  // -- Structured in-memory store --
  static final List<LogEntry> _entries = [];
  static final StreamController<LogEntry> _entryController =
      StreamController<LogEntry>.broadcast();

  // ---------------------------------------------------------------------------
  // Public read API (consumed by LogsService)
  // ---------------------------------------------------------------------------

  /// In-memory log entries, oldest first, newest last.
  static List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Broadcasts every new [LogEntry] as it is appended.
  static Stream<LogEntry> get entryStream => _entryController.stream;

  /// Remove all in-memory entries.
  static void clearEntries() => _entries.clear();

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  /// Call once at app startup (e.g. in main()).
  static Future<void> init() async {
    if (_initDone) return;
    _initDone = true;
    await file_impl.initFileLogger();
    for (final msg in _pending) {
      file_impl.writeToFile(msg);
    }
    _pending.clear();
  }

  // ---------------------------------------------------------------------------
  // Logging API
  // ---------------------------------------------------------------------------

  /// Log a plain message.
  ///
  /// Source and [LogLevel] are auto-detected:
  /// - Source is extracted from a leading `[ClassName]` or `[ClassName.method]`
  ///   prefix when present.
  /// - Level is inferred from keywords in the message
  ///   (error/exception/failed → error, warn → warn, else → info).
  static void log(String message) {
    final entry = _parseEntry(message);
    _store(entry);
    final line = '${_timestamp()} $message';
    _printLine(line);
    _writeFile(line);
  }

  /// Log with an explicit [level] and [source].
  ///
  /// Prefer this for new code. Example:
  /// ```dart
  /// AppLogger.logStructured(LogLevel.error, 'DevicesService', 'fetch failed: $e');
  /// ```
  static void logStructured(LogLevel level, String source, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );
    _store(entry);
    final line = '${_timestamp()} [${level.label}] [$source] $message';
    _printLine(line);
    _writeFile(line);
  }

  /// Returns log file content for upload. Empty on Web or when unavailable.
  static Future<String> getLogContent() => file_impl.getLogContent();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static final _prefixRe = RegExp(r'^\[([^\]]+)\]\s*(.*)$', dotAll: true);

  static LogEntry _parseEntry(String raw) {
    final m = _prefixRe.firstMatch(raw);
    if (m != null) {
      final rawSource = m.group(1)!;
      // "ProfilePage._saveProfile" → "ProfilePage"
      final source = rawSource.split('.').first;
      final message = m.group(2)!;
      return LogEntry(
        timestamp: DateTime.now(),
        level: _inferLevel(message),
        source: source,
        message: message,
      );
    }
    return LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      source: 'App',
      message: raw,
    );
  }

  static LogLevel _inferLevel(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('error') ||
        lower.contains('exception') ||
        lower.contains('failed') ||
        lower.contains('crash')) {
      return LogLevel.error;
    }
    if (lower.contains('warn') || lower.contains('warning')) {
      return LogLevel.warn;
    }
    return LogLevel.info;
  }

  static void _store(LogEntry entry) {
    if (_entries.length >= _maxEntries) {
      // Drop oldest quarter to make room.
      _entries.removeRange(0, _maxEntries ~/ 4);
    }
    _entries.add(entry);
    if (!_entryController.isClosed) {
      _entryController.add(entry);
    }
  }

  static void _printLine(String line) {
    if (kDebugMode) {
      debugPrint(line);
    } else {
      // ignore: avoid_print — intentional for release console logging
      print(line);
    }
  }

  static void _writeFile(String line) {
    if (_initDone) {
      file_impl.writeToFile(line);
    } else if (!kIsWeb) {
      if (_pending.length >= _maxPending) {
        _pending.removeAt(0); // Drop oldest entry to stay within cap.
      }
      _pending.add(line);
    }
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }
}
