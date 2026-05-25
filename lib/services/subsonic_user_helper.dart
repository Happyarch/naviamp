import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../models/finamp_models.dart';
import 'finamp_user_helper.dart';
import 'secure_credential_storage.dart';

final _log = Logger('SubsonicUserHelper');

/// Holds credentials for the active Subsonic/Navidrome session.
class SubsonicCredentials {
  final String username;
  final String password; // stored to re-generate token+salt per request

  const SubsonicCredentials({required this.username, required this.password});
}

class SubsonicUserHelper {
  String? _serverUrl;
  SubsonicCredentials? _credentials;

  /// Overrides the server URL for a single login attempt (mirrors JellyfinApiHelper.baseUrlTemp).
  /// Set before probing a server; clear after login completes.
  String? serverUrlOverride;

  String? get serverUrl => _serverUrl;
  SubsonicCredentials? get credentials => _credentials;

  bool get hasCredentials => _serverUrl != null && _credentials != null;

  void setSession({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    _serverUrl = serverUrl.trimRight().replaceAll(RegExp(r'/+$'), '');
    _credentials = SubsonicCredentials(username: username, password: password);
    serverUrlOverride = null;
    _log.info('Subsonic session set for $username @ $_serverUrl');
  }

  void clearSession() {
    _serverUrl = null;
    _credentials = null;
    serverUrlOverride = null;
    _log.info('Subsonic session cleared');
  }

  /// Clears the in-memory session and removes the saved password from secure
  /// storage. Call this on logout.
  Future<void> clearSessionAndSave() async {
    clearSession();
    await SecureCredentialStorage.clearPassword();
  }

  /// Restores a saved session from secure storage on app startup.
  ///
  /// Also handles a one-time migration: if the password was previously stored
  /// in plaintext inside [FinampUser.subsonicPassword], it is moved to secure
  /// storage and cleared from the Isar record.
  Future<void> loadIfSaved() async {
    final userHelper = GetIt.instance<FinampUserHelper>();
    final user = userHelper.currentUser;
    if (user == null) return;

    String? password = await SecureCredentialStorage.loadPassword();

    // One-time migration: move plaintext password out of Isar.
    if (password == null && user.subsonicPassword != null) {
      _log.info('Migrating plaintext password to secure storage');
      password = user.subsonicPassword;
      await SecureCredentialStorage.savePassword(password!);
      user.subsonicPassword = null;
      await userHelper.saveUser(user);
    }

    if (password != null) {
      setSession(
        serverUrl: user.publicAddress,
        username: user.id,
        password: password,
      );
    }
  }

  /// Sets the in-memory session, saves the password to secure storage, and
  /// persists the server URL and username to Isar (without the password).
  Future<void> setSessionAndSave({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    setSession(serverUrl: serverUrl, username: username, password: password);
    await SecureCredentialStorage.savePassword(password);
    final user = FinampUser(
      id: username,
      publicAddress: serverUrl,
      localAddress: serverUrl,
      isLocal: false,
      preferLocalNetwork: false,
      accessToken: '',
      serverId: '',
      // subsonicPassword intentionally omitted — stored in secure storage
    );
    await GetIt.instance<FinampUserHelper>().saveUser(user);
  }
}
