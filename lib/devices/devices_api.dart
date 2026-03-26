import 'dart:convert';

import 'package:clietn_server_application/auth/auth_api.dart';
import 'package:clietn_server_application/logging/app_logger.dart';
import 'package:http/http.dart' as http;

// --- DTOs (camelCase JSON) ---

class Plugin {
  final String id;
  final String name;
  final bool enabled;
  final String? icon;

  const Plugin({
    required this.id,
    required this.name,
    required this.enabled,
    this.icon,
  });

  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      icon: json['icon'] as String?,
    );
  }
}

class Instance {
  final String id;
  final String name;
  final String status; // "Running" | "Stopped"
  final List<Plugin> plugins;

  const Instance({
    required this.id,
    required this.name,
    required this.status,
    required this.plugins,
  });

  factory Instance.fromJson(Map<String, dynamic> json) {
    final pluginsList = json['plugins'];
    final list = pluginsList is List ? pluginsList : null;
    return Instance(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'Stopped',
      plugins: list != null
          ? list.map((e) => Plugin.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }
}

class Device {
  final String id;
  final String name;
  final String status; // "Online" | "Offline"
  final String? icon;
  final List<Instance>? instances;

  const Device({
    required this.id,
    required this.name,
    required this.status,
    this.icon,
    this.instances,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    final instancesList = json['instances'];
    final list = instancesList is List ? instancesList : null;
    return Device(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'Offline',
      icon: json['icon'] as String?,
      instances: list?.map((e) => Instance.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class Session {
  final String id;
  final String name;
  final String? icon;
  final DateTime? createdAt;

  const Session({
    required this.id,
    required this.name,
    this.icon,
    this.createdAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: (json['id'] as String?) ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)?.toLocal()
          : null,
    );
  }
}

class RegisterDeviceRequest {
  final String deviceId;
  final String name;
  final String? deviceType;

  const RegisterDeviceRequest({
    required this.deviceId,
    required this.name,
    this.deviceType,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'name': name,
        if (deviceType != null) 'deviceType': deviceType,
      };
}

// --- API calls ---

const _jsonAccept = {'Accept': 'application/json'};

/// POST /api/devices/register — idempotent device registration after login.
Future<void> registerDevice(
  http.Client client,
  String baseUrl,
  String token,
  RegisterDeviceRequest request,
) async {
  final uri = Uri.parse('$baseUrl/api/devices/register');
  final response = await client.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(request.toJson()),
  );
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[devices_api] POST $uri -> ${response.statusCode}');
  AppLogger.log('[devices_api] Response body: ${response.body}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// GET /api/devices — all devices for the current user.
Future<List<Device>> getDevices(
  http.Client client,
  String baseUrl,
  String token,
) async {
  final uri = Uri.parse('$baseUrl/api/devices');
  final response = await client.get(
    uri,
    headers: {
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
  );
  if (response.statusCode == 200) {
    try {
      final list = jsonDecode(response.body);
      if (list is! List) return [];
      return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      throw DevicesApiException('Unexpected server response', statusCode: response.statusCode);
    }
  }
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[devices_api] GET $uri -> ${response.statusCode}');
  AppLogger.log('[devices_api] Response body: ${response.body}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// DELETE /api/devices/{deviceId} — remove a device.
Future<void> deleteDevice(
  http.Client client,
  String baseUrl,
  String token,
  String deviceId,
) async {
  final uri = Uri.parse('$baseUrl/api/devices/$deviceId');
  final response = await client.delete(
    uri,
    headers: {
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
  );
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[devices_api] DELETE $uri -> ${response.statusCode}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// GET /api/plugins — full plugin catalog (enabled is always false in catalog).
Future<List<Plugin>> getPluginCatalog(
  http.Client client,
  String baseUrl,
  String token,
) async {
  final uri = Uri.parse('$baseUrl/api/plugins');
  final response = await client.get(
    uri,
    headers: {
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
  );
  if (response.statusCode == 200) {
    try {
      final list = jsonDecode(response.body);
      if (list is! List) return [];
      return list.map((e) => Plugin.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      throw DevicesApiException('Unexpected server response', statusCode: response.statusCode);
    }
  }
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[devices_api] GET $uri -> ${response.statusCode}');
  AppLogger.log('[devices_api] Response body: ${response.body}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// GET /api/sessions — active sessions (refresh tokens).
Future<List<Session>> getSessions(
  http.Client client,
  String baseUrl,
  String token,
) async {
  final uri = Uri.parse('$baseUrl/api/sessions');
  final response = await client.get(
    uri,
    headers: {
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
  );
  if (response.statusCode == 200) {
    try {
      final list = jsonDecode(response.body);
      if (list is! List) return [];
      return list.map((e) => Session.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      throw DevicesApiException('Unexpected server response', statusCode: response.statusCode);
    }
  }
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[devices_api] GET $uri -> ${response.statusCode}');
  AppLogger.log('[devices_api] Response body: ${response.body}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// DELETE /api/sessions/{id} — revoke a specific session.
Future<void> deleteSession(
  http.Client client,
  String baseUrl,
  String token,
  String sessionId,
) async {
  final uri = Uri.parse('$baseUrl/api/sessions/$sessionId');
  final response = await client.delete(
    uri,
    headers: {
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
  );
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[devices_api] DELETE $uri -> ${response.statusCode}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// PATCH /api/devices/{deviceId}/instances/{instanceId}/plugins/{pluginId}
/// Used by desktop clients that have real instances.
Future<void> patchPluginEnabled(
  http.Client client,
  String baseUrl,
  String token,
  String instanceId,
  String pluginId,
  bool enabled, {
  String? deviceId,
}) async {
  final String path = deviceId != null
      ? '/api/devices/$deviceId/instances/$instanceId/plugins/$pluginId'
      : '/api/instances/$instanceId/plugins/$pluginId';
  final uri = Uri.parse('$baseUrl$path');
  final response = await client.patch(
    uri,
    headers: {
      'Content-Type': 'application/json',
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'enabled': enabled}),
  );
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[devices_api] PATCH $uri -> ${response.statusCode}');
  AppLogger.log('[devices_api] Response body: ${response.body}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// POST /api/logs — upload client log file for diagnostics.
Future<void> uploadLogs(
  http.Client client,
  String baseUrl,
  String token,
  String content,
) async {
  final uri = Uri.parse('$baseUrl/api/logs');
  final response = await client.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'content': content}),
  );
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[devices_api] POST $uri -> ${response.statusCode}');
  AppLogger.log('[devices_api] Response body: ${response.body}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

class DevicesApiException implements Exception {
  final String message;
  final int? statusCode;

  DevicesApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
