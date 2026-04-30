import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hyperion_flutter/devices/devices_api.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';

class SessionsController extends ChangeNotifier {
  bool _disposed = false;
  Timer? _refreshTimer;

  List<Session>? sessions;
  bool loading = false;
  Object? error;
  bool expanded = false;

  void startAutoRefresh(Future<void> Function() load) {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => load(),
    );
  }

  Future<void> load(Future<List<Session>> Function() getSessions) async {
    loading = true;
    error = null;
    _notify();
    try {
      final result = await getSessions();
      sessions = List.from(result);
      loading = false;
    } catch (e) {
      AppLogger.log('[SessionsController] Failed to load sessions: $e');
      error = e;
      loading = false;
    }
    _notify();
  }

  void toggleExpanded() {
    expanded = !expanded;
    _notify();
  }

  /// Optimistically removes the session and returns a backup for restore-on-failure.
  List<Session> optimisticRemove(String sessionId) {
    final backup = List<Session>.from(sessions ?? []);
    sessions?.removeWhere((s) => s.id == sessionId);
    _notify();
    return backup;
  }

  void restoreSessions(List<Session> backup) {
    sessions = backup;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
}
