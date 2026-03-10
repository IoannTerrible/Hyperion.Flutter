import 'package:clietn_server_application/auth/auth_notifier.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:clietn_server_application/devices/devices_api.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Stub devices (same structure as plan A.1) for demo mode.
List<api.Device> get stubDevices => [
      const api.Device(
        id: 'dev-1',
        name: 'iPhone 14',
        status: 'Online',
        icon: 'smartphone',
        instances: [
          api.Instance(
            id: 'inst-1',
            name: 'Main Instance',
            status: 'Running',
            plugins: [
              api.Plugin(id: 'p1', name: 'Netflix', enabled: true, icon: 'tv'),
              api.Plugin(id: 'p2', name: 'Audio Controller', enabled: false, icon: 'volume_up'),
              api.Plugin(id: 'p3', name: 'Touch Mapper', enabled: true, icon: 'touch_app'),
            ],
          ),
          api.Instance(
            id: 'inst-2',
            name: 'Test Instance',
            status: 'Stopped',
            plugins: [],
          ),
        ],
      ),
      const api.Device(
        id: 'dev-2',
        name: 'Gaming PC',
        status: 'Offline',
        icon: 'desktop',
        instances: null,
      ),
    ];

/// Stub sessions (same structure as plan A.2) for demo mode.
List<api.Session> get stubSessions => [
      const api.Session(deviceId: 'dev-1', name: 'iPhone 14 Pro', icon: 'smartphone', lastSeen: 'today'),
      const api.Session(deviceId: 'dev-2', name: 'Gaming PC', icon: 'desktop', lastSeen: 'tomorrow'),
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

/// Delivers devices and sessions: with token → API; demo → stubs.
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

  Future<List<api.Device>> getDevices() async {
    final state = _authNotifier.state;
    if (state is! Authenticated) {
      debugPrint('[DevicesService] getDevices: not authenticated -> stubs');
      return stubDevices;
    }
    if (state.isDemo) {
      debugPrint('[DevicesService] getDevices: demo mode -> stubs');
      return stubDevices;
    }
    final token = await _authNotifier.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[DevicesService] getDevices: no token -> stubs');
      return stubDevices;
    }
    debugPrint('[DevicesService] getDevices: calling API');
    try {
      return await api.getDevices(_client, baseUrl, token);
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        return await api.getDevices(_client, fallbackBaseUrl, token);
      }
      rethrow;
    }
  }

  Future<List<api.Session>> getSessions() async {
    final state = _authNotifier.state;
    if (state is! Authenticated) {
      debugPrint('[DevicesService] getSessions: not authenticated -> stubs');
      return stubSessions;
    }
    if (state.isDemo) {
      debugPrint('[DevicesService] getSessions: demo mode -> stubs');
      return stubSessions;
    }
    final token = await _authNotifier.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[DevicesService] getSessions: no token -> stubs');
      return stubSessions;
    }
    debugPrint('[DevicesService] getSessions: calling API');
    try {
      return await api.getSessions(_client, baseUrl, token);
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        return await api.getSessions(_client, fallbackBaseUrl, token);
      }
      rethrow;
    }
  }

  /// Toggle plugin enabled state. In demo mode: no-op (local state only).
  Future<void> patchPluginEnabled(
    String instanceId,
    String pluginId,
    bool enabled, {
    String? deviceId,
  }) async {
    final state = _authNotifier.state;
    if (state is! Authenticated || state.isDemo) return;
    final token = await _authNotifier.getToken();
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
}
