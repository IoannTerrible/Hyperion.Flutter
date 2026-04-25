import 'dart:convert';

import 'package:hyperion_flutter/auth/auth_api.dart';
import 'package:hyperion_flutter/common/network_utils.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
  final fallback = fallbackBaseUrl ?? httpFallback(baseUrl);

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
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      AppLogger.log('[UsersApi] Profile updated successfully');
      try {
        final map = jsonDecode(response.body) as Map<String, dynamic>?;
        return UserResponse.fromJson(map ?? {});
      } catch (_) {
        throw AuthApiException('Unexpected server response', statusCode: response.statusCode);
      }
    }
    final detail = problemDetailsDetail(response.body);
    AppLogger.log('[UsersApi] Profile update failed (HTTP ${response.statusCode}): $detail');
    throw AuthApiException(detail, statusCode: response.statusCode);
  }

  try {
    return await makeRequest(baseUrl);
  } catch (e) {
    if (isConnectionOrTlsError(e) && fallback != baseUrl) {
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
  final fallback = fallbackBaseUrl ?? httpFallback(baseUrl);

  Future<void> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/users/me/avatar');
    final response = await client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      AppLogger.log('[UsersApi] Avatar deleted successfully');
      return;
    }
    final detail = problemDetailsDetail(response.body);
    AppLogger.log('[UsersApi] Avatar deletion failed (HTTP ${response.statusCode}): $detail');
    throw AuthApiException(detail, statusCode: response.statusCode);
  }

  try {
    return await makeRequest(baseUrl);
  } catch (e) {
    if (isConnectionOrTlsError(e) && fallback != baseUrl) {
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
  final fallback = fallbackBaseUrl ?? httpFallback(baseUrl);

  Future<void> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/users/me');
    final response = await client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      AppLogger.log('[UsersApi] Account deletion scheduled (24h grace period)');
      return;
    }
    final detail = problemDetailsDetail(response.body);
    AppLogger.log('[UsersApi] Account deletion failed (HTTP ${response.statusCode}): $detail');
    throw AuthApiException(detail, statusCode: response.statusCode);
  }

  try {
    return await makeRequest(baseUrl);
  } catch (e) {
    if (isConnectionOrTlsError(e) && fallback != baseUrl) {
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
  final fallback = fallbackBaseUrl ?? httpFallback(baseUrl);
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

    final streamed = await client.send(req).timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      AppLogger.log('[UsersApi] Avatar uploaded successfully: ${file.name}');
      try {
        final map = jsonDecode(response.body) as Map<String, dynamic>?;
        return UserResponse.fromJson(map ?? {});
      } catch (_) {
        throw AuthApiException('Unexpected server response', statusCode: response.statusCode);
      }
    }
    final detail = problemDetailsDetail(response.body);
    AppLogger.log('[UsersApi] Avatar upload failed (HTTP ${response.statusCode}): $detail');
    throw AuthApiException(detail, statusCode: response.statusCode);
  }

  try {
    return await makeRequest(baseUrl);
  } catch (e) {
    if (isConnectionOrTlsError(e) && fallback != baseUrl) {
      return await makeRequest(fallback);
    }
    rethrow;
  }
}

