import 'dart:convert';

import 'package:clietn_server_application/auth/auth_api.dart';
import 'package:flutter/foundation.dart';
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
  final String deviceId;
  final String name;
  final String? icon;
  final String? lastSeen;
  final String? lastSeenAt;

  const Session({
    required this.deviceId,
    required this.name,
    this.icon,
    this.lastSeen,
    this.lastSeenAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      deviceId: json['deviceId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      lastSeen: json['lastSeen'] as String?,
      lastSeenAt: json['lastSeenAt'] as String?,
    );
  }
}

// --- API calls ---

const _jsonAccept = {'Accept': 'application/json'};

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
    final list = jsonDecode(response.body);
    if (list is! List) return [];
    return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }
  final message = problemDetailsDetail(response.body);
  debugPrint('[devices_api] GET $uri -> ${response.statusCode}');
  debugPrint('[devices_api] Response body: ${response.body}');
  debugPrint('[devices_api] Parsed message: $message');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

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
    final list = jsonDecode(response.body);
    if (list is! List) return [];
    return list.map((e) => Session.fromJson(e as Map<String, dynamic>)).toList();
  }
  final message = problemDetailsDetail(response.body);
  debugPrint('[devices_api] GET $uri -> ${response.statusCode}');
  debugPrint('[devices_api] Response body: ${response.body}');
  debugPrint('[devices_api] Parsed message: $message');
  throw DevicesApiException(message, statusCode: response.statusCode);
}

class DevicesApiException implements Exception {
  final String message;
  final int? statusCode;

  DevicesApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
