import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

import '../models/finamp_models.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'naviamp_plugin_state.dart';
import 'subsonic_api.dart';
import 'subsonic_user_helper.dart';

final _log = Logger('NaviampPluginHelper');

const _probeTimeout = Duration(seconds: 5);

/// Information returned by the plugin's capabilities endpoint.
class NaviampPluginInfo {
  const NaviampPluginInfo({required this.version, required this.features});

  final String version;
  final Set<String> features;
}

class NaviampPluginHelper {
  /// Probes <serverUrl>/naviamp/capabilities with Subsonic auth params.
  /// Returns null if the plugin is not installed or the probe fails.
  ///
  /// Supports both HTTP and HTTPS — the scheme is taken directly from [serverUrl]
  /// as configured by the user. HTTPS uses standard certificate validation.
  Future<NaviampPluginInfo?> probe(String serverUrl, SubsonicCredentials creds) async {
    final salt = SubsonicAuth.generateSalt();
    final token = SubsonicAuth.generateToken(creds.password, salt);

    final uri = Uri.parse(serverUrl).replace(
      path: '${Uri.parse(serverUrl).path.replaceAll(RegExp(r'/$'), '')}/naviamp/capabilities',
      queryParameters: {
        'u': creds.username,
        't': token,
        's': salt,
        'v': '1.16.1',
        'c': 'naviamp',
        'f': 'json',
      },
    );

    try {
      final response = await http.get(uri).timeout(_probeTimeout);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      if (body == null) return null;

      final version = body['version'] as String?;
      final featureList = body['features'] as List<dynamic>?;
      if (version == null || featureList == null) return null;

      return NaviampPluginInfo(
        version: version,
        features: featureList.whereType<String>().toSet(),
      );
    } catch (e) {
      _log.fine('Plugin probe failed (not installed or unreachable): $e');
      return null;
    }
  }
}

/// Runs the plugin capability probe and updates [NaviampPlugin] state.
///
/// Call at startup (after session restore) and after login. Fire-and-forget.
Future<void> runNaviampPluginProbe() async {
  final container = GetIt.instance<ProviderContainer>();
  final notifier = container.read(naviampPluginProvider.notifier);

  if (!FinampSettingsHelper.finampSettings.enableNaviampPlugin) {
    notifier.setState(const NaviampPluginDisabled());
    return;
  }

  final userHelper = GetIt.instance<SubsonicUserHelper>();
  if (!userHelper.hasCredentials) {
    notifier.setState(const NaviampPluginUnknown());
    return;
  }

  notifier.setState(const NaviampPluginUnknown());

  final serverUrl = userHelper.serverUrl!;
  final creds = userHelper.credentials!;
  final info = await NaviampPluginHelper().probe(serverUrl, creds);

  NaviampPluginState newState;
  if (info != null) {
    _log.info('Naviamp plugin detected: v${info.version}, features: ${info.features}');
    newState = NaviampPluginPresent(version: info.version, features: info.features);
  } else {
    _log.info('Naviamp plugin not detected at $serverUrl');
    newState = const NaviampPluginAbsent();
  }

  notifier.setState(newState);

  // Persist result to FinampUser cache so the settings page can show last-known
  // state before the next probe completes.
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  final user = finampUserHelper.currentUser;
  if (user != null) {
    user.naviampPluginLastDetected = info != null;
    user.naviampPluginLastVersion = info?.version;
    await finampUserHelper.saveUser(user);
  }
}
