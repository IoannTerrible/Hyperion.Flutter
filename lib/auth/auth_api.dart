import 'dart:convert';

import 'package:http/http.dart' as http;

// --- Request DTOs (camelCase JSON) ---

class LoginRequest {
  final String usernameOrEmail;
  final String password;

  LoginRequest({required this.usernameOrEmail, required this.password});

  Map<String, dynamic> toJson() => {
        'usernameOrEmail': usernameOrEmail,
        'password': password,
      };
}

class RegisterRequest {
  final String username;
  final String email;
  final String password;

  RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
      };
}

class ValidateTokenRequest {
  final String token;

  ValidateTokenRequest({required this.token});

  Map<String, dynamic> toJson() => {'token': token};
}

// --- Response DTOs ---

class UserResponse {
  final String? id;
  final String? username;
  final String? email;
  final List<String>? roles;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserResponse({
    this.id,
    this.username,
    this.email,
    this.roles,
    this.createdAt,
    this.lastLogin,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
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
  final String? errorMessage;
  final UserResponse? user;

  AuthenticationResult({
    required this.isValid,
    this.userId,
    this.username,
    this.email,
    this.roles,
    this.token,
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

class AuthApiException implements Exception {
  final String message;
  final int? statusCode;

  AuthApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
