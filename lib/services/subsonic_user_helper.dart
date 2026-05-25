import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../models/finamp_models.dart';
import 'finamp_user_helper.dart';

final _log = Logger('SubsonicUserHelper');

/// Holds credentials for the active Subsonic/Navidrome session.
///
/// Phase 2: in-memory only. Phase 4 will back this with Isar persistence
/// and wire it into FinampUser so credentials survive app restarts.
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

  bool get hasCredentials =>
      _serverUrl != null && _credentials != null;

  void setSession({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    _serverUrl = serverUrl.trimRight().replaceAll(RegExp(r'/+$'), ''); // strip trailing slashes
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

  /// Restores a saved session from the [FinampUser] stored in Isar, if one
  /// exists and has Subsonic credentials.
  void loadIfSaved() {
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    if (user?.subsonicPassword != null) {
      setSession(
        serverUrl: user!.publicAddress,
        username: user.id,
        password: user.subsonicPassword!,
      );
    }
  }

  /// Sets the in-memory session and persists the credentials to Isar so they
  /// survive app restarts.
  Future<void> setSessionAndSave({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    setSession(serverUrl: serverUrl, username: username, password: password);
    final user = FinampUser(
      id: username,
      publicAddress: serverUrl,
      localAddress: serverUrl,
      isLocal: false,
      preferLocalNetwork: false,
      accessToken: '',
      serverId: '',
      subsonicPassword: password,
    );
    await GetIt.instance<FinampUserHelper>().saveUser(user);
  }
}
