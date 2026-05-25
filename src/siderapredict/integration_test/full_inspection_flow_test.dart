import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:siderapredict/app/core/services/local_history_store.dart';
import 'package:siderapredict/app/core/services/measurement_service.dart';
import 'package:siderapredict/app/core/services/ollama_report_service.dart';
import 'package:siderapredict/app/core/services/report_export_service.dart';
import 'package:siderapredict/app/core/services/settings_service.dart';
import 'package:siderapredict/app/core/services/supabase_image_storage_service.dart';
import 'package:siderapredict/app/core/services/supabase_measurement_service.dart';
import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/auth/view/login_page.dart';
import 'package:siderapredict/app/features/auth/view/signup_page.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/features/auth/viewmodel/login_view_model.dart';
import 'package:siderapredict/app/features/auth/viewmodel/signup_view_model.dart';
import 'package:siderapredict/app/features/inspection/data/measurement_repository.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/inspection/view/processing_page.dart';
import 'package:siderapredict/app/features/inspection/view/validation_page.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/processing_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/validation_view_model.dart';
import 'package:siderapredict/app/features/menu/view/main_menu_page.dart';
import 'package:siderapredict/app/features/menu/viewmodel/main_menu_view_model.dart';
import 'package:siderapredict/app/features/reports/view/history_page.dart';
import 'package:siderapredict/app/features/reports/viewmodel/history_view_model.dart';
import 'package:siderapredict/app/features/settings/view/settings_page.dart';
import 'package:siderapredict/app/features/settings/viewmodel/settings_view_model.dart';
import 'package:siderapredict/app/routes/app_router.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

