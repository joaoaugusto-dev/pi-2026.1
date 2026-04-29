import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/routes/app_pages.dart';
import 'package:siderapredict/app/routes/app_routes.dart';
import 'package:siderapredict/app/config/app_config.dart';
import 'package:siderapredict/app/core/services/firestore_service.dart';
import 'package:siderapredict/app/core/services/local_history_store.dart';
import 'package:siderapredict/app/core/services/measurement_service.dart';
import 'package:siderapredict/app/core/services/ollama_report_service.dart';
import 'package:siderapredict/app/core/services/report_export_service.dart';
import 'package:siderapredict/app/core/theme/theme.dart';
import 'package:siderapredict/app/features/inspection/data/measurement_repository.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_viewmodel.dart';

final statusBarStyle = SystemUiOverlayStyle(
  statusBarColor: primaryColor,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

class AppWidget extends StatelessWidget {
  AppWidget({super.key, required List<CameraDescription> cameras})
    : _viewModel = _buildViewModel(cameras);

  final InspectionViewModel _viewModel;

  static InspectionViewModel _buildViewModel(List<CameraDescription> cameras) {
    final firestore = FirestoreService(
      collectionName: AppConfig.firestoreCollection,
    );

    final repository = MeasurementRepository(
      firestoreService: firestore,
      localStore: LocalHistoryStore(),
      ollamaService: OllamaReportService(
        baseUrl: AppConfig.ollamaBaseUrl,
        model: AppConfig.ollamaModel,
      ),
      exportService: ReportExportService(),
    );

    return InspectionViewModel(
      measurementService: MeasurementService(),
      repository: repository,
      cameras: cameras,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<InspectionViewModel>.value(value: _viewModel),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sidera Predict',
        theme: ThemeData(
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            systemOverlayStyle: statusBarStyle,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        builder: (context, child) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: statusBarStyle,
            child: child ?? const SizedBox.shrink(),
          );
        },
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppPages.onGenerateRoute,
      ),
    );
  }
}
