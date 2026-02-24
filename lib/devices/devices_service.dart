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

/// Delivers devices and sessions: with token → API; demo → stubs.
class DevicesService {
  final http.Client _client = http.Client();
  final String baseUrl;
  final AuthNotifier _authNotifier;

  DevicesService({
    required this.baseUrl,
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
    return api.getDevices(_client, baseUrl, token);
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
    return api.getSessions(_client, baseUrl, token);
  }
}
