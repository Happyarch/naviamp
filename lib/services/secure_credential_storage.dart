import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] to store the Subsonic password securely.
///
/// On Android this uses EncryptedSharedPreferences backed by the Android
/// Keystore. On Linux it delegates to the freedesktop Secret Service (GNOME
/// Keyring / KWallet). No password is ever written to Isar or Hive.
class SecureCredentialStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _passwordKey = 'naviamp.subsonic_password';

  static Future<void> savePassword(String password) =>
      _storage.write(key: _passwordKey, value: password);

  static Future<String?> loadPassword() => _storage.read(key: _passwordKey);

  static Future<void> clearPassword() => _storage.delete(key: _passwordKey);
}
