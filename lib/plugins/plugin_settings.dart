import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Plugin IDs — must match seed in backend DB.
const kPluginDebugInfoId = '44424700-0000-4000-8000-000000000007';
const kPluginCompactUiId = '43550000-0000-4000-8000-000000000008';

const _keyCompactUi = 'plugin_compact_ui';
const _keyDebugInfo = 'plugin_debug_info';

/// App-wide plugin feature flags for mobile. Persisted to secure storage.
class PluginSettings extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _compactUi = false;
  bool _debugInfo = false;

  bool get compactUi => _compactUi;
  bool get debugInfo => _debugInfo;

  /// Load persisted values from secure storage. Call once before runApp.
  Future<void> loadFromStorage() async {
    _compactUi = await _storage.read(key: _keyCompactUi) == 'true';
    _debugInfo = await _storage.read(key: _keyDebugInfo) == 'true';
    // No notifyListeners needed here — called before first build.
  }

  /// Toggle Compact UI and persist the new value.
  Future<void> setCompactUi(bool value) async {
    if (_compactUi == value) return;
    _compactUi = value;
    await _storage.write(key: _keyCompactUi, value: value.toString());
    notifyListeners();
  }

  /// Toggle Debug Info and persist the new value.
  Future<void> setDebugInfo(bool value) async {
    if (_debugInfo == value) return;
    _debugInfo = value;
    await _storage.write(key: _keyDebugInfo, value: value.toString());
    notifyListeners();
  }
}
