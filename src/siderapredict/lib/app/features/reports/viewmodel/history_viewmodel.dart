import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:siderapredict/app/features/inspection/viewmodel/inspection_viewmodel.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({required InspectionViewModel inspectionViewModel})
      : _inspectionViewModel = inspectionViewModel {
    _inspectionViewModel.addListener(notifyListeners);
  }

  final InspectionViewModel _inspectionViewModel;

  @override
  void dispose() {
    _inspectionViewModel.removeListener(notifyListeners);
    super.dispose();
  }

  List<MeasurementRecord> get history => _inspectionViewModel.history;
  bool get isLoading => _inspectionViewModel.isLoadingHistory;

  Future<void> loadHistory() => _inspectionViewModel.loadHistory();

  Future<File?> exportHistoryPdf() async {
    await Permission.storage.request();
    return await _inspectionViewModel.exportHistoryPdf();
  }

  Future<File?> exportHistoryExcel() async {
    await Permission.storage.request();
    return await _inspectionViewModel.exportHistoryExcel();
  }

  Future<File?> exportSingleRecordPdf(MeasurementRecord record) async {
    await Permission.storage.request();
    return await _inspectionViewModel.exportSingleRecordPdf(record);
  }

  Future<File?> exportSingleRecordExcel(MeasurementRecord record) async {
    await Permission.storage.request();
    return await _inspectionViewModel.exportSingleRecordExcel(record);
  }

  Future<bool> deleteRecord(String id) async {
    return await _inspectionViewModel.deleteRecordById(id);
  }

  MeasurementRecord? recordById(String id) => _inspectionViewModel.recordById(id);
}
