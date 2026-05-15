import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/features/splash/viewmodel/splash_view_model.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

void main() {
  group('SplashViewModel - Testes de Navegação', () {
    testWidgets('TC31 - Sessão autenticada navega para menu principal', (
      tester,
    ) async {
      final viewModel = SplashViewModel(
        startupDelay: () async {},
        hasAuthenticatedSession: () => true,
      );
      late BuildContext hostContext;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.menuPrincipal: (_) => const Text('Menu Principal'),
          },
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Text('Splash');
            },
          ),
        ),
      );

      await viewModel.onReady(hostContext);
      await tester.pumpAndSettle();

      expect(find.text('Menu Principal'), findsOneWidget);
      expect(find.text('Splash'), findsNothing);
    });

    testWidgets('TC32 - Falha ao checar sessão navega para login', (
      tester,
    ) async {
      final viewModel = SplashViewModel(
        startupDelay: () async {},
        hasAuthenticatedSession: () =>
            throw StateError('Firebase indisponível'),
      );
      late BuildContext hostContext;

      await tester.pumpWidget(
        MaterialApp(
          routes: {AppRoutes.login: (_) => const Text('Login')},
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Text('Splash');
            },
          ),
        ),
      );

      await viewModel.onReady(hostContext);
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Splash'), findsNothing);
    });
  });
}
