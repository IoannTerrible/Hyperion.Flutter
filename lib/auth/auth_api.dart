import 'dart:convert';

import 'package:http/http.dart' as http;

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

// --- Request DTOs (camelCase JSON) ---

class LoginRequest {
  final String usernameOrEmail;
  final String password;
  final String deviceType;
  final String? deviceId;

  LoginRequest({
    required this.usernameOrEmail,
    required this.password,
    this.deviceType = 'Phone',
    this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'usernameOrEmail': usernameOrEmail,
        'password': password,
        'deviceType': deviceType,
        if (deviceId != null) 'deviceId': deviceId,
      };
}

class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final String firstRegistrationChannel;

  RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    this.firstRegistrationChannel = 'Phone',
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
        'firstRegistrationChannel': firstRegistrationChannel,
      };
}

class ValidateTokenRequest {
  final String token;

  ValidateTokenRequest({required this.token});

  Map<String, dynamic> toJson() => {'token': token};
}

class RefreshTokenRequest {
  final String refreshToken;

  RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

class LogoutRequest {
  final String refreshToken;

  LogoutRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

// --- Response DTOs ---

class UserResponse {
  final String? id;
  final String? username;
  final String? email;
  final bool? emailVerified;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final List<String>? roles;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserResponse({
    this.id,
    this.username,
    this.email,
    this.emailVerified,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.roles,
    this.createdAt,
    this.lastLogin,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      emailVerified: json['emailVerified'] as bool?,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      roles: json['roles'] != null
          ? List<String>.from(json['roles'] as List)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      lastLogin: json['lastLogin'] != null
          ? DateTime.tryParse(json['lastLogin'] as String)
          : null,
    );
  }
}

class AuthenticationResult {
  final bool isValid;
  final String? userId;
  final String? username;
  final String? email;
  final List<String>? roles;
  final String? token;
  final String? refreshToken;
  final String? errorMessage;
  final UserResponse? user;

  AuthenticationResult({
    required this.isValid,
    this.userId,
    this.username,
    this.email,
    this.roles,
    this.token,
    this.refreshToken,
    this.errorMessage,
    this.user,
  });

