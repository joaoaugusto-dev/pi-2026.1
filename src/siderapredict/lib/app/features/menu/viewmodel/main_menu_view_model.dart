import 'dart:async';

import 'package:flutter/material.dart';

import 'package:siderapredict/app/config/app_config.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_view_model.dart';
import 'package:siderapredict/app/routes/app_router.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

class MainMenuViewModel extends ChangeNotifier {
  MainMenuViewModel({
    required InspectionViewModel inspectionViewModel,
    required AuthViewModel authViewModel,
  }) : _inspectionViewModel = inspectionViewModel,
       _authViewModel = authViewModel {
    _authViewModel.addListener(notifyListeners);
    onReady();
  }

  final InspectionViewModel _inspectionViewModel;
  final AuthViewModel _authViewModel;

  bool _initialized = false;

  String get fullName => _authViewModel.userName ?? 'Funcionário';
  String get firstName => fullName.split(' ').first;
  List<String> get configIssues => AppConfig.validationMessages;

  void onReady() {
    if (_initialized) return;
    _initialized = true;
    unawaited(_authViewModel.fetchProfile());
  }

  VoidCallback newMeasurementAction(BuildContext context) {
    return () => onNewMeasurementPressed(context);
  }

  VoidCallback historyAction(BuildContext context) {
    return () => onHistoryPressed(context);
  }

  VoidCallback settingsAction(BuildContext context) {
    return () => onSettingsPressed(context);
  }

  void onNewMeasurementPressed(BuildContext context) {
    _inspectionViewModel.clearDraft();
    Navigator.of(context).pushNamed(
      AppRoutes.camera,
      arguments: CameraArgs(cameras: _inspectionViewModel.availableCameras),
    );
  }

  void onHistoryPressed(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.history);
  }

  void onSettingsPressed(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.settings);
  }

  @override
  void dispose() {
    _authViewModel.removeListener(notifyListeners);
    super.dispose();
  }
}
