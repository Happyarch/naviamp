import 'package:finamp/services/naviamp_plugin_helper.dart';
import 'package:finamp/services/naviamp_plugin_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/finamp_settings_helper.dart';

class NaviampServerSettingsScreen extends ConsumerWidget {
  const NaviampServerSettingsScreen({super.key});
  static const routeName = '/settings/naviamp-server';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(finampSettingsProvider.enableNaviampPlugin);
    final pluginState = ref.watch(naviampPluginProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Naviamp Server Plugin')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          SwitchListTile(
            title: const Text('Extended server features'),
            subtitle: const Text(
              'Enables capabilities that require the Naviamp companion sidecar '
              'running behind the same reverse proxy as your Navidrome server '
              '(delta sync, performing artist browse, and more). '
              'Has no effect if the sidecar is not installed.',
            ),
            value: enabled ?? true,
            onChanged: (v) => FinampSetters.setEnableNaviampPlugin(v),
          ),
          const Divider(),
          ListTile(
            title: const Text('Plugin status'),
            subtitle: Text(_statusLabel(pluginState)),
            trailing: TextButton(
              onPressed: () => runNaviampPluginProbe(),
              child: const Text('Re-check'),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(NaviampPluginState state) => switch (state) {
    NaviampPluginDisabled() => 'Extended features disabled',
    NaviampPluginUnknown() => 'Checking…',
    NaviampPluginAbsent() => 'Plugin not detected on this server',
    NaviampPluginPresent(:final version, :final features) =>
      'Detected v$version — features: ${features.isEmpty ? "none reported" : features.join(", ")}',
  };
}
