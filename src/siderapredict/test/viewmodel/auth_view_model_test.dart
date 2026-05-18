import 'package:flutter_test/flutter_test.dart';

import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import '../fakes/fake_auth_service.dart';

/// Testes de Unidade — AuthViewModel
///
/// Verifica o comportamento de login e cadastro
/// usando uma implementação fake do AuthService.
void main() {
  late FakeAuthService fakeService;
  late AuthViewModel viewmodel;

  setUp(() {
    fakeService = FakeAuthService();
    viewmodel = AuthViewModel(authService: fakeService);
  });

  // ═══════════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════════

  group("AuthViewModel - Login", () {
    test("TC01 — Login com credenciais válidas retorna sucesso", () async {
      //ARRANGE
      await fakeService.signUp(
        email: "joao@email.com",
        password: "Senha@123",
        matricula: "12345",
        nome: "João",
      );

      //ACT
      final resultado = await viewmodel.login("joao@email.com", "Senha@123");

      //ASSERT
      expect(resultado, isTrue);
      expect(viewmodel.errorMessage, isNull);
      expect(viewmodel.userName, "João");
    });

    test("TC02 — Login com senha errada retorna erro", () async {
      //ARRANGE
      await fakeService.signUp(
        email: "joao@email.com",
        password: "Senha@123",
        matricula: "12345",
        nome: "João",
      );

      //ACT
      final resultado = await viewmodel.login("joao@email.com", "senhaerrada");

      //ASSERT
      expect(resultado, isFalse);
      expect(viewmodel.errorMessage, isNotNull);
      expect(viewmodel.errorMessage, contains("Credenciais inválidas"));
    });

    test("TC03 — Login com usuário inexistente retorna erro", () async {
      //ACT
      final resultado = await viewmodel.login(
        "naoexiste@email.com",
        "qualquersenha",
      );

      //ASSERT
      expect(resultado, isFalse);
      expect(viewmodel.errorMessage, isNotNull);
    });

    test("TC04 — isLoading é false antes e depois do login", () async {
      //ARRANGE
      await fakeService.signUp(
        email: "joao@email.com",
        password: "Senha@123",
        matricula: "12345",
        nome: "João",
      );

      //ASSERT (antes)
      expect(viewmodel.isLoading, isFalse);

      //ACT
      await viewmodel.login("joao@email.com", "Senha@123");

      //ASSERT (depois)
      expect(viewmodel.isLoading, isFalse);
    });
  });

  // ═══════════════════════════════════════════
  // CADASTRO
  // ═══════════════════════════════════════════

  group("AuthViewModel - Cadastro", () {
    test("TC05 — Cadastro com dados válidos retorna sucesso", () async {
      //ACT
      final resultado = await viewmodel.signUp(
        email: "novo@email.com",
        password: "Senha@123",
        matricula: "99999",
        nome: "Maria",
      );

      //ASSERT
      expect(resultado, isTrue);
      expect(viewmodel.errorMessage, isNull);
      expect(viewmodel.userName, "Maria");
    });

    test("TC06 — Cadastro com e-mail duplicado retorna erro", () async {
      //ARRANGE
      await viewmodel.signUp(
        email: "joao@email.com",
        password: "Senha@123",
        matricula: "12345",
        nome: "João",
      );
      viewmodel.clearError();

      //ACT
      final resultado = await viewmodel.signUp(
        email: "joao@email.com",
        password: "Outra@123",
        matricula: "99999",
        nome: "Outro",
      );

      //ASSERT
      expect(resultado, isFalse);
      expect(viewmodel.errorMessage, isNotNull);
      expect(viewmodel.errorMessage, contains("e-mail"));
    });

    test("TC07 — Cadastro com matrícula duplicada retorna erro", () async {
      //ARRANGE
      await viewmodel.signUp(
        email: "joao@email.com",
        password: "Senha@123",
        matricula: "12345",
        nome: "João",
      );
      viewmodel.clearError();

      //ACT
      final resultado = await viewmodel.signUp(
        email: "outro@email.com",
        password: "Outra@123",
        matricula: "12345",
        nome: "Outro",
      );

      //ASSERT
      expect(resultado, isFalse);
      expect(viewmodel.errorMessage, isNotNull);
      expect(viewmodel.errorMessage, contains("matrícula"));
    });

    test("TC08 — Verificação de matrícula disponível", () async {
      //ARRANGE
      await fakeService.signUp(
        email: "joao@email.com",
        password: "Senha@123",
        matricula: "12345",
        nome: "João",
      );

      //ACT
      final disponivel = await viewmodel.checkMatriculaAvailable("99999");
      final indisponivel = await viewmodel.checkMatriculaAvailable("12345");

      //ASSERT
      expect(disponivel, isTrue);
      expect(indisponivel, isFalse);
    });

    test("TC09 — Verificação de e-mail disponível", () async {
      //ARRANGE
      await fakeService.signUp(
        email: "joao@email.com",
        password: "Senha@123",
        matricula: "12345",
        nome: "João",
      );

      //ACT
      final disponivel = await viewmodel.checkEmailAvailable("novo@email.com");
      final indisponivel = await viewmodel.checkEmailAvailable(
        "joao@email.com",
      );

      //ASSERT
      expect(disponivel, isTrue);
      expect(indisponivel, isFalse);
    });
  });
}