import '../test/fakes/fake_auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Fluxo completo de autenticação e medição - Testes de Integração', () {
    testWidgets(
      'TC29 - Auth, modos visuais, histórico, medição simulada e anotação',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        dotenv.loadFromString(envString: 'SIDERA_TEST_ENV=true');
        final prefs = await SharedPreferences.getInstance();

        final fakeAuthService = FakeAuthService();
        final authViewModel = AuthViewModel(authService: fakeAuthService);
        await fakeAuthService.signUp(
          email: 'fluxo.completo@email.com',
          password: 'Senha@123',
          matricula: '29119',
          nome: 'Operador Fluxo',
        );
        await fakeAuthService.signOut();

        final remoteService = _FakeSupabaseMeasurementService();
        final localStore = _InMemoryLocalHistoryStore();
        final ollamaService = _FakeOllamaReportService();
        final repository = MeasurementRepository(
          localStore: localStore,
          remoteService: remoteService,
          imageStorageService: _FakeSupabaseImageStorageService(),
          ollamaService: ollamaService,
          exportService: _FakeReportExportService(),
          currentUserIdProvider: () => fakeAuthService.currentUser?.uid,
          sharedPreferences: prefs,
        );
        final inspectionViewModel = InspectionViewModel(
          measurementService: _FakeMeasurementService(),
          repository: repository,
          cameras: const <CameraDescription>[],
          authService: fakeAuthService,
        );
        final settingsViewModel = SettingsViewModel(
          settingsService: SettingsService(prefs),
        );
        final observedAiStatuses = <AiReportStatus>[];
        void collectAiStatus() {
          if (inspectionViewModel.history.isEmpty) return;
          final status = inspectionViewModel.history.single.aiReportStatus;
          if (observedAiStatuses.isEmpty || observedAiStatuses.last != status) {
            observedAiStatuses.add(status);
          }
        }

        inspectionViewModel.addListener(collectAiStatus);

        await tester.pumpWidget(
          _buildFullFlowApp(
            authViewModel: authViewModel,
            inspectionViewModel: inspectionViewModel,
            settingsViewModel: settingsViewModel,
          ),
        );
        await tester.pumpAndSettle();

        await _login(tester);
        expect(find.text('MENU PRINCIPAL'), findsOneWidget);
        expect(authViewModel.userName, 'Operador Fluxo');

        await tester.tap(find.text('CONFIGURAÇÕES'));
        await tester.pumpAndSettle();
        expect(find.text('CONFIGURAÇÕES'), findsOneWidget);

        await tester.tap(find.byType(Switch).at(0));
        await tester.pumpAndSettle();
        expect(settingsViewModel.isDarkMode, isTrue);
        expect(settingsViewModel.isHighContrast, isFalse);

        await tester.tap(find.byType(Switch).at(1));
        await tester.pumpAndSettle();
        expect(settingsViewModel.isHighContrast, isTrue);
        expect(settingsViewModel.isDarkMode, isFalse);

        await tester.tap(find.byType(Switch).at(1));
        await tester.pumpAndSettle();
        expect(settingsViewModel.isHighContrast, isFalse);
        expect(settingsViewModel.isDarkMode, isFalse);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.text('MENU PRINCIPAL'), findsOneWidget);

        await tester.tap(find.text('HISTÓRICO'));
        await tester.pumpAndSettle();
        expect(find.text('HISTÓRICO'), findsOneWidget);
        expect(find.text('Nenhuma medição registrada.'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.text('MENU PRINCIPAL'), findsOneWidget);

        await tester.tap(find.text('NOVA MEDIÇÃO'));
        await tester.pumpAndSettle();
        expect(find.text('CÂMERA SIMULADA'), findsOneWidget);

        await tester.tap(find.text('SIMULAR FOTO OK'));
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('VALIDAÇÃO'), findsOneWidget);
        expect(inspectionViewModel.currentDraft?.isValidMeasurement, isTrue);

        await tester.enterText(find.byType(TextField).at(0), 'Peça TC29');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        await tester.tap(find.text('NÃO CONFORME'));
        await tester.pumpAndSettle();
        for (final reason in const <String>[
          'Ângulo incorreto',
          'Aresta fora de medida',
          'Furo deslocado',
          'Raio incorreto',
          'Peça amassada/danificada',
          'Rebarba',
          'Outro',
        ]) {
          await tester.ensureVisible(find.text(reason));
          await tester.tap(find.text(reason));
          await tester.pumpAndSettle();
        }

        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Observações adicionais (opcional)...',
          ),
          'Anotação TC29: recurso de observação validado.',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        await tester.tap(find.text('SALVAR'));
        await tester.pump();
        await _pumpUntil(
          tester,
          () =>
              find.text('MENU PRINCIPAL').evaluate().isNotEmpty &&
              inspectionViewModel.history.isNotEmpty,
          timeout: const Duration(seconds: 8),
        );
        await ollamaService.reportStarted.timeout(const Duration(seconds: 3));
        await _pumpUntil(
          tester,
          () =>
              observedAiStatuses.contains(AiReportStatus.generating) &&
              inspectionViewModel.history.single.aiReportStatus ==
                  AiReportStatus.generating,
        );

        expect(find.text('MENU PRINCIPAL'), findsOneWidget);
        expect(inspectionViewModel.history, hasLength(1));
        expect(localStore.statusTransitions, contains(AiReportStatus.pending));
        expect(observedAiStatuses, contains(AiReportStatus.generating));
        final savedRecord = inspectionViewModel.history.single;
        expect(savedRecord.pieceName, 'Peça TC29');
        expect(savedRecord.aiReportStatus, AiReportStatus.generating);
        expect(savedRecord.conformityStatus, ConformityStatus.nok);
        expect(savedRecord.nonConformityReason, 'Outro');
        expect(
          savedRecord.nonConformityObservation,
          'Anotação TC29: recurso de observação validado.',
        );

        ollamaService.completeReport();
        await _pumpUntil(
          tester,
          () =>
              inspectionViewModel.history.single.aiReportStatus ==
              AiReportStatus.completed,
        );
        final completedRecord = inspectionViewModel.history.single;
        expect(observedAiStatuses, contains(AiReportStatus.completed));
        expect(
          localStore.statusTransitions,
          contains(AiReportStatus.completed),
        );
        expect(completedRecord.aiReport, contains('Relatório IA simulado'));

        await tester.tap(find.text('HISTÓRICO'));
        await tester.pumpAndSettle();
        expect(find.text('HISTÓRICO'), findsOneWidget);
        expect(find.text('Peça TC29'), findsOneWidget);
        expect(find.text('NÃO CONFORME'), findsOneWidget);

        inspectionViewModel.removeListener(collectAiStatus);
        fakeAuthService.dispose();
        authViewModel.dispose();
        inspectionViewModel.dispose();
        settingsViewModel.dispose();
        remoteService.dispose();
      },
    );
  });
}

Future<void> _login(WidgetTester tester) async {
  expect(find.text('BEM-VINDO'), findsOneWidget);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'E-mail ou Matrícula'),
    'fluxo.completo@email.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Senha'),
    'Senha@123',
  );
  await tester.tap(find.text('ENTRAR'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 3500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Condição não atingida em ${timeout.inMilliseconds}ms.');
    }
    await tester.pump(step);
  }
}

