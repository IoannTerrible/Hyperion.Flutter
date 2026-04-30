import 'package:flutter/material.dart';
import 'package:hyperion_flutter/auth/auth_state.dart';
import 'package:hyperion_flutter/config/api_config.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:hyperion_flutter/profile/profile_utils.dart';
import 'package:hyperion_flutter/users/users_api.dart' as users_api;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class EditProfileController extends ChangeNotifier {
  final _client = http.Client();
  final _picker = ImagePicker();
  bool _disposed = false;

  final displayName = TextEditingController();
  final bio = TextEditingController();
  bool busy = false;
  bool editing = false;
  String? message;

  void initFromAuth(Authenticated? auth) {
    displayName.text = auth?.displayName ?? '';
    bio.text = auth?.bio ?? '';
  }

  void startEditing() {
    editing = true;
    message = null;
    _notify();
  }

  void cancelEditing(Authenticated? auth) {
    initFromAuth(auth);
    editing = false;
    message = null;
    _notify();
  }

  Future<void> saveProfile({
    required String token,
    required Future<void> Function() onRefresh,
  }) async {
    busy = true;
    message = null;
    _notify();
    try {
      await users_api.putMyProfile(
        _client,
        ApiConfig.authBaseUrl,
        token,
        users_api.UpdateMyProfileRequest(
          displayName: displayName.text.trim().isEmpty ? null : displayName.text.trim(),
          bio: bio.text.trim().isEmpty ? null : bio.text.trim(),
        ),
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      await onRefresh();
      editing = false;
      message = null;
    } catch (e) {
      AppLogger.log('[EditProfileController.saveProfile] Error: $e');
      message = 'Save failed: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> uploadAvatar({
    required String token,
    required String? oldAvatarUrl,
    required Future<void> Function() onRefresh,
  }) async {
    busy = true;
    message = null;
    _notify();
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) {
        busy = false;
        _notify();
        return;
      }
      AppLogger.log('[EditProfileController] Uploading avatar: ${file.name}');
      await users_api.putMyAvatar(
        _client,
        ApiConfig.authBaseUrl,
        token,
        file,
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      evictAvatarCache(oldAvatarUrl);
      await onRefresh();
      message = 'Avatar updated';
    } catch (e) {
      AppLogger.log('[EditProfileController.uploadAvatar] Error: $e');
      message = 'Avatar upload failed: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> deleteAvatar({
    required String token,
    required String? oldAvatarUrl,
    required Future<void> Function() onRefresh,
  }) async {
    busy = true;
    message = null;
    _notify();
    try {
      AppLogger.log('[EditProfileController] Requesting avatar deletion');
      await users_api.deleteMyAvatar(
        _client,
        ApiConfig.authBaseUrl,
        token,
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      evictAvatarCache(oldAvatarUrl);
      await onRefresh();
      message = 'Avatar deleted';
    } catch (e) {
      AppLogger.log('[EditProfileController.deleteAvatar] Error: $e');
      message = 'Delete failed: $e';
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
    displayName.dispose();
    bio.dispose();
    super.dispose();
  }
}
