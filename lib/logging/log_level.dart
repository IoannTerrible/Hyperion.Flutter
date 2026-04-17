/// Log severity level.
enum LogLevel {
  debug,
  info,
  warn,
  error;

  String get label => switch (this) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERROR',
      };
}