Widget _buildFullFlowApp({
  required AuthViewModel authViewModel,
  required InspectionViewModel inspectionViewModel,
  required SettingsViewModel settingsViewModel,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
      ChangeNotifierProvider<InspectionViewModel>.value(
        value: inspectionViewModel,
      ),
      ChangeNotifierProvider<SettingsViewModel>.value(value: settingsViewModel),
    ],
    child: Consumer<SettingsViewModel>(
      builder: (context, settings, _) {
        final theme = settings.currentTheme;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sidera Predict - Full Flow Test',
          theme: theme,
          darkTheme: theme,
          initialRoute: AppRoutes.login,
          onGenerateRoute: _testRouteFactory,
        );
      },
    ),
  );
}

Route<dynamic> _testRouteFactory(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.login:
      return MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<LoginViewModel>(
          create: (context) =>
              LoginViewModel(authViewModel: context.read<AuthViewModel>()),
          child: const LoginPage(),
        ),
        settings: settings,
      );
    case AppRoutes.signup:
      return MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<SignupViewModel>(
          create: (context) =>
              SignupViewModel(authViewModel: context.read<AuthViewModel>()),
          child: const SignupPage(),
        ),
        settings: settings,
      );
    case AppRoutes.menuPrincipal:
      return MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<MainMenuViewModel>(
          create: (context) => MainMenuViewModel(
            inspectionViewModel: context.read<InspectionViewModel>(),
            authViewModel: context.read<AuthViewModel>(),
          ),
          child: const MainMenuPage(),
        ),
        settings: settings,
      );
    case AppRoutes.settings:
      return MaterialPageRoute<void>(
        builder: (_) => const SettingsPage(),
        settings: settings,
      );
    case AppRoutes.history:
      return MaterialPageRoute<void>(
        builder: (_) =>
            ChangeNotifierProxyProvider<InspectionViewModel, HistoryViewModel>(
              create: (context) => HistoryViewModel(
                inspectionViewModel: context.read<InspectionViewModel>(),
              ),
              update: (context, inspection, previous) => previous!,
              child: const HistoryPage(),
            ),
        settings: settings,
      );
    case AppRoutes.camera:
      return MaterialPageRoute<void>(
        builder: (_) => const _FakeCameraPage(),
        settings: settings,
      );
    case AppRoutes.processing:
      final args = settings.arguments;
      if (args is! ProcessingArgs) {
        return _errorRoute(
          settings,
          'Argumentos inválidos para processamento.',
        );
      }
      return MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<ProcessingViewModel>(
          create: (context) => ProcessingViewModel(
            inspectionViewModel: context.read<InspectionViewModel>(),
            imagePath: args.imagePath,
          )..scheduleProcessing(context),
          child: const ProcessingPage(),
        ),
        settings: settings,
      );
    case AppRoutes.validation:
      final args = settings.arguments;
      if (args is! ValidationArgs) {
        return _errorRoute(settings, 'Argumentos inválidos para validação.');
      }
      return MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<ValidationViewModel>(
          create: (context) => ValidationViewModel(
            inspectionViewModel: context.read<InspectionViewModel>(),
            draft: args.draft,
          ),
          child: const ValidationPage(),
        ),
        settings: settings,
      );
    default:
      return _errorRoute(settings, 'Rota não encontrada: ${settings.name}');
  }
}

Route<dynamic> _errorRoute(RouteSettings settings, String message) {
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Erro de navegação')),
      body: Center(child: Text(message)),
    ),
  );
}

class _FakeCameraPage extends StatelessWidget {
  const _FakeCameraPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context: context, title: 'Câmera simulada'),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushNamed(
              AppRoutes.processing,
              arguments: const ProcessingArgs(
                imagePath: '/tmp/sidera-fake-camera.jpg',
              ),
            );
          },
          child: const Text('SIMULAR FOTO OK'),
        ),
      ),
    );
  }
}

class _FakeMeasurementService extends MeasurementService {
  @override
  Future<MeasurementDraft> processImage(String imagePath) async {
    return const MeasurementDraft(
      sourceImagePath: '',
      processedImagePath: '',
      calibrationSuccess: true,
      objectFound: true,
      widthMm: 42.125,
      heightMm: 18.75,
      perimeterMm: 121.5,
      areaMm2: 784.25,
      scaleMicronsPerPx: 27.3,
      markerSizeMm: 11,
      quickStatus: 'medição simulada',
      segments: <PieceSegmentMeasurement>[
        PieceSegmentMeasurement(
          type: PieceSegmentType.overallWidth,
          label: 'Largura geral',
          valueMm: 42.125,
        ),
        PieceSegmentMeasurement(
          type: PieceSegmentType.overallHeight,
          label: 'Altura geral',
          valueMm: 18.75,
        ),
        PieceSegmentMeasurement(
          type: PieceSegmentType.hole,
          label: 'Furo 1',
          valueMm: 5.25,
          isRadius: true,
        ),
        PieceSegmentMeasurement(
          type: PieceSegmentType.angle,
          label: 'Ângulo 1',
          valueMm: 90,
          isAngle: true,
        ),
      ],
    );
  }
}

