/// Static configuration for the GitHub OAuth flow.
///
/// The mobile redirect uses a custom URI scheme registered in
/// `AndroidManifest.xml` (and iOS Universal Link / scheme handler when iOS
/// is added). The desktop flow uses a loopback HTTP server and builds its
/// redirect URI dynamically, so [mobileRedirectUri] is mobile-only.
class GitHubAuthConfig {
  final String clientId;

  /// Custom-scheme redirect used on mobile (Android intent / iOS scheme).
  final String mobileRedirectUri;

  const GitHubAuthConfig({
    required this.clientId,
    this.mobileRedirectUri = 'hyperion://oauth/github',
  });

  bool get isConfigured => clientId.isNotEmpty;
}
