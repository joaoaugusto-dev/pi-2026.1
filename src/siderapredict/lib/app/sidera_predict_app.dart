import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/routes/app_router.dart';
import 'package:siderapredict/app/routes/app_routes.dart';
import 'package:siderapredict/app/config/app_config.dart';
import 'package:siderapredict/app/core/services/local_history_store.dart';
import 'package:siderapredict/app/core/services/measurement_service.dart';
import 'package:siderapredict/app/core/services/ollama_report_service.dart';
import 'package:siderapredict/app/core/services/report_export_service.dart';
import 'package:siderapredict/app/core/services/supabase_image_storage_service.dart';
import 'package:siderapredict/app/core/services/supabase_measurement_service.dart';
import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/inspection/data/measurement_repository.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_view_model.dart';
import 'package:siderapredict/app/core/services/settings_service.dart';
import 'package:siderapredict/app/features/settings/viewmodel/settings_view_model.dart';
import 'package:siderapredict/app/core/services/auth_service.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

final statusBarStyle = SystemUiOverlayStyle(
  statusBarColor: primaryColor,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

class SideraPredictApp extends StatelessWidget {
  factory SideraPredictApp({
    Key? key,
    required List<CameraDescription> cameras,
    required SharedPreferences sharedPreferences,
  }) {
    final authService = AuthService();
    return SideraPredictApp._(
      key: key,
      cameras: cameras,
      sharedPreferences: sharedPreferences,
      authService: authService,
    );
  }

  SideraPredictApp._({
    super.key,
    required List<CameraDescription> cameras,
    required SharedPreferences sharedPreferences,
    required AuthService authService,
  }) : _viewModel = _buildViewModel(
         cameras,
         authService: authService,
         sharedPreferences: sharedPreferences,
       ),
       _settingsViewModel = SettingsViewModel(
         settingsService: SettingsService(sharedPreferences),
       ),
       _authViewModel = AuthViewModel(authService: authService);

  final InspectionViewModel _viewModel;
  final SettingsViewModel _settingsViewModel;
  final AuthViewModel _authViewModel;

  static InspectionViewModel _buildViewModel(
    List<CameraDescription> cameras, {
    required AuthService authService,
    required SharedPreferences sharedPreferences,
  }) {
    final remoteService = SupabaseMeasurementService(
      tableName: AppConfig.supabaseMeasurementsTable,
    );
    final imageStorageService = SupabaseImageStorageService(
      bucketName: AppConfig.supabaseImagesBucket,
    );

    final repository = MeasurementRepository(
      remoteService: remoteService,
      imageStorageService: imageStorageService,
      localStore: LocalHistoryStore(
        sessionKeyProvider: () => authService.currentUser?.uid,
      ),
      ollamaService: OllamaReportService(
        baseUrl: AppConfig.ollamaBaseUrl,
        model: AppConfig.ollamaModel,
      ),
      exportService: ReportExportService(
        imageLoader: imageStorageService.imageBytesFor,
      ),
      currentUserIdProvider: () => authService.currentUser?.uid,
      sharedPreferences: sharedPreferences,
    );

    return InspectionViewModel(
      measurementService: MeasurementService(),
      repository: repository,
      cameras: cameras,
      authService: authService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<InspectionViewModel>.value(value: _viewModel),
        ChangeNotifierProvider<SettingsViewModel>.value(
          value: _settingsViewModel,
        ),
        ChangeNotifierProvider<AuthViewModel>.value(value: _authViewModel),
      ],
      child: Consumer<SettingsViewModel>(
        builder: (context, settings, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Sidera Predict',
            theme: settings.currentTheme,
            themeMode: settings.themeMode,
            builder: (context, child) {
              final isDark = settings.isDarkMode;
              final isHighContrast = settings.isHighContrast;
              // If it's Dark Mode OR High Contrast, the AppBar is black, so icons should be light
              final shouldUseLightIcons = isDark || isHighContrast;

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: statusBarStyle.copyWith(
                  statusBarColor:
                      settings.currentTheme.appBarTheme.backgroundColor,
                  statusBarIconBrightness: shouldUseLightIcons
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: shouldUseLightIcons
                      ? Brightness.dark
                      : Brightness.light,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
