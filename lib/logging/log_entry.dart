import 'package:hyperion_flutter/logging/log_level.dart';

/// A single structured log record.
class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  final DateTime timestamp;
  final LogLevel level;

  /// Class or component that emitted this entry (e.g. "AuthService").
  final String source;

  final String message;

  @override
  String toString() => '${_fmt(timestamp)} [${level.label}] [$source] $message';

  static String _fmt(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
