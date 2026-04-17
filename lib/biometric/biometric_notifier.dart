import 'package:hyperion_flutter/biometric/biometric_service.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Represents the current biometric lock state of the app.
enum BiometricLockState {
  /// Lock is disabled or the app is currently unlocked.
  unlocked,

  /// App went to background while lock is enabled — waiting for auth.
  locked,

  /// Biometric dialog is open.
  authenticating,

  /// Last authentication attempt was denied or cancelled.
  failed,
}

/// Manages biometric app-lock state and multi-account sign-in via biometrics.
///
/// Wiring up:
/// 1. Call [init] after creating the notifier (e.g. in main()).
/// 2. Call [onAppPaused] from a [WidgetsBindingObserver] on AppLifecycleState.paused.
/// 3. In the UI layer: check [isLocked] and call [authenticate] to unlock.
/// 4. After password sign-in: call [saveCredentials] to enable biometric sign-in.
/// 5. On the sign-in screen: check [savedAccounts] / [canSignInWithBiometrics],
///    then call [authenticateAndGetCredentials] with the chosen account.
class BiometricNotifier extends ChangeNotifier {
  final BiometricService _service;

  BiometricNotifier(this._service);

  BiometricLockState _lockState = BiometricLockState.unlocked;
  bool _isEnabled = false;
  bool _isAvailable = false;
  List<String> _savedAccounts = [];
  bool _isBiometricSigningIn = false;
  String? _lastError;

  BiometricLockState get lockState => _lockState;

  /// Whether the app is currently locked (auth is required).
  bool get isLocked =>
      _lockState == BiometricLockState.locked ||
      _lockState == BiometricLockState.failed;

  bool get isAuthenticating => _lockState == BiometricLockState.authenticating;

  /// Whether a biometric sign-in attempt is in progress on the sign-in screen.
  bool get isBiometricSigningIn => _isBiometricSigningIn;

  /// Whether biometric lock is turned on by the user.
  bool get isEnabled => _isEnabled;

  /// Whether the device supports biometrics at all.
  bool get isAvailable => _isAvailable;

  /// Accounts that have stored biometric credentials, in insertion order.
  List<String> get savedAccounts => List.unmodifiable(_savedAccounts);

  /// Whether biometric sign-in can be offered (device supports it + at least one account stored).
  bool get canSignInWithBiometrics => _isAvailable && _savedAccounts.isNotEmpty;

  /// Whether more than one account has stored biometric credentials.
  /// When `true` the UI should present an account picker before calling
  /// [authenticateAndGetCredentials].
  bool get hasMultipleAccounts => _savedAccounts.length > 1;

  /// Non-null when an error should be shown to the user.
  String? get lastError => _lastError;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Load persisted settings. Call once at startup before showing any UI.
  Future<void> init() async {
    _isAvailable = await _service.isAvailable();
    _isEnabled = _isAvailable && await _service.isEnabled();
    _savedAccounts = await _service.getSavedAccounts();
    AppLogger.log(
      '[BiometricNotifier] init — available=$_isAvailable, '
      'enabled=$_isEnabled, accounts=${_savedAccounts.length}',
    );
    notifyListeners();
  }

