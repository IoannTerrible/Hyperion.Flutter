import 'package:flutter/material.dart';
import 'package:hyperion_flutter/config/api_config.dart';

String friendlyError(Object? e) {
  if (e == null) return 'Unknown error';
  final s = e.toString();
  if (s.contains('<!') || s.contains('<html') || s.contains('DOCTYPE')) {
    return 'Server returned an unexpected response';
  }
  const maxLen = 120;
  return s.length > maxLen ? '${s.substring(0, maxLen)}…' : s;
}

String resolveAvatarUrl(String url) {
  if (url.startsWith('/')) {
    return '${ApiConfig.authFallbackUrl}$url';
  }
  final https = ApiConfig.authBaseUrl;
  final http = ApiConfig.authFallbackUrl;
  if (https != http && url.startsWith(https)) {
    return http + url.substring(https.length);
  }
  return url;
}

void evictAvatarCache(String? avatarUrl) {
  final url = avatarUrl?.trim();
  if (url != null && url.isNotEmpty) {
    PaintingBinding.instance.imageCache.evict(NetworkImage(resolveAvatarUrl(url)));
  }
}

IconData sessionIcon(String? icon) {
  switch (icon) {
    case 'smartphone':
      return Icons.smartphone_outlined;
    case 'desktop_windows':
      return Icons.desktop_windows_outlined;
    default:
      return Icons.devices_other;
  }
}

String sessionCreatedLabel(DateTime? createdAt) {
  if (createdAt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(createdAt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  return '${createdAt.day}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';
}
