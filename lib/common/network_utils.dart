/// Returns true if [e] represents a connection or TLS/SSL error.
bool isConnectionOrTlsError(dynamic e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('wrong version') ||
      msg.contains('handshake') ||
      msg.contains('tlsexception') ||
      msg.contains('certificate') ||
      msg.contains('socketexception') ||
      msg.contains('clientexception') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable') ||
      msg.contains('сетевое подключение');
}

/// Returns the HTTP (non-TLS) fallback URL for [baseUrl].
String httpFallback(String baseUrl) {
  return baseUrl.startsWith('https:') ? 'http:${baseUrl.substring(6)}' : baseUrl;
}
