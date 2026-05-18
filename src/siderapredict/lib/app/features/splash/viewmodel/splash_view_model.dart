import 'package:flutter/material.dart';

import 'package:siderapredict/app/core/services/auth_service.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

class SplashViewModel extends ChangeNotifier {
  SplashViewModel({
    Future<void> Function()? startupDelay,
    bool Function()? hasAuthenticatedSession,
    AuthService? authService,
  }) : _startupDelay =
           startupDelay ??
           (() => Future<void>.delayed(const Duration(milliseconds: 2500))),
       _hasAuthenticatedSession =
           hasAuthenticatedSession ??
           (() => (authService ?? AuthService()).currentUser != null);

  final Future<void> Function() _startupDelay;
  final bool Function() _hasAuthenticatedSession;

  bool _started = false;

  void scheduleNavigation(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        onReady(context);
      }
    });
  }

  Future<void> onReady(BuildContext context) async {
    if (_started) return;
    _started = true;

    await _startupDelay();
    if (!context.mounted) return;

    final route = _safeInitialRoute();
    Navigator.of(context).pushReplacementNamed(route);
  }

  String _safeInitialRoute() {
    try {
      return _hasAuthenticatedSession()
          ? AppRoutes.menuPrincipal
          : AppRoutes.login;
    } catch (_) {
      return AppRoutes.login;
    }
  }
}
