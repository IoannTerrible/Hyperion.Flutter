import 'package:clietn_server_application/logging/app_logger_io.dart'
    if (dart.library.html) 'package:clietn_server_application/logging/app_logger_stub.dart'
    as fileImpl;

import 'package:flutter/foundation.dart';

/// Centralized logger: console + file. Format: [ClassName] message.
/// File path: app support dir / app_log.txt. On Web, file logging is skipped.
class AppLogger {
  AppLogger._();

  static bool _initDone = false;
  static final List<String> _pending = [];

  /// Call once at app startup (e.g. in main()).
  static Future<void> init() async {
    if (_initDone) return;
    _initDone = true;
    await fileImpl.initFileLogger();
    for (final msg in _pending) {
      fileImpl.writeToFile(msg);
    }
    _pending.clear();
  }

  /// Log message. Format: [ClassName] message (caller provides full string).
  static void log(String message) {
    final line = '${_timestamp()} $message';
    if (kDebugMode) {
      debugPrint(line);
    } else {
      // ignore: avoid_print — intentional for release console logging
      print(line);
    }
    if (_initDone) {
      fileImpl.writeToFile(line);
    } else if (!kIsWeb) {
      _pending.add(line);
    }
  }

  /// Returns log file content for upload. Empty on Web or when unavailable.
  static Future<String> getLogContent() => fileImpl.getLogContent();

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