  /// Call when [AppLifecycleState.paused] fires (app goes to background).
  void onAppPaused() {
    if (_isEnabled && _lockState == BiometricLockState.unlocked) {
      _lockState = BiometricLockState.locked;
      _lastError = null;
      AppLogger.log('[BiometricNotifier] app paused — app locked');
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // App-lock authentication
  // ---------------------------------------------------------------------------

  /// Prompt biometrics to unlock the app. No-op if not currently locked.
  Future<void> authenticate() async {
    if (!isLocked) return;

    _lockState = BiometricLockState.authenticating;
    _lastError = null;
    notifyListeners();

    final ok = await _service.authenticate();

    if (ok) {
      _lockState = BiometricLockState.unlocked;
      _lastError = null;
      AppLogger.log('[BiometricNotifier] authentication succeeded');
    } else {
      _lockState = BiometricLockState.failed;
      _lastError = 'Authentication failed. Please try again.';
      AppLogger.log('[BiometricNotifier] authentication failed');
    }
    notifyListeners();
  }

  /// Reset from [BiometricLockState.failed] back to [BiometricLockState.locked]
  /// so the user can retry without re-pausing the app.
  void resetFailure() {
    if (_lockState == BiometricLockState.failed) {
      _lockState = BiometricLockState.locked;
      _lastError = null;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Biometric sign-in (sign-in screen)
  // ---------------------------------------------------------------------------

  /// Authenticate with biometrics and return stored credentials for [usernameOrEmail].
  ///
  /// Returns `null` if the biometric prompt is cancelled, fails, or
  /// no credentials are stored for the given account.
  ///
  /// Typical call sites:
  /// - Single account: `authenticateAndGetCredentials(savedAccounts.first)`
  /// - Multiple accounts: show a picker first, then call with the chosen account.
  Future<({String usernameOrEmail, String password})?> authenticateAndGetCredentials(
    String usernameOrEmail,
  ) async {
    final creds = await _service.getCredentialsForAccount(usernameOrEmail);
    if (creds == null) {
      AppLogger.log('[BiometricNotifier] no credentials stored for $usernameOrEmail');
      return null;
    }

    _isBiometricSigningIn = true;
    notifyListeners();

    final ok = await _service.authenticate(reason: 'Sign in to Hyperion');

    _isBiometricSigningIn = false;
    notifyListeners();

    if (ok) {
      AppLogger.log('[BiometricNotifier] biometric sign-in succeeded for $usernameOrEmail');
      return creds;
    } else {
      AppLogger.log('[BiometricNotifier] biometric sign-in cancelled or failed');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Credential management
  // ---------------------------------------------------------------------------

  /// Store credentials for [usernameOrEmail] so biometric sign-in is available.
  ///
  /// Call this after a successful password sign-in when [isAvailable] is true.
  /// If the account already exists its password is silently updated.
  Future<void> saveCredentials(String usernameOrEmail, String password) async {
    await _service.saveCredentials(usernameOrEmail, password);
    if (!_savedAccounts.contains(usernameOrEmail)) {
      _savedAccounts = [..._savedAccounts, usernameOrEmail];
    }
    AppLogger.log('[BiometricNotifier] credentials saved for $usernameOrEmail '
        '(total accounts: ${_savedAccounts.length})');
    notifyListeners();
  }

  /// Remove one account's biometric credentials, e.g. after explicit sign-out.
  Future<void> removeAccount(String usernameOrEmail) async {
    await _service.removeAccount(usernameOrEmail);
    _savedAccounts = _savedAccounts.where((a) => a != usernameOrEmail).toList();
    AppLogger.log('[BiometricNotifier] removed biometric account: $usernameOrEmail');
    notifyListeners();
  }

  /// Remove all stored biometric credentials.
  Future<void> clearCredentials() async {
    await _service.clearCredentials();
    _savedAccounts = [];
    AppLogger.log('[BiometricNotifier] all biometric credentials cleared');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  /// Enable or disable biometric app-lock.
  ///
  /// Enabling requires one successful authentication first.
  Future<void> setEnabled(bool value) async {
    if (!_isAvailable) return;

    if (value) {
      final ok = await _service.authenticate(
        reason: 'Confirm biometrics to enable app lock',
      );
      if (!ok) {
        _lastError = 'Authentication required to enable biometric lock.';
        notifyListeners();
        return;
      }
    }

    await _service.setEnabled(value);
    _isEnabled = value;

    if (!value && isLocked) {
      _lockState = BiometricLockState.unlocked;
    }

    _lastError = null;
    AppLogger.log('[BiometricNotifier] biometric lock set to $value');
    notifyListeners();
  }
}
