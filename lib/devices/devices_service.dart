import 'package:clietn_server_application/auth/auth_notifier.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:clietn_server_application/devices/devices_api.dart' as api;
import 'package:clietn_server_application/logging/app_logger.dart';
import 'package:http/http.dart' as http;

/// Stub devices for demo mode.
List<api.Device> get stubDevices => [
      const api.Device(
        id: 'dev-1',
        name: 'Demo Device',
        status: 'Online',
        icon: 'smartphone',
        instances: null,
      ),
    ];

/// Stub sessions for demo mode.
List<api.Session> get stubSessions => [
      const api.Session(id: 'stub-1', name: 'Mobile Device', icon: 'smartphone'),
      const api.Session(id: 'stub-2', name: 'Desktop', icon: 'desktop_windows'),
    ];

/// Stub plugin catalog for demo mode.
List<api.Plugin> get stubPluginCatalog => const [
      api.Plugin(id: '44424700-0000-4000-8000-000000000007', name: 'Debug Info', enabled: false, icon: 'bug_report'),
      api.Plugin(id: '43550000-0000-4000-8000-000000000008', name: 'Compact UI', enabled: false, icon: 'view_compact'),
    ];

bool _isConnectionOrTlsError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('wrong version') ||
      s.contains('handshake') ||
      s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('connection refused') ||
      s.contains('сетевое подключение');
}

/// Delivers devices, sessions and plugin catalog: with token → API; demo → stubs.
class DevicesService {
  final http.Client _client = http.Client();
  final String baseUrl;
  final String fallbackBaseUrl;
  final AuthNotifier _authNotifier;

  DevicesService({
    required this.baseUrl,
    required this.fallbackBaseUrl,
    required AuthNotifier authNotifier,
  }) : _authNotifier = authNotifier;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<String?> _getValidToken() => _authNotifier.getToken();

  Future<String?> _refreshAndGetToken() async {
    final ok = await _authNotifier.tryRefreshSession();
    if (!ok) {
      await _authNotifier.signOut();
      return null;
    }
    return _authNotifier.getToken();
  }

  // ── Device registration ────────────────────────────────────────────────────

