import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

const String _logFileName = 'app_log.txt';
const int _maxFileSizeBytes = 512 * 1024; // 512 KB

// Top-level state for the write isolate.
SendPort? _logSendPort;
Isolate? _logIsolate;

// File reference kept on the main isolate for reads only.
File? _file;

/// Data passed to the write isolate at spawn time.
class _IsolateInitData {
  final SendPort sendPort;
  final String filePath;
  const _IsolateInitData(this.sendPort, this.filePath);
}

/// Entry point for the background write isolate (must be top-level).
void _logIsolateEntry(_IsolateInitData init) {
  final receivePort = ReceivePort();
  // Send our port back so the main isolate can talk to us.
  init.sendPort.send(receivePort.sendPort);

  final file = File(init.filePath);

  receivePort.listen((message) {
    if (message is String) {
      try {
        if (file.existsSync() && file.lengthSync() > _maxFileSizeBytes) {
          // Truncate the file when it exceeds the size limit.
          file.writeAsStringSync('');
        }
        file.writeAsStringSync('$message\n', mode: FileMode.append);
      } catch (_) {
        // Ignore write errors inside the isolate.
      }
    } else if (message == null) {
      // null = shutdown signal.
      receivePort.close();
    }
  });
}

/// Initialises the background write isolate.
///
/// The file path is resolved here (on the main isolate) because
/// [path_provider] requires platform channels that are unavailable in
/// secondary isolates.
Future<void> initFileLogger() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/$_logFileName';

    // Keep a reference for [getLogContent].
    _file = File(path);

    final receivePort = ReceivePort();
    _logIsolate = await Isolate.spawn(
      _logIsolateEntry,
      _IsolateInitData(receivePort.sendPort, path),
    );
    _logSendPort = await receivePort.first as SendPort;
  } catch (_) {
    // If isolate spawn fails, fall back silently (no file logging).
    _logSendPort = null;
    _logIsolate = null;
  }
}

/// Sends a shutdown signal to the write isolate and cleans up references.
Future<void> disposeFileLogger() async {
  _logSendPort?.send(null);
  _logIsolate?.kill(priority: Isolate.beforeNextEvent);
  _logSendPort = null;
  _logIsolate = null;
}

/// Fire-and-forget: sends [line] to the write isolate.
void writeToFile(String line) {
  _writeToFileImpl(line);
}

/// Returns log file content or empty string if unavailable.
Future<String> getLogContent() async {
  if (_file == null) return '';
  try {
    if (await _file!.exists()) {
      return await _file!.readAsString();
    }
  } catch (_) {}
  return '';
}

/// Non-blocking send to the write isolate — no await, no queue.
void _writeToFileImpl(String line) {
  _logSendPort?.send(line);
}
