import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'naviamp_plugin_state.g.dart';

sealed class NaviampPluginState {
  const NaviampPluginState();
}

/// User has disabled extended features in settings.
class NaviampPluginDisabled extends NaviampPluginState {
  const NaviampPluginDisabled();
}

/// Probe has not been run yet this session (first launch, or just re-enabled).
class NaviampPluginUnknown extends NaviampPluginState {
  const NaviampPluginUnknown();
}

/// Probe ran; the plugin was not found on the server.
class NaviampPluginAbsent extends NaviampPluginState {
  const NaviampPluginAbsent();
}

/// Probe ran; the plugin is confirmed present.
class NaviampPluginPresent extends NaviampPluginState {
  const NaviampPluginPresent({required this.version, required this.features});

  final String version;

  /// Feature identifiers reported by the plugin, e.g. "delta-sync", "performing-artists".
  final Set<String> features;

  bool supports(String feature) => features.contains(feature);
}

@Riverpod(keepAlive: true)
class NaviampPlugin extends _$NaviampPlugin {
  @override
  NaviampPluginState build() => const NaviampPluginUnknown();

  void setState(NaviampPluginState newState) => state = newState;
}
