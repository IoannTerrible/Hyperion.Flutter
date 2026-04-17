import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:hyperion_flutter/logging/log_entry.dart';
import 'package:hyperion_flutter/logging/log_level.dart';

/// Read-only access to in-memory log entries with filtering.
///
/// Usage:
///   final logs = LogsService.instance.filtered(level: LogLevel.error);
///   LogsService.instance.stream.listen((entry) { ... });
class LogsService {
  LogsService._();

  static final LogsService instance = LogsService._();

  /// All captured entries, newest last.
  List<LogEntry> get all => AppLogger.entries;

  /// Entries filtered by [level] and/or [source].
  ///
  /// [source] is a case-insensitive substring match against [LogEntry.source].
  List<LogEntry> filtered({LogLevel? level, String? source}) {
    Iterable<LogEntry> result = AppLogger.entries;
    if (level != null) {
      result = result.where((e) => e.level == level);
    }
    if (source != null && source.isNotEmpty) {
      final q = source.toLowerCase();
      result = result.where((e) => e.source.toLowerCase().contains(q));
    }
    return result.toList(growable: false);
  }

  /// All unique source names present in the log, sorted alphabetically.
  List<String> get sources {
    final seen = <String>{};
    for (final e in AppLogger.entries) {
      seen.add(e.source);
    }
    return seen.toList()..sort();
  }

  /// Live stream — fires whenever a new [LogEntry] is appended.
  Stream<LogEntry> get stream => AppLogger.entryStream;

  /// Wipe all in-memory entries.
  void clear() => AppLogger.clearEntries();
}