  /// Register or update this device on the backend. Idempotent — safe to call on every login.
  Future<void> registerDevice(String deviceId, String name) async {
    final state = _authNotifier.state;
    if (state is! Authenticated || state.isDemo) return;
    final token = await _getValidToken();
    if (token == null || token.isEmpty) return;
    final request = api.RegisterDeviceRequest(
      deviceId: deviceId,
      name: name,
      deviceType: 'Phone',
    );
    AppLogger.log('[DevicesService] registerDevice: $deviceId "$name"');
    try {
      await api.registerDevice(_client, baseUrl, token, request);
      AppLogger.log('[DevicesService] registerDevice: success');
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        await api.registerDevice(_client, fallbackBaseUrl, token, request);
      }
      // Best-effort — registration failure is non-fatal
    }
  }

  // ── Devices ────────────────────────────────────────────────────────────────

  Future<List<api.Device>> getDevices() async {
    final state = _authNotifier.state;
    if (state is! Authenticated) {
      AppLogger.log('[DevicesService] getDevices: not authenticated -> stubs');
      return stubDevices;
    }
    if (state.isDemo) {
      AppLogger.log('[DevicesService] getDevices: demo mode -> stubs');
      return stubDevices;
    }
    final token = await _getValidToken();
    if (token == null || token.isEmpty) {
      AppLogger.log('[DevicesService] getDevices: no token -> stubs');
      return stubDevices;
    }
    AppLogger.log('[DevicesService] getDevices: calling API');
    try {
      return await api.getDevices(_client, baseUrl, token);
    } on api.DevicesApiException catch (e) {
      if (e.statusCode == 401) {
        AppLogger.log('[DevicesService] getDevices: 401 -> try refresh');
        final newToken = await _refreshAndGetToken();
        if (newToken != null && newToken.isNotEmpty) {
          return await api.getDevices(_client, baseUrl, newToken);
        }
      }
      rethrow;
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        return await api.getDevices(_client, fallbackBaseUrl, token);
      }
      rethrow;
    }
  }

  /// Delete a device by its ID.
  Future<void> deleteDevice(String deviceId) async {
    final state = _authNotifier.state;
    if (state is! Authenticated || state.isDemo) return;
    final token = await _getValidToken();
    if (token == null || token.isEmpty) return;
    try {
      await api.deleteDevice(_client, baseUrl, token, deviceId);
    } on api.DevicesApiException catch (e) {
      if (e.statusCode == 401) {
        final newToken = await _refreshAndGetToken();
        if (newToken != null && newToken.isNotEmpty) {
          await api.deleteDevice(_client, baseUrl, newToken, deviceId);
          return;
        }
      }
      rethrow;
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        await api.deleteDevice(_client, fallbackBaseUrl, token, deviceId);
      } else {
        rethrow;
      }
    }
  }

  // ── Plugin catalog ─────────────────────────────────────────────────────────

  /// Returns the full plugin catalog. `enabled` is always false in catalog responses —
  /// actual enabled state for mobile is stored locally in PluginSettings.
  Future<List<api.Plugin>> getPluginCatalog() async {
    final state = _authNotifier.state;
    if (state is! Authenticated) return stubPluginCatalog;
    if (state.isDemo) return stubPluginCatalog;
    final token = await _getValidToken();
    if (token == null || token.isEmpty) return stubPluginCatalog;
    AppLogger.log('[DevicesService] getPluginCatalog: calling API');
    try {
      return await api.getPluginCatalog(_client, baseUrl, token);
    } on api.DevicesApiException catch (e) {
      if (e.statusCode == 401) {
        AppLogger.log('[DevicesService] getPluginCatalog: 401 -> try refresh');
        final newToken = await _refreshAndGetToken();
        if (newToken != null && newToken.isNotEmpty) {
          return await api.getPluginCatalog(_client, baseUrl, newToken);
        }
      }
      rethrow;
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        return await api.getPluginCatalog(_client, fallbackBaseUrl, token);
      }
      rethrow;
    }
  }

  // ── Sessions ───────────────────────────────────────────────────────────────

  Future<List<api.Session>> getSessions() async {
    final state = _authNotifier.state;
    if (state is! Authenticated) {
      AppLogger.log('[DevicesService] getSessions: not authenticated -> stubs');
      return stubSessions;
    }
    if (state.isDemo) {
      AppLogger.log('[DevicesService] getSessions: demo mode -> stubs');
      return stubSessions;
    }
    final token = await _getValidToken();
    if (token == null || token.isEmpty) {
      AppLogger.log('[DevicesService] getSessions: no token -> stubs');
      return stubSessions;
    }
    AppLogger.log('[DevicesService] getSessions: calling API');
    try {
      return await api.getSessions(_client, baseUrl, token);
    } on api.DevicesApiException catch (e) {
      if (e.statusCode == 401) {
        AppLogger.log('[DevicesService] getSessions: 401 -> try refresh');
        final newToken = await _refreshAndGetToken();
        if (newToken != null && newToken.isNotEmpty) {
          return await api.getSessions(_client, baseUrl, newToken);
        }
      }
      rethrow;
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        return await api.getSessions(_client, fallbackBaseUrl, token);
      }
      rethrow;
    }
  }

  /// Revoke a specific session by its refresh token ID.
  Future<void> revokeSession(String sessionId) async {
    final state = _authNotifier.state;
    if (state is! Authenticated || state.isDemo) return;
    final token = await _getValidToken();
    if (token == null || token.isEmpty) return;
    try {
      await api.deleteSession(_client, baseUrl, token, sessionId);
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        await api.deleteSession(_client, fallbackBaseUrl, token, sessionId);
      } else {
        rethrow;
      }
    }
  }

  // ── Instance plugins (desktop) ─────────────────────────────────────────────

  /// Toggle plugin enabled state on a desktop instance.
  Future<void> patchPluginEnabled(
    String instanceId,
    String pluginId,
    bool enabled, {
    String? deviceId,
  }) async {
    final state = _authNotifier.state;
    if (state is! Authenticated || state.isDemo) return;
    final token = await _getValidToken();
    if (token == null || token.isEmpty) return;
    try {
      await api.patchPluginEnabled(
        _client,
        baseUrl,
        token,
        instanceId,
        pluginId,
        enabled,
        deviceId: deviceId,
      );
    } on api.DevicesApiException catch (e) {
      if (e.statusCode == 401) {
        AppLogger.log('[DevicesService] patchPluginEnabled: 401 -> try refresh');
        final newToken = await _refreshAndGetToken();
        if (newToken != null && newToken.isNotEmpty) {
          await api.patchPluginEnabled(
            _client,
            baseUrl,
            newToken,
            instanceId,
            pluginId,
            enabled,
            deviceId: deviceId,
          );
          return;
        }
      }
      rethrow;
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        await api.patchPluginEnabled(
          _client,
          fallbackBaseUrl,
          token,
          instanceId,
          pluginId,
          enabled,
          deviceId: deviceId,
        );
      } else {
        rethrow;
      }
    }
  }

  // ── Logs ───────────────────────────────────────────────────────────────────

  /// Upload app logs to server. Returns true on success. In demo mode: no-op, returns false.
  Future<bool> uploadLogs() async {
    final state = _authNotifier.state;
    if (state is! Authenticated || state.isDemo) return false;
    final token = await _getValidToken();
    if (token == null || token.isEmpty) return false;
    final content = await AppLogger.getLogContent();
    if (content.isEmpty) return false;
    try {
      await api.uploadLogs(_client, baseUrl, token, content);
      return true;
    } on api.DevicesApiException catch (e) {
      if (e.statusCode == 401) {
        AppLogger.log('[DevicesService] uploadLogs: 401 -> try refresh');
        final newToken = await _refreshAndGetToken();
        if (newToken != null && newToken.isNotEmpty) {
          await api.uploadLogs(_client, baseUrl, newToken, content);
          return true;
        }
      }
      rethrow;
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        await api.uploadLogs(_client, fallbackBaseUrl, token, content);
        return true;
      }
      rethrow;
    }
  }
}