class _InMemoryLocalHistoryStore extends LocalHistoryStore {
  final List<MeasurementRecord> _records = <MeasurementRecord>[];
  final List<AiReportStatus> statusTransitions = <AiReportStatus>[];

  @override
  Future<List<MeasurementRecord>> loadAll() async {
    return List<MeasurementRecord>.from(_records)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> saveAll(List<MeasurementRecord> records) async {
    _records
      ..clear()
      ..addAll(records);
    _trackStatuses(records);
  }

  @override
  Future<void> upsert(MeasurementRecord record) async {
    _records.removeWhere((item) => item.id == record.id);
    _records.add(record);
    _records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _trackStatus(record.aiReportStatus);
  }

  @override
  Future<void> deleteById(String recordId) async {
    _records.removeWhere((item) => item.id == recordId);
  }

  void _trackStatuses(List<MeasurementRecord> records) {
    for (final record in records) {
      _trackStatus(record.aiReportStatus);
    }
  }

  void _trackStatus(AiReportStatus status) {
    if (statusTransitions.isEmpty || statusTransitions.last != status) {
      statusTransitions.add(status);
    }
  }
}

class _FakeSupabaseMeasurementService extends SupabaseMeasurementService {
  _FakeSupabaseMeasurementService() : super(tableName: 'fake_measurements');

  final List<MeasurementRecord> _records = <MeasurementRecord>[];
  final StreamController<List<MeasurementRecord>> _controller =
      StreamController<List<MeasurementRecord>>.broadcast();

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    _records.removeWhere((item) => item.id == record.id);
    _records.add(record);
    _records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _controller.add(List<MeasurementRecord>.from(_records));
  }

  @override
  Future<List<MeasurementRecord>> fetchRecords() async {
    return List<MeasurementRecord>.from(_records);
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    _records.removeWhere((item) => item.id == recordId);
    _controller.add(List<MeasurementRecord>.from(_records));
  }

  @override
  Stream<List<MeasurementRecord>> streamRecords() => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

class _FakeSupabaseImageStorageService extends SupabaseImageStorageService {
  _FakeSupabaseImageStorageService() : super(bucketName: 'fake-images');

  @override
  Future<StoredMeasurementImages> uploadMeasurementImages({
    required String recordId,
    required Uint8List? photoBytes,
    required Uint8List? thumbnailBytes,
    String? ownerUserId,
  }) async {
    return const StoredMeasurementImages(
      photoStoragePath: null,
      thumbnailStoragePath: null,
    );
  }

  @override
  Future<Uint8List?> imageBytesFor(
    MeasurementRecord record, {
    bool preferDetailedImage = false,
  }) async {
    return null;
  }

  @override
  Future<void> deleteImagesFor(MeasurementRecord record) async {}
}

class _FakeOllamaReportService extends OllamaReportService {
  _FakeOllamaReportService()
    : super(baseUrl: 'https://fake.local', model: 'fake');

  final Completer<void> _reportStarted = Completer<void>();
  final Completer<void> _releaseFinalReport = Completer<void>();

  Future<void> get reportStarted => _reportStarted.future;

  void completeReport() {
    if (!_releaseFinalReport.isCompleted) {
      _releaseFinalReport.complete();
    }
  }

  @override
  Stream<AiReportChunk> streamReport({
    required String pieceName,
    required MeasurementDraft draft,
    required DateTime createdAt,
    required ConformityStatus conformityStatus,
    String? nonConformityReason,
    String? nonConformityObservation,
    String? responsavel,
  }) async* {
    if (!_reportStarted.isCompleted) {
      _reportStarted.complete();
    }
    yield AiReportChunk(
      fullText: 'Relatório IA parcial para $pieceName.',
      isDone: false,
    );
    await _releaseFinalReport.future;
    yield AiReportChunk(
      fullText:
          'Relatório IA simulado para $pieceName. Status: ${conformityStatus.storageValue}.',
      isDone: true,
    );
  }
}

class _FakeReportExportService extends ReportExportService {
  @override
  Future<File?> exportSingleRecordPdf(MeasurementRecord record) async => null;

  @override
  Future<File?> exportSingleRecordExcel(MeasurementRecord record) async => null;

  @override
  Future<File?> exportHistoryPdf(List<MeasurementRecord> records) async => null;

  @override
  Future<File?> exportHistoryExcel(List<MeasurementRecord> records) async =>
      null;
}