  factory AuthenticationResult.fromJson(Map<String, dynamic> json) {
    return AuthenticationResult(
      isValid: json['isValid'] as bool? ?? false,
      userId: json['userId'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      roles: json['roles'] != null
          ? List<String>.from(json['roles'] as List)
          : null,
      token: json['token'] as String?,
      refreshToken: json['refreshToken'] as String?,
      errorMessage: json['errorMessage'] as String?,
      user: json['user'] != null
          ? UserResponse.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// ProblemDetails (4xx): extract detail for user message.
String problemDetailsDetail(String body) {
  try {
    final map = jsonDecode(body) as Map<String, dynamic>?;
    if (map == null) return 'Unknown error';
    final d = map['detail'];
    if (d is String) return d;
    if (d != null) return d.toString();
    return map['title'] as String? ?? 'Unknown error';
  } catch (_) {
    return 'Unknown error';
  }
}

// --- API calls ---

const _jsonHeaders = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

Future<AuthenticationResult> postLogin(
  http.Client client,
  String baseUrl,
  LoginRequest request,
) async {
  final uri = Uri.parse('$baseUrl/api/authentication/login');
  final response = await client.post(
    uri,
    headers: _jsonHeaders,
    body: jsonEncode(request.toJson()),
  );
  if (response.statusCode == 200) {
    final map = jsonDecode(response.body) as Map<String, dynamic>?;
    return AuthenticationResult.fromJson(map ?? {});
  }
  if (response.statusCode == 401) {
    throw AuthApiException(
      problemDetailsDetail(response.body),
      statusCode: response.statusCode,
    );
  }
  throw AuthApiException(
    problemDetailsDetail(response.body),
    statusCode: response.statusCode,
  );
}

Future<AuthenticationResult> postRegister(
  http.Client client,
  String baseUrl,
  RegisterRequest request,
) async {
  final uri = Uri.parse('$baseUrl/api/authentication/register');
  final response = await client.post(
    uri,
    headers: _jsonHeaders,
    body: jsonEncode(request.toJson()),
  );
  if (response.statusCode == 200) {
    final map = jsonDecode(response.body) as Map<String, dynamic>?;
    return AuthenticationResult.fromJson(map ?? {});
  }
  if (response.statusCode == 400 || response.statusCode >= 400) {
    throw AuthApiException(
      problemDetailsDetail(response.body),
      statusCode: response.statusCode,
    );
  }
  throw AuthApiException(
    problemDetailsDetail(response.body),
    statusCode: response.statusCode,
  );
}

Future<AuthenticationResult> postValidateToken(
  http.Client client,
  String baseUrl,
  ValidateTokenRequest request,
) async {
  final uri = Uri.parse('$baseUrl/api/authentication/validate-token');
  final response = await client.post(
    uri,
    headers: _jsonHeaders,
    body: jsonEncode(request.toJson()),
  );
  if (response.statusCode == 200) {
    final map = jsonDecode(response.body) as Map<String, dynamic>?;
    return AuthenticationResult.fromJson(map ?? {});
  }
  throw AuthApiException(
    problemDetailsDetail(response.body),
    statusCode: response.statusCode,
  );
}

Future<AuthenticationResult> postRefreshToken(
  http.Client client,
  String baseUrl,
  RefreshTokenRequest request,
) async {
  final uri = Uri.parse('$baseUrl/api/authentication/refresh');
  final response = await client.post(
    uri,
    headers: _jsonHeaders,
    body: jsonEncode(request.toJson()),
  );
  if (response.statusCode == 200) {
    final map = jsonDecode(response.body) as Map<String, dynamic>?;
    return AuthenticationResult.fromJson(map ?? {});
  }
  throw AuthApiException(
    problemDetailsDetail(response.body),
    statusCode: response.statusCode,
  );
}

Future<void> postLogout(
  http.Client client,
  String baseUrl,
  LogoutRequest request,
) async {
  final uri = Uri.parse('$baseUrl/api/authentication/logout');
  final response = await client.post(
    uri,
    headers: _jsonHeaders,
    body: jsonEncode(request.toJson()),
  );
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  throw AuthApiException(
    problemDetailsDetail(response.body),
    statusCode: response.statusCode,
  );
}

Future<void> postVerifyEmail(
  http.Client client,
  String baseUrl, {
  required String token,
  String? fallbackBaseUrl,
}) async {
  final fallback = fallbackBaseUrl ?? _httpFallback(baseUrl);

  Future<void> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/authentication/verify-email')
        .replace(queryParameters: {'token': token});
    final response = await client.get(uri, headers: _jsonHeaders);
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw AuthApiException(
      problemDetailsDetail(response.body),
      statusCode: response.statusCode,
    );
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

Future<void> postResendVerification(
  http.Client client,
  String baseUrl, {
  required String token,
  String? fallbackBaseUrl,
}) async {
  final fallback = fallbackBaseUrl ?? _httpFallback(baseUrl);

  Future<void> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/authentication/resend-verification');
    final response = await client.post(uri, headers: {
      ..._jsonHeaders,
      'Authorization': 'Bearer $token',
    });
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw AuthApiException(
      problemDetailsDetail(response.body),
      statusCode: response.statusCode,
    );
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

Future<UserResponse> getMe(http.Client client, String baseUrl, String token) async {
  final uri = Uri.parse('$baseUrl/api/authentication/me');
  final response = await client.get(
    uri,
    headers: {
      ..._jsonHeaders,
      'Authorization': 'Bearer $token',
    },
  );
  if (response.statusCode == 200) {
    final map = jsonDecode(response.body) as Map<String, dynamic>?;
    return UserResponse.fromJson(map ?? {});
  }
  throw AuthApiException(
    problemDetailsDetail(response.body),
    statusCode: response.statusCode,
  );
}

/// Step 1: Request a password-reset code sent to [email].
Future<void> postForgotPassword(
  http.Client client,
  String baseUrl,
  String email, {
  String? fallbackBaseUrl,
}) async {
  final fallback = fallbackBaseUrl ?? _httpFallback(baseUrl);

  Future<void> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/authentication/forgot-password');
    final response = await client.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw AuthApiException(
      problemDetailsDetail(response.body),
      statusCode: response.statusCode,
    );
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

/// Step 2: Verify the reset [code] for [email].
/// Returns a short-lived [resetToken] to be used in step 3.
Future<String> postVerifyResetCode(
  http.Client client,
  String baseUrl,
  String email,
  String code, {
  String? fallbackBaseUrl,
}) async {
  final fallback = fallbackBaseUrl ?? _httpFallback(baseUrl);

  Future<String> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/authentication/verify-reset-code');
    final response = await client.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (response.statusCode == 200) {
      final map = jsonDecode(response.body) as Map<String, dynamic>?;
      final token = map?['resetToken'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthApiException('Invalid server response: missing resetToken');
      }
      return token;
    }
    throw AuthApiException(
      problemDetailsDetail(response.body),
      statusCode: response.statusCode,
    );
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

/// Step 3: Set [newPassword] using the [resetToken] from step 2.
Future<void> postResetPassword(
  http.Client client,
  String baseUrl,
  String resetToken,
  String newPassword, {
  String? fallbackBaseUrl,
}) async {
  final fallback = fallbackBaseUrl ?? _httpFallback(baseUrl);

  Future<void> makeRequest(String url) async {
    final uri = Uri.parse('$url/api/authentication/reset-password');
    final response = await client.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({'resetToken': resetToken, 'newPassword': newPassword}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw AuthApiException(
      problemDetailsDetail(response.body),
      statusCode: response.statusCode,
    );
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

class AuthApiException implements Exception {
  final String message;
  final int? statusCode;

  AuthApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
