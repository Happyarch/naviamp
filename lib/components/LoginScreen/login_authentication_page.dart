import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/subsonic_models.dart';
import 'package:finamp/services/naviamp_plugin_helper.dart';
import 'package:finamp/services/subsonic_api_helper.dart';
import 'package:finamp/services/subsonic_user_helper.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'login_flow.dart';

class LoginAuthenticationPage extends StatefulWidget {
  static const routeName = "login/authentication";

  final ServerState serverState;
  final ConnectionState? connectionState;
  final VoidCallback? onAuthenticated;

  const LoginAuthenticationPage({
    super.key,
    required this.serverState,
    required this.connectionState,
    required this.onAuthenticated,
  });

  @override
  State<LoginAuthenticationPage> createState() => _LoginAuthenticationPageState();
}

class _LoginAuthenticationPageState extends State<LoginAuthenticationPage> {
  static final _log = Logger("LoginAuthenticationPage");

  final _subsonicApiHelper = GetIt.instance<SubsonicApiHelper>();
  final _subsonicUserHelper = GetIt.instance<SubsonicUserHelper>();

  String? username;
  String? password;

  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Center(
          child: Column(
            children: [
              Padding(padding: const EdgeInsets.only(top: 32.0, bottom: 20.0), child: FinampIcon(75, 75)),
              Text(
                AppLocalizations.of(context)!.loginFlowAuthenticationHeading,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SimpleButton(
                    icon: TablerIcons.chevron_left,
                    text: AppLocalizations.of(context)!.back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              _buildLoginForm(context),
              const SizedBox(height: 16),
              CTAMedium(
                text: AppLocalizations.of(context)!.login,
                icon: TablerIcons.login_2,
                onPressed: () async => await sendForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Form _buildLoginForm(BuildContext context) {
    final node = FocusScope.of(context);

    InputDecoration inputFieldDecoration(String placeholder) {
      return InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        label: Text(placeholder),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(16)),
      );
    }

    return Form(
      key: formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 2.0, left: 8.0),
              child: Text(AppLocalizations.of(context)!.username, textAlign: TextAlign.start),
            ),
            TextFormField(
              autocorrect: false,
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.username],
              decoration: inputFieldDecoration(AppLocalizations.of(context)!.usernameHint),
              textInputAction: TextInputAction.next,
              onEditingComplete: () => node.nextFocus(),
              onSaved: (newValue) => username = newValue,
              validator: (value) {
                if (value?.isEmpty ?? false) {
                  return AppLocalizations.of(context)!.usernameValidationMissingUsername;
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 2.0, left: 8.0),
              child: Text(AppLocalizations.of(context)!.password, textAlign: TextAlign.start),
            ),
            TextFormField(
              autocorrect: false,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
              decoration: inputFieldDecoration(AppLocalizations.of(context)!.passwordHint),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) async => await sendForm(),
              onSaved: (newValue) => password = newValue,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> sendForm() async {
    if ((formKey.currentState?.validate() ?? false) && !(widget.connectionState?.isAuthenticating ?? false)) {
      formKey.currentState!.save();
      setState(() {
        widget.connectionState?.isAuthenticating = true;
      });
      await _authenticate();
      setState(() {
        widget.connectionState?.isAuthenticating = false;
      });
    }
  }

  Future<void> _authenticate() async {
    final serverUrl = widget.serverState.baseUrl;
    if (serverUrl == null) {
      GlobalSnackbar.error("No server URL set. Please go back and select a server.");
      return;
    }

    // Set credentials on the helper so the interceptor can use them for ping.
    _subsonicUserHelper.serverUrlOverride = serverUrl;
    _subsonicUserHelper.setSession(
      serverUrl: serverUrl,
      username: username!,
      password: password ?? '',
    );

    try {
      await _subsonicApiHelper.ping();
    } on SubsonicException catch (e) {
      // Authentication failed — clear the in-memory session
      _subsonicUserHelper.clearSession();
      GlobalSnackbar.error(e.message);
      return;
    } catch (e) {
      _subsonicUserHelper.clearSession();
      GlobalSnackbar.error(e);
      return;
    }

    // Ping succeeded — persist credentials to Isar
    try {
      await _subsonicUserHelper.setSessionAndSave(
        serverUrl: serverUrl,
        username: username!,
        password: password ?? '',
      );
    } catch (e) {
      _log.warning('Failed to persist Subsonic session: $e', e);
    }

    // Probe for the Naviamp plugin on the newly configured server.
    runNaviampPluginProbe();

    if (!mounted) return;
    widget.onAuthenticated?.call();
  }
}
