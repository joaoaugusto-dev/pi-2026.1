import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'package:siderapredict/app/core/widgets/zoomable_image_overlay.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_view_model.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/core/theme/app_theme.dart';

typedef HistoryDetailsBuilder = Widget Function(BuildContext context);

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({required InspectionViewModel inspectionViewModel})
    : _inspectionViewModel = inspectionViewModel {
    _inspectionViewModel.addListener(notifyListeners);
  }

  final InspectionViewModel _inspectionViewModel;
  final DateFormat _formatter = DateFormat('dd/MM/yyyy HH:mm');
  final DateFormat _dayFormatter = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _inspectionViewModel.removeListener(notifyListeners);
    super.dispose();
  }

  List<MeasurementRecord> get history => _inspectionViewModel.history;
  bool get isLoading => _inspectionViewModel.isLoadingHistory;
  String get realtimeScopeKey =>
      _inspectionViewModel.currentUserId?.trim().isNotEmpty == true
      ? _inspectionViewModel.currentUserId!.trim()
      : 'anonymous';

  Future<void> loadHistory() => _inspectionViewModel.loadHistory();

  Future<void> onReady() => loadHistory();

  String dateLabel(MeasurementRecord record) {
    return _formatter.format(record.createdAt.toLocal());
  }

  String? pieceOfDayLabel(MeasurementRecord record) {
    final pieceNumber = record.draft.pieceNumberOfDay;
    if (pieceNumber == null) return null;
    final day = _dayFormatter.format(record.createdAt.toLocal());
    return 'Peça $pieceNumber do dia $day';
  }

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

  bool canDeleteRecord(MeasurementRecord record) =>
      _inspectionViewModel.canDeleteRecord(record);

  bool shouldAnimateRealtimeCue(MeasurementRecord record) =>
      !_inspectionViewModel.isOwnedByCurrentUser(record);

  MeasurementRecord? recordById(String id) =>
      _inspectionViewModel.recordById(id);

  Future<Uint8List?> imageBytesFor(
    MeasurementRecord record, {
    bool preferDetailedImage = false,
  }) => _inspectionViewModel.imageBytesFor(
    record,
    preferDetailedImage: preferDetailedImage,
  );

  Future<ImageProvider<Object>?> recordImageProvider(
    MeasurementRecord record, {
    bool preferDetailedImage = false,
  }) async {
    final bytes = await imageBytesFor(
      record,
      preferDetailedImage: preferDetailedImage,
    );
    return bytes == null ? null : MemoryImage(bytes);
  }

  VoidCallback exportHistoryPdfAction(BuildContext context) {
    return () => onExportHistoryPdfPressed(context);
  }

  VoidCallback exportHistoryExcelAction(BuildContext context) {
    return () => onExportHistoryExcelPressed(context);
  }

  VoidCallback exportSingleRecordPdfAction(
    BuildContext context,
    MeasurementRecord record,
  ) {
    return () => onExportSingleRecordPdfPressed(context, record);
  }

  VoidCallback exportSingleRecordExcelAction(
    BuildContext context,
    MeasurementRecord record,
  ) {
    return () => onExportSingleRecordExcelPressed(context, record);
  }

  Future<bool> Function(DismissDirection) confirmDeleteRecordAction(
    BuildContext context,
    MeasurementRecord record,
  ) {
    return (_) => onConfirmDeleteRecord(context, record);
  }

  DismissDirectionCallback deleteRecordAction(
    BuildContext context,
    MeasurementRecord record,
  ) {
    return (_) => unawaited(onDeleteRecord(context, record));
  }

  VoidCallback openDetailsAction(
    BuildContext context,
    HistoryDetailsBuilder builder,
  ) {
    return () => onOpenDetailsPressed(context, builder);
  }

  VoidCallback showImageAction(
    BuildContext context,
    ImageProvider<Object> imageProvider,
  ) {
    return () =>
        ZoomableImageOverlay.show(context, imageProvider: imageProvider);
  }

  Future<void> onExportHistoryPdfPressed(BuildContext context) async {
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há medições para exportar.')),
      );
      return;
    }

    final file = await exportHistoryPdf();
    if (!context.mounted) return;
    await _handleExportResult(context, file, 'PDF Geral', 'Sidera Predict');
  }

  Future<void> onExportHistoryExcelPressed(BuildContext context) async {
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há medições para exportar.')),
      );
      return;
    }

    final file = await exportHistoryExcel();
    if (!context.mounted) return;
    await _handleExportResult(context, file, 'Excel Geral', 'Sidera Predict');
  }

  Future<void> onExportSingleRecordPdfPressed(
    BuildContext context,
    MeasurementRecord record,
  ) async {
    final file = await exportSingleRecordPdf(record);
    if (!context.mounted) return;
    await _handleExportResult(
      context,
      file,
      'PDF Individual',
      record.pieceName,
    );
  }

  Future<void> onExportSingleRecordExcelPressed(
    BuildContext context,
    MeasurementRecord record,
  ) async {
    final file = await exportSingleRecordExcel(record);
    if (!context.mounted) return;
    await _handleExportResult(
      context,
      file,
      'Excel Individual',
      record.pieceName,
    );
  }

  Future<bool> onConfirmDeleteRecord(
    BuildContext context,
    MeasurementRecord record,
  ) async {
    if (!canDeleteRecord(record)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Você não tem permissão para excluir esta medição.'),
          backgroundColor: paletteRed,
        ),
      );
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir peça'),
        content: Text('Deseja remover "${record.pieceName}" do histórico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> onDeleteRecord(
    BuildContext context,
    MeasurementRecord record,
  ) async {
    final deleted = await deleteRecord(record.id);
    if (!context.mounted) return;

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir.')),
      );
      await loadHistory();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Peça "${record.pieceName}" removida.')),
    );
  }

  void onOpenDetailsPressed(
    BuildContext context,
    HistoryDetailsBuilder builder,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: builder,
    );
  }

  Future<void> _handleExportResult(
    BuildContext context,
    File? file,
    String label,
    String recordName,
  ) async {
    if (file == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Download concluído'),
        content: const Text(
          'O arquivo foi exportado com sucesso.\n\n'
          'Você também pode abrir para visualizar agora ou compartilhar.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              SharePlus.instance.share(
                ShareParams(
                  files: <XFile>[XFile(file.path)],
                  text: 'Relatório $label - $recordName',
                ),
              );
            },
            child: Text(
              'Compartilhar',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              OpenFilex.open(file.path);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }
}
