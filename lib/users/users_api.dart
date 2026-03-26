import 'dart:convert';

import 'package:clietn_server_application/auth/auth_api.dart';
import 'package:clietn_server_application/logging/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

bool _isConnectionOrTlsError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('wrong version') ||
      s.contains('handshake') ||
      s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('connection refused') ||
      s.contains('сетевое подключение');
}

String _httpFallback(String url) =>
    url.startsWith('https:') ? 'http:${url.substring(6)}' : url;

class UpdateMyProfileRequest {
  final String? displayName;
  final String? bio;

  UpdateMyProfileRequest({this.displayName, this.bio});

  Map<String, dynamic> toJson() => {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
      };
}

Future<UserResponse> putMyProfile(
  http.Client client,
  String baseUrl,
  String token,
  UpdateMyProfileRequest request, {
  String? fallbackBaseUrl,
}) async {
  final fallback = fallbackBaseUrl ?? _httpFallback(baseUrl);

  Future<UserResponse> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/users/me/profile');
    final response = await client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(request.toJson()),
    );
    AppLogger.log('[UsersApi.putMyProfile] Status: ${response.statusCode}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final map = jsonDecode(response.body) as Map<String, dynamic>?;
        return UserResponse.fromJson(map ?? {});
      } catch (_) {
        throw AuthApiException('Unexpected server response', statusCode: response.statusCode);
      }
    }
    final detail = problemDetailsDetail(response.body);
    AppLogger.log('[UsersApi.putMyProfile] Error: $detail');
    throw AuthApiException(detail, statusCode: response.statusCode);
  }

  try {
    return await makeRequest(baseUrl);
  } catch (e) {
    if (_isConnectionOrTlsError(e) && fallback != baseUrl) {
      return await makeRequest(fallback);
    }
    rethrow;
  }
}

Future<void> deleteMyAvatar(
  http.Client client,
  String baseUrl,
  String token, {
  String? fallbackBaseUrl,
}) async {
  final fallback = fallbackBaseUrl ?? _httpFallback(baseUrl);

  Future<void> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/users/me/avatar');
    final response = await client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    AppLogger.log('[UsersApi.deleteMyAvatar] Status: ${response.statusCode}');
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final detail = problemDetailsDetail(response.body);
    AppLogger.log('[UsersApi.deleteMyAvatar] Error: $detail');
    throw AuthApiException(detail, statusCode: response.statusCode);
  }

  try {
    return await makeRequest(baseUrl);
  } catch (e) {
    if (_isConnectionOrTlsError(e) && fallback != baseUrl) {
      return await makeRequest(fallback);
    }
    rethrow;
  }
}

/// DELETE /api/users/me — schedules account for deletion (backend applies 24h grace period).
Future<void> deleteMyAccount(
  http.Client client,
  String baseUrl,
  String token, {
  String? fallbackBaseUrl,
}) async {
  final fallback = fallbackBaseUrl ?? _httpFallback(baseUrl);

  Future<void> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/users/me');
    final response = await client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    AppLogger.log('[UsersApi.deleteMyAccount] Status: ${response.statusCode}');
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final detail = problemDetailsDetail(response.body);
    AppLogger.log('[UsersApi.deleteMyAccount] Error: $detail');
    throw AuthApiException(detail, statusCode: response.statusCode);
  }

  try {
    return await makeRequest(baseUrl);
  } catch (e) {
    if (_isConnectionOrTlsError(e) && fallback != baseUrl) {
      return await makeRequest(fallback);
    }
    rethrow;
  }
}

Future<UserResponse> putMyAvatar(
  http.Client client,
  String baseUrl,
  String token,
  XFile file, {
  String? fallbackBaseUrl,
}) async {
  final fallback = fallbackBaseUrl ?? _httpFallback(baseUrl);
  final bytes = await file.readAsBytes();

  Future<UserResponse> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/users/me/avatar');
    final req = http.MultipartRequest('PUT', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );

    final streamed = await client.send(req);
    final response = await http.Response.fromStream(streamed);
    AppLogger.log('[UsersApi.putMyAvatar] Status: ${response.statusCode}, File: ${file.name}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final map = jsonDecode(response.body) as Map<String, dynamic>?;
        return UserResponse.fromJson(map ?? {});
      } catch (_) {
        throw AuthApiException('Unexpected server response', statusCode: response.statusCode);
      }
    }
    final detail = problemDetailsDetail(response.body);
    AppLogger.log('[UsersApi.putMyAvatar] Error detail: $detail');
    throw AuthApiException(detail, statusCode: response.statusCode);
  }

  try {
    return await makeRequest(baseUrl);
  } catch (e) {
    if (_isConnectionOrTlsError(e) && fallback != baseUrl) {
      return await makeRequest(fallback);
    }
    rethrow;
  }
}

