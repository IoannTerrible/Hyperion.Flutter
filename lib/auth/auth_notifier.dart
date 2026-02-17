import 'package:clietn_server_application/auth/auth_api.dart';
import 'package:clietn_server_application/auth/auth_service.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:flutter/foundation.dart';

class AuthNotifier extends ChangeNotifier {
  final AuthService _service;

  AuthState _state = const Unauthenticated();
  String? _lastError;
  bool _isLoading = false;

  AuthNotifier(this._service);

  AuthState get state => _state;
  String? get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _state is Authenticated;

  set _authState(AuthState value) {
    _state = value;
    _lastError = null;
    notifyListeners();
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
    _lastError = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _service.signIn(usernameOrEmail, password);
      // State updated via onStateChanged from service
    } on AuthApiException catch (e) {
      _lastError = e.message;
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
}
