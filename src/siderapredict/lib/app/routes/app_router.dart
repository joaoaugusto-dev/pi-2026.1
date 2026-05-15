import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/inspection/view/processing_page.dart';
import 'package:siderapredict/app/features/inspection/view/scanner_page.dart';
import 'package:siderapredict/app/features/inspection/view/validation_page.dart';
import 'package:siderapredict/app/features/menu/view/main_menu_page.dart';
import 'package:siderapredict/app/features/reports/view/history_page.dart';
import 'package:siderapredict/app/features/splash/view/splash_page.dart';
import 'package:siderapredict/app/features/settings/view/settings_page.dart';
import 'package:siderapredict/app/features/auth/view/login_page.dart';
import 'package:siderapredict/app/features/auth/view/signup_page.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/features/auth/viewmodel/login_view_model.dart';
import 'package:siderapredict/app/features/auth/viewmodel/signup_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/scanner_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/processing_view_model.dart';
import 'package:siderapredict/app/features/reports/viewmodel/history_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/validation_view_model.dart';
import 'package:siderapredict/app/features/menu/viewmodel/main_menu_view_model.dart';
import 'package:siderapredict/app/features/splash/viewmodel/splash_view_model.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

class CameraArgs {
  final List<CameraDescription> cameras;
  const CameraArgs({required this.cameras});
}

class ProcessingArgs {
  final String imagePath;
  final MeasurementSource source;
  const ProcessingArgs({
    required this.imagePath,
    this.source = MeasurementSource.camera,
  });
}

class ValidationArgs {
  final MeasurementDraft draft;
  const ValidationArgs({required this.draft});
}

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<SplashViewModel>(
            lazy: false,
            create: (context) => SplashViewModel()..scheduleNavigation(context),
            child: const SplashPage(),
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

      case AppRoutes.camera:
        final args = settings.arguments;
        if (args is! CameraArgs) {
          return _errorRoute(settings, 'Argumentos inválidos para câmera.');
        }
        return MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<ScannerViewModel>(
            create: (_) => ScannerViewModel(cameras: args.cameras)..init(),
            child: const ScannerPage(),
          ),
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

      case AppRoutes.history:
        return MaterialPageRoute<void>(
          builder: (_) =>
              ChangeNotifierProxyProvider<
                InspectionViewModel,
                HistoryViewModel
              >(
                create: (context) => HistoryViewModel(
                  inspectionViewModel: context.read<InspectionViewModel>(),
                ),
                update: (context, inspection, previous) => previous!,
                child: const HistoryPage(),
              ),
          settings: settings,
        );

      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );

      default:
        return _errorRoute(settings, 'Rota não encontrada: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(RouteSettings settings, String message) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Erro de navegação')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
