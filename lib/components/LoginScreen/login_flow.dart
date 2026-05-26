import 'dart:async';

import 'package:finamp/components/LoginScreen/login_server_selection_page.dart';
import 'package:finamp/models/subsonic_models.dart';
import 'package:finamp/screens/view_selector.dart';
import 'package:finamp/services/subsonic_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'login_authentication_page.dart';
import 'login_splash_page.dart';

class LoginFlow extends StatefulWidget {
  const LoginFlow({super.key});

  @override
  State<LoginFlow> createState() => _LoginFlowState();
}

final loginNavigatorKey = GlobalKey<NavigatorState>();

class _LoginFlowState extends State<LoginFlow> {
  ServerState serverState = ServerState();
  ConnectionState connectionState = ConnectionState();

  @override
  void dispose() {
    serverState.connectionTestDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (context.mounted) {
          if (!loginNavigatorKey.currentState!.canPop()) {
            Navigator.of(context).pop();
          } else {
            loginNavigatorKey.currentState!.pop();
          }
        }
      },
      child: Navigator(
        key: loginNavigatorKey,
        initialRoute: LoginSplashPage.routeName,
        onGenerateRoute: (RouteSettings settings) {
          Route route;

          Route createRoute(Widget page) => PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => page,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              if (MediaQuery.disableAnimationsOf(context)) {
                return child;
              }
              final pushingNext = secondaryAnimation.status == AnimationStatus.forward;
              final poppingNext = secondaryAnimation.status == AnimationStatus.reverse;
              final pushingOrPoppingNext = pushingNext || poppingNext;
              late final Tween<Offset> offsetTween = pushingOrPoppingNext
                  ? Tween<Offset>(begin: const Offset(0.0, 0.0), end: const Offset(-1.0, 0.0))
                  : Tween<Offset>(begin: const Offset(1.0, 0.0), end: const Offset(0.0, 0.0));

              final curveOffsetTween = offsetTween.chain(CurveTween(curve: Curves.ease));

              late final Animation<Offset> slidingAnimation = pushingOrPoppingNext
                  ? curveOffsetTween.animate(secondaryAnimation)
                  : curveOffsetTween.animate(animation);
              return SlideTransition(position: slidingAnimation, child: child);
            },
          );

          switch (settings.name) {
            case LoginSplashPage.routeName:
              route = createRoute(
                LoginSplashPage(
                  onGetStartedPressed: () =>
                      loginNavigatorKey.currentState!.pushNamed(LoginServerSelectionPage.routeName),
                ),
              );
              break;
            case LoginServerSelectionPage.routeName:
              route = createRoute(
                LoginServerSelectionPage(
                  serverState: serverState,
                  onServerSelected: (String baseUrl) {
                    serverState.baseUrl = baseUrl;
                    loginNavigatorKey.currentState!.pushNamed(LoginAuthenticationPage.routeName);
                  },
                ),
              );
              break;
            case LoginAuthenticationPage.routeName:
              route = createRoute(
                LoginAuthenticationPage(
                  serverState: serverState,
                  connectionState: connectionState,
                  onAuthenticated: () {
                    Navigator.of(context).popAndPushNamed(ViewSelector.routeName);
                  },
                ),
              );
              break;
            default:
              throw Exception('Invalid route: ${settings.name}');
          }
          return route;
        },
      ),
    );
  }
}

class ServerState {
  static final _log = Logger("LoginServerState");

  final subsonicApiHelper = GetIt.instance<SubsonicApiHelper>();

  SubsonicServerInfo? detectedServer;
  String? baseUrl;
  Timer? connectionTestDebounceTimer;
  String? baseUrlToTest;
  VoidCallback? updateCallback;

  void onBaseUrlChanged(String baseUrl) {
    if (connectionTestDebounceTimer?.isActive ?? false) {
      connectionTestDebounceTimer?.cancel();
    }
    connectionTestDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      updateCallback?.call();
      try {
        baseUrlToTest = baseUrl;
        updateCallback?.call();
        await testServerConnection(baseUrl);
        baseUrlToTest = null;
        updateCallback?.call();
      } catch (err) {
        // nop
      }
    });
  }

  Future<void> testServerConnection(String baseUrl) async {
    String urlToTest = baseUrl.trim();
    if (!(urlToTest.startsWith("http://") || urlToTest.startsWith("https://"))) {
      urlToTest = "https://$urlToTest";
    }
    if (urlToTest.endsWith("/")) {
      urlToTest = urlToTest.substring(0, urlToTest.length - 1);
    }

    final info = await subsonicApiHelper.probeServer(urlToTest);
    if (this.baseUrlToTest != baseUrl) {
      throw Exception("Server URL changed while testing");
    }

    if (info != null) {
      detectedServer = info;
      this.baseUrl = urlToTest;
    } else if (urlToTest.startsWith("https://")) {
      // HTTPS failed — retry with HTTP
      final httpUrl = urlToTest.replaceFirst("https://", "http://");
      final httpInfo = await subsonicApiHelper.probeServer(httpUrl);
      if (baseUrlToTest != baseUrl) {
        throw Exception("Server URL changed while testing");
      }
      if (httpInfo != null) {
        detectedServer = httpInfo;
        this.baseUrl = httpUrl;
      }
    }
    _log.fine('Server probe result: ${detectedServer?.serverVersion}');
  }
}

class ConnectionState {
  bool isConnected;
  bool isAuthenticating;

  ConnectionState({this.isConnected = false, this.isAuthenticating = false});
}
