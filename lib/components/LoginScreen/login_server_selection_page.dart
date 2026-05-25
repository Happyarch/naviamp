import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/subsonic_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import 'login_flow.dart';

class LoginServerSelectionPage extends StatefulWidget {
  static const routeName = "login/server-selection";

  final ServerState serverState;
  final void Function(String baseUrl)? onServerSelected;

  const LoginServerSelectionPage({super.key, required this.serverState, this.onServerSelected});

  @override
  State<LoginServerSelectionPage> createState() => _LoginServerSelectionPageState();
}

class _LoginServerSelectionPageState extends State<LoginServerSelectionPage> {
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    widget.serverState.updateCallback = () {
      if (mounted) setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Center(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 32.0, bottom: 20.0),
                child: Hero(tag: "finamp_logo", child: FinampIcon(75, 75)),
              ),
              Text(
                AppLocalizations.of(context)!.loginFlowServerSelectionHeading,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SimpleButton(
                    icon: TablerIcons.chevron_left,
                    text: AppLocalizations.of(context)!.back,
                    onPressed: () {
                      widget.serverState.detectedServer = null;
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
              _buildServerUrlInput(context),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 95.0),
                child: widget.serverState.baseUrlToTest != null && widget.serverState.detectedServer == null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Padding(padding: EdgeInsets.all(4.0), child: CircularProgressIndicator()),
                            const SizedBox(width: 8.0),
                            Text(
                              AppLocalizations.of(context)!.connectingToServer,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : Visibility(
                        visible: widget.serverState.detectedServer != null,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: NavidromeServerWidget(
                            baseUrl: widget.serverState.baseUrl,
                            serverInfo: widget.serverState.detectedServer,
                            onPressed: () {
                              widget.onServerSelected?.call(widget.serverState.baseUrl!);
                            },
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Form _buildServerUrlInput(BuildContext context) {
    final node = FocusScope.of(context);

    InputDecoration inputFieldDecoration(String placeholder) {
      return InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        label: Text(placeholder),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(16)),
        suffixIcon: IconButton(
          color: Theme.of(context).iconTheme.color,
          icon: const Icon(Icons.info),
          tooltip: AppLocalizations.of(context)!.serverUrlInfoButtonTooltip,
          onPressed: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Text(AppLocalizations.of(context)!.internalExternalIpExplanation),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(MaterialLocalizations.of(context).okButtonLabel),
                ),
              ],
            ),
          ),
        ),
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
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
              child: Text(AppLocalizations.of(context)!.serverUrl, textAlign: TextAlign.start),
            ),
            TextFormField(
              autocorrect: false,
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
              decoration: inputFieldDecoration(AppLocalizations.of(context)!.serverUrlHint),
              textInputAction: TextInputAction.next,
              onEditingComplete: () => node.nextFocus(),
              onChanged: (value) async {
                widget.serverState.detectedServer = null;
                widget.serverState.baseUrl = value;
                if (formKey.currentState?.validate() ?? false) {
                  widget.serverState.onBaseUrlChanged(value);
                }
              },
              validator: (value) {
                if (value?.isEmpty ?? false) {
                  return AppLocalizations.of(context)!.emptyServerUrl;
                }
                return null;
              },
              onSaved: (newValue) => widget.serverState.baseUrl = newValue,
            ),
          ],
        ),
      ),
    );
  }
}

class NavidromeServerWidget extends StatelessWidget {
  final String? baseUrl;
  final SubsonicServerInfo? serverInfo;
  final void Function()? onPressed;

  const NavidromeServerWidget({
    super.key,
    required this.baseUrl,
    required this.serverInfo,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    Row buildContent() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(TablerIcons.music, size: 36),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Navidrome",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (serverInfo?.serverVersion != null)
                  Text("v${serverInfo!.serverVersion}", style: Theme.of(context).textTheme.bodySmall),
                if (baseUrl != null)
                  Text(baseUrl!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      );
    }

    return onPressed != null
        ? ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            ),
            onPressed: onPressed,
            child: buildContent(),
          )
        : Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: buildContent(),
          );
  }
}
