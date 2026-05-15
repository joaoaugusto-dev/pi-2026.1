import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/features/auth/viewmodel/login_view_model.dart';
import 'package:siderapredict/app/features/auth/viewmodel/signup_view_model.dart';

import '../helpers/sidera_test_fakes.dart';

void main() {
  group('LoginViewModel - Testes de Unidade e Ação', () {
    test('TC07 - Validadores de login bloqueiam entradas inválidas', () {
      final authViewModel = AuthViewModel(authService: FakeAuthService());
      final viewModel = LoginViewModel(authViewModel: authViewModel);
      addTearDown(viewModel.dispose);
      addTearDown(authViewModel.dispose);

      expect(viewModel.identifierValidator(''), 'Campo obrigatório');
      expect(viewModel.identifierValidator('ab'), 'Identificador muito curto');
      expect(viewModel.identifierValidator('202601'), isNull);
      expect(viewModel.passwordValidator(''), 'Senha obrigatória');
      expect(viewModel.passwordValidator('1234567'), 'Mínimo de 8 caracteres');
      expect(viewModel.passwordValidator('Senha123!'), isNull);
    });

    testWidgets('TC08 - Botão de login válido aciona sucesso visual', (
      tester,
    ) async {
      final authViewModel = AuthViewModel(authService: FakeAuthService());
      final viewModel = LoginViewModel(authViewModel: authViewModel);
      late BuildContext formContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                formContext = context;
                return Form(
                  key: viewModel.formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: viewModel.identifierController,
                        validator: viewModel.identifierValidator,
                      ),
                      TextFormField(
                        controller: viewModel.passwordController,
                        validator: viewModel.passwordValidator,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      viewModel.identifierController.text = 'operador@soufer.com';
      viewModel.passwordController.text = 'Senha123!';

      await viewModel.onLoginPressed(formContext);
      await tester.pump();

      expect(viewModel.showSuccess, isTrue);
      expect(viewModel.isLoginDisabled, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      viewModel.dispose();
      authViewModel.dispose();
    });
  });

  group('SignupViewModel - Testes de Unidade e Ação', () {
    test('TC09 - Validadores de cadastro protegem campos obrigatórios', () {
      final authViewModel = AuthViewModel(authService: FakeAuthService());
      final viewModel = SignupViewModel(authViewModel: authViewModel);
      addTearDown(viewModel.dispose);
      addTearDown(authViewModel.dispose);

      expect(viewModel.nomeValidator(''), 'Nome obrigatório');
      expect(viewModel.nomeValidator('Ana'), isNull);
      expect(viewModel.matriculaValidator(''), 'Matrícula obrigatória');
      expect(viewModel.matriculaValidator('12'), 'Matrícula muito curta');
      expect(
        viewModel.matriculaValidator('abc'),
        'Apenas números são permitidos',
      );
      expect(viewModel.matriculaValidator('202601'), isNull);
      expect(viewModel.emailValidator(''), 'E-mail obrigatório');
      expect(viewModel.emailValidator('email-invalido'), 'E-mail inválido');
      expect(viewModel.emailValidator('ana@soufer.com'), isNull);
    });

    test(
      'TC10 - Força de senha exige tamanho, maiúscula, número e especial',
      () {
        final authViewModel = AuthViewModel(authService: FakeAuthService());
        final viewModel = SignupViewModel(authViewModel: authViewModel);
        addTearDown(viewModel.dispose);
        addTearDown(authViewModel.dispose);

        viewModel.passwordController.text = 'senhafraca';
        expect(viewModel.isPasswordStrong, isFalse);

        viewModel.passwordController.text = 'Senha123!';
        expect(viewModel.isPasswordStrong, isTrue);
      },
    );

    testWidgets('TC11 - Finalizar cadastro válido exibe sucesso', (
      tester,
    ) async {
      final authViewModel = AuthViewModel(authService: FakeAuthService());
      final viewModel = SignupViewModel(authViewModel: authViewModel);
      late BuildContext formContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                formContext = context;
                return Form(
                  key: viewModel.formKeySenha,
                  child: Column(
                    children: [
                      TextFormField(controller: viewModel.passwordController),
                      TextFormField(
                        controller: viewModel.confirmPasswordController,
                        validator: viewModel.confirmPasswordValidator,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      viewModel.nomeController.text = 'Ana Operadora';
      viewModel.matriculaController.text = '202601';
      viewModel.emailController.text = 'ana@soufer.com';
      viewModel.passwordController.text = 'Senha123!';
      viewModel.confirmPasswordController.text = 'Senha123!';

      await viewModel.onSignupPressed(formContext);
      await tester.pump();

      expect(viewModel.showSuccess, isTrue);
      expect(authViewModel.userName, 'Ana Operadora');

      await tester.pumpWidget(const SizedBox.shrink());
      viewModel.dispose();
      authViewModel.dispose();
    });
  });
}
