import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import '../fakes/fake_auth_service.dart';

/// Testes de Integração — Fluxos Completos
///
/// Testa a interação entre múltiplos componentes do sistema
/// simulando fluxos reais do usuário de ponta a ponta.
void main() {
  late FakeAuthService fakeAuthService;
  late AuthViewModel authViewModel;

  setUp(() {
    fakeAuthService = FakeAuthService();
    authViewModel = AuthViewModel(authService: fakeAuthService);
  });

  group("Integração - Fluxo Completo", () {
    test("TC25 — Cadastro → Login → Verificar usuário logado", () async {
      //ARRANGE — Cadastrar novo usuário
      final cadastroOk = await authViewModel.signUp(
        email: "integra@email.com",
        password: "Senha@123",
        matricula: "77777",
        nome: "Teste Integração",
      );
      expect(cadastroOk, isTrue);

      //ACT — Fazer login com o usuário cadastrado
      final loginOk = await authViewModel.login(
        "integra@email.com",
        "Senha@123",
      );

      //ASSERT — Usuário está autenticado
      expect(loginOk, isTrue);
      expect(authViewModel.userName, "Teste Integração");
      expect(authViewModel.errorMessage, isNull);
    });

    test("TC26 — Login inválido e re-tentativa com dados corretos", () async {
      //ARRANGE
      await authViewModel.signUp(
        email: "retry@email.com",
        password: "Senha@456",
        matricula: "88888",
        nome: "Retry User",
      );

      //ACT — Tentativa com senha errada
      final tentativa1 = await authViewModel.login(
        "retry@email.com",
        "senhaerrada",
      );

      //ASSERT — Primeira tentativa falha
      expect(tentativa1, isFalse);
      expect(authViewModel.errorMessage, isNotNull);

      //ACT — Re-tentativa com senha correta
      final tentativa2 = await authViewModel.login(
        "retry@email.com",
        "Senha@456",
      );

      //ASSERT — Segunda tentativa tem sucesso
      expect(tentativa2, isTrue);
      expect(authViewModel.errorMessage, isNull);
      expect(authViewModel.userName, "Retry User");
    });

    test(
      "TC27 — Cadastro duplicado e depois login com conta original",
      () async {
        //ARRANGE — Primeiro cadastro
        await authViewModel.signUp(
          email: "unico@email.com",
          password: "Senha@789",
          matricula: "11111",
          nome: "Primeiro",
        );
        authViewModel.clearError();

        //ACT — Tentar cadastrar com mesmo e-mail
        final duplicado = await authViewModel.signUp(
          email: "unico@email.com",
          password: "Outra@123",
          matricula: "22222",
          nome: "Segundo",
        );

        //ASSERT — Cadastro duplicado falha
        expect(duplicado, isFalse);
        expect(authViewModel.errorMessage, isNotNull);

        //ACT — Login com conta original funciona
        final loginOk = await authViewModel.login(
          "unico@email.com",
          "Senha@789",
        );

        //ASSERT
        expect(loginOk, isTrue);
        expect(authViewModel.userName, "Primeiro");
      },
    );
  });

  group("Integração - Medição e IA", () {
    test("TC28 — Criar registro e verificar ciclo de status da IA", () {
      //ARRANGE
      final draft = const MeasurementDraft(
        sourceImagePath: '/img.jpg',
        processedImagePath: '/proc.jpg',
        calibrationSuccess: true,
        objectFound: true,
        widthMm: 100.0,
        heightMm: 50.0,
        perimeterMm: 300.0,
        areaMm2: 5000.0,
        scaleMicronsPerPx: 50.0,
        markerSizeMm: 11.0,
        segments: [
          PieceSegmentMeasurement(
            type: PieceSegmentType.overallWidth,
            label: 'Largura',
            valueMm: 100.0,
          ),
        ],
      );

      //ACT — Simular ciclo: pending → generating → completed
      final pendente = MeasurementRecord(
        id: 'ciclo-1',
        pieceName: 'Ciclo IA',
        createdAt: DateTime.now(),
        primaryValueMm: draft.primaryValueMm,
        aiReport: '',
        aiReportStatus: AiReportStatus.pending,
        draft: draft,
      );

      final gerando = pendente.copyWith(
        aiReportStatus: AiReportStatus.generating,
      );

      final concluido = gerando.copyWith(
        aiReport: '## Relatório concluído',
        aiReportStatus: AiReportStatus.completed,
      );

      //ASSERT — Cada etapa tem o status correto
      expect(pendente.aiReportStatus, AiReportStatus.pending);
      expect(pendente.isAiReportStreaming, isTrue);

      expect(gerando.aiReportStatus, AiReportStatus.generating);
      expect(gerando.isAiReportStreaming, isTrue);

      expect(concluido.aiReportStatus, AiReportStatus.completed);
      expect(concluido.isAiReportStreaming, isFalse);
      expect(concluido.aiReport, contains('Relatório'));
    });

    test("TC29 — Serializar lista de registros e restaurar", () {
      //ARRANGE
      final records = List.generate(3, (i) {
        return MeasurementRecord(
          id: 'rec-$i',
          pieceName: 'Peça $i',
          createdAt: DateTime(2026, 5, 17, 10 + i),
          primaryValueMm: 100.0 + i,
          aiReport: 'Relatório $i',
          aiReportStatus: AiReportStatus.completed,
          draft: const MeasurementDraft(
            sourceImagePath: '/img.jpg',
            processedImagePath: '/proc.jpg',
            calibrationSuccess: true,
            objectFound: true,
            widthMm: 100.0,
            heightMm: 50.0,
            perimeterMm: 300.0,
            areaMm2: 5000.0,
            scaleMicronsPerPx: 50.0,
            markerSizeMm: 11.0,
            segments: [],
          ),
        );
      });

      //ACT
      final encoded = MeasurementRecord.encodeList(records);
      final decoded = MeasurementRecord.decodeList(encoded);

      //ASSERT
      expect(decoded.length, 3);
      expect(decoded[0].pieceName, 'Peça 0');
      expect(decoded[2].pieceName, 'Peça 2');
      expect(decoded[1].primaryValueMm, 101.0);
    });
  });
}
