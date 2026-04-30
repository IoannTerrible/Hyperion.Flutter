import 'package:flutter/foundation.dart';
import 'package:hyperion_flutter/config/api_config.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:hyperion_flutter/users/users_api.dart' as users_api;
import 'package:http/http.dart' as http;

class DeleteAccountController extends ChangeNotifier {
  bool _disposed = false;
  final _client = http.Client();

  bool busy = false;

  Future<void> deleteAccount({
    required String token,
    required Future<void> Function() signOut,
  }) async {
    busy = true;
    _notify();
    try {
      await users_api.deleteMyAccount(
        _client,
        ApiConfig.authBaseUrl,
        token,
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      AppLogger.log('[DeleteAccountController] Account deletion requested, signing out');
      await signOut();
    } catch (e) {
      AppLogger.log('[DeleteAccountController] deleteMyAccount error: $e');
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
