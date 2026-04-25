import 'dart:convert';

import 'package:hyperion_flutter/auth/auth_api.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// --- DTOs (camelCase JSON) ---

class Plugin {
  final String id;
  final String name;
  final bool enabled;
  final String? icon;
  final String? description;

  const Plugin({
    required this.id,
    required this.name,
    required this.enabled,
    this.icon,
    this.description,
  });

  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      icon: json['icon'] as String?,
      description: json['description'] as String?,
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

/// Minimal instance summary from GET /api/instances (PluginService).
class InstanceSummary {
  final String instanceId;
  final DateTime lastUpdatedAt;
  final String? clientType;
  final String? label;

  const InstanceSummary({
    required this.instanceId,
    required this.lastUpdatedAt,
    this.clientType,
    this.label,
  });

  factory InstanceSummary.fromJson(Map<String, dynamic> json) {
    return InstanceSummary(
      instanceId: json['instanceId'] as String? ?? '',
      lastUpdatedAt: json['lastUpdatedAt'] != null
          ? (DateTime.tryParse(json['lastUpdatedAt'] as String)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      clientType: json['clientType'] as String?,
      label: json['label'] as String?,
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

// --- Background isolate decoders (top-level required by compute()) ---

List<Device> _decodeDeviceList(String body) {
  final list = jsonDecode(body);
  if (list is! List) return [];
  return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
}

List<Plugin> _decodePluginCatalog(String body) {
  final list = jsonDecode(body);
  if (list is! List) return [];
  return list.map((e) => Plugin.fromJson(e as Map<String, dynamic>)).toList();
}

List<Session> _decodeSessionList(String body) {
  final list = jsonDecode(body);
  if (list is! List) return [];
  return list.map((e) => Session.fromJson(e as Map<String, dynamic>)).toList();
}

List<InstanceSummary> _decodeInstanceList(String body) {
  final list = jsonDecode(body);
  if (list is! List) return [];
  return list.map((e) => InstanceSummary.fromJson(e as Map<String, dynamic>)).toList();
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
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Device registration rejected (HTTP ${response.statusCode})');
  AppLogger.log('[DevicesApi] Server response: ${response.body}');
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
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode == 200) {
    try {
      return await compute(_decodeDeviceList, response.body);
    } catch (_) {
      throw DevicesApiException('Unexpected server response', statusCode: response.statusCode);
    }
  }
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Failed to load devices (HTTP ${response.statusCode})');
  AppLogger.log('[DevicesApi] Server response: ${response.body}');
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
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Failed to delete device (HTTP ${response.statusCode})');
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
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode == 200) {
    try {
      return await compute(_decodePluginCatalog, response.body);
    } catch (_) {
      throw DevicesApiException('Unexpected server response', statusCode: response.statusCode);
    }
  }
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Failed to load plugins (HTTP ${response.statusCode})');
  AppLogger.log('[DevicesApi] Server response: ${response.body}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// GET /api/instances/{instanceId}/plugins — plugin list with real enabled state.
Future<List<Plugin>> getInstancePlugins(
  http.Client client,
  String baseUrl,
  String token,
  String instanceId,
) async {
  final uri = Uri.parse('$baseUrl/api/instances/$instanceId/plugins');
  final response = await client.get(
    uri,
    headers: {
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode == 200) {
    try {
      return await compute(_decodePluginCatalog, response.body);
    } catch (_) {
      throw DevicesApiException('Unexpected server response', statusCode: response.statusCode);
    }
  }
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Failed to load instance plugins (HTTP ${response.statusCode})');
  AppLogger.log('[DevicesApi] Server response: ${response.body}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// GET /api/instances — all instances that have plugin records for the current user.
Future<List<InstanceSummary>> getInstances(
  http.Client client,
  String baseUrl,
  String token,
) async {
  final uri = Uri.parse('$baseUrl/api/instances');
  final response = await client.get(
    uri,
    headers: {
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode == 200) {
    try {
      return await compute(_decodeInstanceList, response.body);
    } catch (_) {
      throw DevicesApiException('Unexpected server response', statusCode: response.statusCode);
    }
  }
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Failed to load instances (HTTP ${response.statusCode})');
  AppLogger.log('[DevicesApi] Server response: ${response.body}');
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
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode == 200) {
    try {
      return await compute(_decodeSessionList, response.body);
    } catch (_) {
      throw DevicesApiException('Unexpected server response', statusCode: response.statusCode);
    }
  }
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Failed to load sessions (HTTP ${response.statusCode})');
  AppLogger.log('[DevicesApi] Server response: ${response.body}');
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
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Failed to revoke session (HTTP ${response.statusCode})');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

/// PATCH /api/instances/{instanceId}/plugins/{pluginId}
/// Plugin Service endpoint — toggle plugin enabled state on a desktop instance.
Future<void> patchPluginEnabled(
  http.Client client,
  String baseUrl,
  String token,
  String instanceId,
  String pluginId,
  bool enabled,
) async {
  final uri = Uri.parse('$baseUrl/api/instances/$instanceId/plugins/$pluginId');
  final response = await client.patch(
    uri,
    headers: {
      'Content-Type': 'application/json',
      ..._jsonAccept,
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'enabled': enabled}),
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Failed to toggle plugin (HTTP ${response.statusCode})');
  AppLogger.log('[DevicesApi] Server response: ${response.body}');
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
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final message = problemDetailsDetail(response.body);
  AppLogger.log('[DevicesApi] Log upload failed (HTTP ${response.statusCode})');
  AppLogger.log('[DevicesApi] Server response: ${response.body}');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

class DevicesApiException implements Exception {
  final String message;
  final int? statusCode;

  DevicesApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
