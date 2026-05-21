import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/auth/view/login_page.dart';
import 'package:siderapredict/app/features/auth/view/signup_page.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/features/auth/viewmodel/login_view_model.dart';
import 'package:siderapredict/app/features/auth/viewmodel/signup_view_model.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

import '../test/fakes/fake_auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Fluxo de autenticação - Testes de Integração', () {
    testWidgets('TC25 - Cadastro e navegação para Menu Principal', (
      tester,
    ) async {
      final fakeAuthService = FakeAuthService();
      final authViewModel = AuthViewModel(authService: fakeAuthService);

      await tester.pumpWidget(_buildAuthFlowApp(authViewModel));
      await tester.pumpAndSettle();

      expect(find.text('BEM-VINDO'), findsOneWidget);
      expect(find.text('ENTRAR'), findsOneWidget);

      await tester.tap(find.text('Não tem uma conta? Cadastre-se'));
      await tester.pumpAndSettle();

      expect(find.text('Como podemos te chamar?'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Fulano Integracao',
      );
      await tester.tap(find.text('AVANÇAR'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Matrícula'),
        '54321',
      );
      await tester.tap(find.text('AVANÇAR'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'fulano.integracao@email.com',
      );
      await tester.tap(find.text('AVANÇAR'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'Senha@123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar Senha'),
        'Senha@123',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('MENU PRINCIPAL'), findsOneWidget);
      expect(authViewModel.userName, 'Fulano Integracao');

      fakeAuthService.dispose();
      authViewModel.dispose();
    });

    testWidgets('TC26 - Login com campos vazios exibe validacoes', (
      tester,
    ) async {
      final fakeAuthService = FakeAuthService();
      final authViewModel = AuthViewModel(authService: fakeAuthService);

      await tester.pumpWidget(_buildAuthFlowApp(authViewModel));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ENTRAR'));
      await tester.pumpAndSettle();

      expect(find.text('Campo obrigatório'), findsOneWidget);
      expect(find.text('Senha obrigatória'), findsOneWidget);
      expect(find.text('MENU PRINCIPAL'), findsNothing);

      fakeAuthService.dispose();
      authViewModel.dispose();
    });

    testWidgets('TC27 - Login invalido exibe mensagem e nao navega', (
      tester,
    ) async {
      final fakeAuthService = FakeAuthService();
      final authViewModel = AuthViewModel(authService: fakeAuthService);

      await fakeAuthService.signUp(
        email: 'operador@email.com',
        password: 'Senha@123',
        matricula: '12345',
        nome: 'Operador Teste',
      );
      await fakeAuthService.signOut();

      await tester.pumpWidget(_buildAuthFlowApp(authViewModel));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail ou Matrícula'),
        'operador@email.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'senhaerrada',
      );
      await tester.tap(find.text('ENTRAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(
        find.text('Credenciais inválidas. Verifique seus dados.'),
        findsOneWidget,
      );
      expect(find.text('MENU PRINCIPAL'), findsNothing);

      fakeAuthService.dispose();
      authViewModel.dispose();
    });

    testWidgets('TC28 - Login valido navega para Menu Principal', (
      tester,
    ) async {
      final fakeAuthService = FakeAuthService();
      final authViewModel = AuthViewModel(authService: fakeAuthService);

      await fakeAuthService.signUp(
        email: 'login.ok@email.com',
        password: 'Senha@123',
        matricula: '77777',
        nome: 'Login Ok',
      );
      await fakeAuthService.signOut();

      await tester.pumpWidget(_buildAuthFlowApp(authViewModel));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail ou Matrícula'),
        'login.ok@email.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'Senha@123',
      );
      await tester.tap(find.text('ENTRAR'));
      await tester.pumpAndSettle();

      expect(find.text('MENU PRINCIPAL'), findsOneWidget);
      expect(authViewModel.userName, 'Login Ok');

      fakeAuthService.dispose();
      authViewModel.dispose();
    });
  });
}

Widget _buildAuthFlowApp(AuthViewModel authViewModel) {
  return ChangeNotifierProvider<AuthViewModel>.value(
    value: authViewModel,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      initialRoute: AppRoutes.login,
      routes: <String, WidgetBuilder>{
        AppRoutes.login: (_) => ChangeNotifierProvider<LoginViewModel>(
          create: (context) =>
              LoginViewModel(authViewModel: context.read<AuthViewModel>()),
          child: const LoginPage(),
        ),
        AppRoutes.signup: (_) => ChangeNotifierProvider<SignupViewModel>(
          create: (context) =>
              SignupViewModel(authViewModel: context.read<AuthViewModel>()),
          child: const SignupPage(),
        ),
        AppRoutes.menuPrincipal: (_) => const _IntegrationHomePage(),
      },
    ),
  );
}

class _IntegrationHomePage extends StatelessWidget {
  const _IntegrationHomePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'MENU PRINCIPAL',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
