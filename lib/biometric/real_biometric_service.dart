import 'dart:convert';

import 'package:hyperion_flutter/biometric/biometric_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class RealBiometricService implements BiometricService {
  static const _kEnabled      = 'biometric_lock_enabled';
  static const _kAccountsList = 'biometric_accounts';    // JSON list of identifiers
  // Per-account password key: 'biometric_cred_<base64url(identifier)>'

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage;

  RealBiometricService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // Derive a safe storage key from an account identifier.
  String _credKey(String id) {
    final encoded = base64Url.encode(utf8.encode(id.toLowerCase().trim()));
    return 'biometric_cred_$encoded';
  }

  // ---------------------------------------------------------------------------
  // Biometric hardware
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> availableTypes() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.map((t) => t.name).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> authenticate({
    String reason = 'Authenticate to unlock Hyperion',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN/password as fallback
          stickyAuth: true,     // keep dialog if user switches apps mid-auth
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // App-lock toggle
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isEnabled() async {
    final val = await _storage.read(key: _kEnabled);
    return val == 'true';
  }

  @override
  Future<void> setEnabled(bool value) =>
      _storage.write(key: _kEnabled, value: value.toString());

  // ---------------------------------------------------------------------------
  // Multi-account credential storage
  // ---------------------------------------------------------------------------

  @override
  Future<List<String>> getSavedAccounts() async {
    final raw = await _storage.read(key: _kAccountsList);
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveCredentials(String usernameOrEmail, String password) async {
    final accounts = await getSavedAccounts();
    if (!accounts.contains(usernameOrEmail)) {
      accounts.add(usernameOrEmail);
      await _storage.write(key: _kAccountsList, value: jsonEncode(accounts));
    }
    await _storage.write(key: _credKey(usernameOrEmail), value: password);
  }

  @override
  Future<({String usernameOrEmail, String password})?> getCredentialsForAccount(
    String usernameOrEmail,
  ) async {
    final password = await _storage.read(key: _credKey(usernameOrEmail));
    if (password == null) return null;
    return (usernameOrEmail: usernameOrEmail, password: password);
  }

  @override
  Future<void> removeAccount(String usernameOrEmail) async {
    final accounts = await getSavedAccounts();
    accounts.remove(usernameOrEmail);
    await _storage.write(key: _kAccountsList, value: jsonEncode(accounts));
    await _storage.delete(key: _credKey(usernameOrEmail));
  }

  @override
  Future<void> clearCredentials() async {
    final accounts = await getSavedAccounts();
    for (final acc in accounts) {
      await _storage.delete(key: _credKey(acc));
    }
    await _storage.delete(key: _kAccountsList);
  }
}
