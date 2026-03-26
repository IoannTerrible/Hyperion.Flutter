import 'dart:io';

import 'package:path_provider/path_provider.dart';

const String _logFileName = 'app_log.txt';
const int _maxFileSizeBytes = 512 * 1024; // 512 KB

File? _file;
bool _writing = false;

Future<void> initFileLogger() async {
  try {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/$_logFileName');
  } catch (_) {
    _file = null;
  }
}

void writeToFile(String line) {
  if (_file == null) return;
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

Future<void> _writeToFileImpl(String line) async {
  if (_file == null) return;
  while (_writing) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  _writing = true;
  try {
    final f = _file!;
    if (await f.exists() && await f.length() > _maxFileSizeBytes) {
      final content = await f.readAsString();
      final lines = content.split('\n');
      final keep = lines.length ~/ 2;
      await f.writeAsString(
        '${lines.skip(lines.length - keep).join("\n")}\n',
        mode: FileMode.write,
      );
    }
    await f.writeAsString('$line\n', mode: FileMode.append);
  } catch (_) {
    // Ignore file write errors
  } finally {
    _writing = false;
  }
}
