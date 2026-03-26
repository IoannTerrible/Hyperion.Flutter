import 'package:clietn_server_application/auth/auth_api.dart';
import 'package:clietn_server_application/auth/auth_service.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class AuthNotifier extends ChangeNotifier {
  final AuthService _service;

  AuthState _state = const Unauthenticated();
  String? _lastError;
  bool _isLoading = false;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  AuthNotifier(this._service);

  AuthState get state => _state;
  String? get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _state is Authenticated;
  Duration? get lockoutRemaining {
    final until = _lockoutUntil;
    if (until == null) return null;
    final diff = until.difference(DateTime.now());
    if (diff.isNegative) return null;
    return diff;
  }
  bool get isLockedOut => lockoutRemaining != null;

  set _authState(AuthState value) {
    _state = value;
    _lastError = null;
    _clearLockout();
    notifyListeners();
  }

  void _clearLockout() {
    _lockoutUntil = null;
    _lockoutTimer?.cancel();
    _lockoutTimer = null;
  }

  static Duration? _tryParseLockoutDuration(String message) {
    final m = message.toLowerCase();
    if (!(m.contains('lock') || m.contains('blocked') || m.contains('заблок'))) return null;
    final re = RegExp(r'(\d+)\s*(minutes?|mins?|min|минут[аы]?|мин)\b', caseSensitive: false);
    final match = re.firstMatch(message);
    if (match == null) return null;
    final n = int.tryParse(match.group(1) ?? '');
    if (n == null || n <= 0) return null;
    return Duration(minutes: n);
  }

  void _applyLockoutIfPresent(String message) {
    final d = _tryParseLockoutDuration(message);
    if (d == null) return;
    _lockoutUntil = DateTime.now().add(d);
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (lockoutRemaining == null) {
        _clearLockout();
        notifyListeners();
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> restoreSession() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await _service.restoreSession();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called by RealAuthService.onStateChanged to keep notifier in sync.
  void replaceState(AuthState newState) {
    _authState = newState;
  }

  Future<void> signIn(String usernameOrEmail, String password) async {
    if (isLockedOut) return;
    _lastError = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _service.signIn(usernameOrEmail, password);
      // State updated via onStateChanged from service
    } on AuthApiException catch (e) {
      _lastError = e.message;
      _applyLockoutIfPresent(e.message);
      notifyListeners();
    } catch (e) {
      _lastError = _toUserFriendlyError(e);
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String username, String email, String password) async {
    _lastError = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _service.register(username, email, password);
    } on AuthApiException catch (e) {
      _lastError = e.message;
      notifyListeners();
    } catch (e) {
      _lastError = _toUserFriendlyError(e);
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void signInAsDemo() {
    _lastError = null;
    _service.signInAsDemo();
  }

  Future<void> signOut() async {
    _lastError = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _service.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getToken() => _service.getToken();

  /// Used by API layer to recover from 401 by refreshing tokens.
  Future<bool> tryRefreshSession() => _service.tryRefreshSession();

  Future<void> refreshProfile() => _service.refreshProfile();

  static String _toUserFriendlyError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Connection') ||
        s.contains('Connection refused') ||
        s.contains('сетевое подключение')) {
      return 'Connection failed. Please check your network and try again.';
    }
    return s;
  }
}
