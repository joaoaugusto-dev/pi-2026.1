import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';

import '../helpers/sidera_test_fakes.dart';

void main() {
  late FakeAuthService authService;
  late AuthViewModel viewModel;

  setUp(() {
    authService = FakeAuthService();
    viewModel = AuthViewModel(authService: authService);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('AuthViewModel - Testes de Unidade', () {
    test(
      'TC01 - Login válido autentica, limpa erro e carrega o nome',
      () async {
        final success = await viewModel.login(
          '  operador@soufer.com  ',
          'Senha123!',
        );

        expect(success, isTrue);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.userName, 'João Operador');
        expect(
          authService.signInRequests.single.emailOrMatricula,
          'operador@soufer.com',
        );
      },
    );

    test('TC02 - Login inválido exibe mensagem funcional', () async {
      authService.signInException = FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Senha inválida',
      );

      final success = await viewModel.login('operador@soufer.com', 'errada');

      expect(success, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(
        viewModel.errorMessage,
        'Credenciais inválidas. Verifique seus dados.',
      );
    });

    test(
      'TC03 - Cadastro válido envia dados limpos e define usuário',
      () async {
        final success = await viewModel.signUp(
          email: '  novo@soufer.com  ',
          password: 'Senha123!',
          matricula: '  202601  ',
          nome: '  Maria Souza  ',
        );

        expect(success, isTrue);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.userName, 'Maria Souza');
        expect(authService.signUpRequests.single.email, 'novo@soufer.com');
        expect(authService.signUpRequests.single.matricula, '202601');
        expect(authService.signUpRequests.single.nome, 'Maria Souza');
      },
    );

    test('TC04 - Cadastro duplicado mapeia erro de e-mail em uso', () async {
      authService.signUpException = FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Duplicado',
      );

      final success = await viewModel.signUp(
        email: 'duplicado@soufer.com',
        password: 'Senha123!',
        matricula: '202602',
        nome: 'Operador',
      );

      expect(success, isFalse);
      expect(viewModel.errorMessage, 'Este e-mail já está em uso.');
    });

    test(
      'TC05 - Verificação de matrícula e e-mail bloqueia duplicados',
      () async {
        authService.matriculaAvailable = false;

        final matriculaAvailable = await viewModel.checkMatriculaAvailable(
          ' 202603 ',
        );

        expect(matriculaAvailable, isFalse);
        expect(viewModel.errorMessage, 'Esta matrícula já está cadastrada.');

        authService.matriculaAvailable = true;
        authService.emailAvailable = false;

        final emailAvailable = await viewModel.checkEmailAvailable(
          ' duplicado@soufer.com ',
        );

        expect(emailAvailable, isFalse);
        expect(viewModel.errorMessage, 'Este e-mail já está em uso.');
      },
    );

    test('TC06 - Logout encerra sessão e limpa nome em memória', () async {
      await viewModel.signUp(
        email: 'novo@soufer.com',
        password: 'Senha123!',
        matricula: '202604',
        nome: 'Operador Teste',
      );

      await viewModel.logout();

      expect(authService.signOutCalled, isTrue);
      expect(viewModel.userName, isNull);
      expect(viewModel.isLoading, isFalse);
    });
  });
}
