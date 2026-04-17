/// Contract for biometric / device-credential authentication.
abstract class BiometricService {
  /// Whether the device hardware supports biometric authentication.
  Future<bool> isAvailable();

  /// Human-readable names of available biometric types (e.g. "face", "fingerprint").
  Future<List<String>> availableTypes();

  /// Prompt the OS biometric dialog with the given [reason].
  ///
  /// Returns `true` on success, `false` on cancellation or failure.
  Future<bool> authenticate({String reason});

  /// Whether the user has enabled biometric app-lock.
  Future<bool> isEnabled();

  /// Persist the user's choice to enable or disable biometric app-lock.
  Future<void> setEnabled(bool value);

  // ---------------------------------------------------------------------------
  // Multi-account credential storage
  // ---------------------------------------------------------------------------

  /// All accounts that have stored biometric credentials, in insertion order.
  Future<List<String>> getSavedAccounts();

  /// Store [password] for [usernameOrEmail].
  /// If the account already exists its password is updated, not duplicated.
  Future<void> saveCredentials(String usernameOrEmail, String password);

  /// Retrieve credentials for a specific account.
  /// Returns `null` if not found.
  Future<({String usernameOrEmail, String password})?> getCredentialsForAccount(
    String usernameOrEmail,
  );

  /// Remove one account's credentials.
  Future<void> removeAccount(String usernameOrEmail);

  /// Remove all stored credentials for all accounts.
  Future<void> clearCredentials();
}
