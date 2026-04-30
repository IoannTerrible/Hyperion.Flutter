import 'package:flutter/foundation.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';

class UploadLogsController extends ChangeNotifier {
  bool _disposed = false;
  bool uploading = false;

  /// Calls [doUpload] and returns its result, or rethrows on failure.
  Future<bool> uploadLogs(Future<bool> Function() doUpload) async {
    uploading = true;
    _notify();
    try {
      final result = await doUpload();
      return result;
    } catch (e) {
      AppLogger.log('[UploadLogsController] Upload failed: $e');
      rethrow;
    } finally {
      uploading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
