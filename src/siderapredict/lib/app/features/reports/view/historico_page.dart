import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:siderapredict/app/core/theme/theme.dart';
import 'package:siderapredict/app/core/widgets/zoomable_image_overlay.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_viewmodel.dart';
import 'package:siderapredict/app/features/reports/viewmodel/history_viewmodel.dart';

class HistoricoPage extends StatefulWidget {
  const HistoricoPage({super.key});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  final DateFormat _formatter = DateFormat('dd/MM/yyyy HH:mm');
  final DateFormat _dayFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryViewModel>().loadHistory();
    });
  }

  Future<void> _handleExportResult(
    File? file,
    String label,
    String recordName,
  ) async {
    if (!mounted) return;
    if (file == null) return;

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
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              OpenFilex.open(file.path);
            },
            style: FilledButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportHistoryPdf() async {
    final viewModel = context.read<HistoryViewModel>();
    if (viewModel.history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há medições para exportar.')),
      );
      return;
    }
    final file = await viewModel.exportHistoryPdf();
    await _handleExportResult(file, 'PDF Geral', 'Sidera Predict');
  }

  Future<void> _exportHistoryExcel() async {
    final viewModel = context.read<HistoryViewModel>();
    if (viewModel.history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há medições para exportar.')),
      );
      return;
    }
    final file = await viewModel.exportHistoryExcel();
    await _handleExportResult(file, 'Excel Geral', 'Sidera Predict');
  }

  Future<void> _exportSingleRecordPdf(MeasurementRecord record) async {
    final viewModel = context.read<HistoryViewModel>();
    final file = await viewModel.exportSingleRecordPdf(record);
    await _handleExportResult(file, 'PDF Individual', record.pieceName);
  }

  Future<void> _exportSingleRecordExcel(MeasurementRecord record) async {
    final viewModel = context.read<HistoryViewModel>();
    final file = await viewModel.exportSingleRecordExcel(record);
    await _handleExportResult(file, 'Excel Individual', record.pieceName);
  }

  String? _pieceOfDayLabel(MeasurementRecord record) {
    final pieceNumber = record.draft.pieceNumberOfDay;
    if (pieceNumber == null) return null;
    final day = _dayFormatter.format(record.createdAt.toLocal());
    return 'Peça $pieceNumber do dia $day';
  }

  Future<bool> _confirmDeleteRecord(MeasurementRecord record) async {
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
            style: FilledButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteRecord(MeasurementRecord record) async {
    final viewModel = context.read<HistoryViewModel>();
    final deleted = await viewModel.deleteRecord(record.id);
    if (!mounted) return;

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir.')),
      );
      await viewModel.loadHistory();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Peça "${record.pieceName}" removida.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryViewModel>(
      builder: (context, viewModel, _) {
        final records = viewModel.history;

        return Scaffold(
          backgroundColor: primaryColor,
          body: SafeArea(
            child: Container(
              color: backgroundLight,
              child: Column(
                children: [
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    color: primaryColor,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppLogo(height: 22),
                              SizedBox(width: 24),
                              Flexible(
                                child: Text(
                                  'HISTÓRICO',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    shadows: textShadows,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: Colors.white,
                          ),
                          onPressed: _exportHistoryPdf,
                          tooltip: 'Exportar PDF Geral',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.table_chart_outlined,
                            color: Colors.white,
                          ),
                          onPressed: _exportHistoryExcel,
                          tooltip: 'Exportar Excel Geral',
                        ),
                      ],
                    ),
                  ),

                  
                  Expanded(
                    child: RefreshIndicator(
                      color: primaryColor,
                      onRefresh: viewModel.loadHistory,
                      child: records.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.6,
                                  child: Center(
                                    child: viewModel.isLoading
                                        ? const CircularProgressIndicator(
                                            color: primaryColor,
                                          )
                                        : const Text(
                                            'Nenhuma medição registrada.',
                                            style: TextStyle(
                                              color: darkTextColor,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: records.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final record = records[index];
                                return Dismissible(
                                  key: ValueKey(record.id),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) =>
                                      _confirmDeleteRecord(record),
                                  onDismissed: (_) => _deleteRecord(record),
                                  background: Container(
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                  child: _HistoryCard(
                                    record: record,
                                    dateLabel: _formatter.format(
                                      record.createdAt.toLocal(),
                                    ),
                                    pieceOfDayLabel: _pieceOfDayLabel(record),
                                    onTap: () => _openDetails(record.id),
                                    onDownloadPdf: () =>
                                        _exportSingleRecordPdf(record),
                                    onDownloadExcel: () =>
                                        _exportSingleRecordExcel(record),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openDetails(String recordId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer<InspectionViewModel>(
          builder: (context, viewModel, _) {
            final record = viewModel.recordById(recordId);
            if (record == null) {
              return const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Registro não encontrado.'),
                ),
              );
            }

            final pieceOfDayLabel = _pieceOfDayLabel(record);

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              record.pieceName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: darkTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              '${record.primaryValueMm.toStringAsFixed(3)} mm',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _exportSingleRecordPdf(record),
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              color: primaryColor,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _exportSingleRecordExcel(record),
                            icon: const Icon(
                              Icons.table_chart_outlined,
                              color: primaryColor,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _formatter.format(record.createdAt.toLocal()),
                            style: const TextStyle(color: darkTextColor),
                          ),
                          if (pieceOfDayLabel != null)
                            Text(
                              pieceOfDayLabel,
                              style: const TextStyle(color: darkTextColor),
                            ),
                          _AiStatusBadge(status: record.aiReportStatus),
                        ],
                      ),
                      const Divider(height: 20),

                      
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HistoryRecordImage(
                                record: record,
                                height: 220,
                                preferDetailedImage: true,
                                enableZoom: true,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Resumo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: darkTextColor,
                                  shadows: textShadows,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Data: ${_formatter.format(record.createdAt.toLocal())}',
                              ),
                              Text(
                                'Número da peça do dia: ${record.draft.pieceNumberOfDay?.toString() ?? 'n/a'}',
                              ),
                              Text(
                                'Largura geral: ${record.draft.widthMm.toStringAsFixed(3)} mm',
                              ),
                              Text(
                                'Altura geral: ${record.draft.heightMm.toStringAsFixed(3)} mm',
                              ),
                              Text(
                                'Perímetro: ${record.draft.perimeterMm.toStringAsFixed(3)} mm',
                              ),
                              Text(
                                'Área: ${record.draft.areaMm2.toStringAsFixed(3)} mm²',
                              ),
                              Text(
                                'Escala: ${record.draft.scaleMicronsPerPx?.toStringAsFixed(3) ?? '-'} µm/px',
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Segmentos medidos',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: darkTextColor,
                                  shadows: textShadows,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (record.draft.segments.isEmpty)
                                const Text(
                                  'Sem segmentos classificados nesta medição.',
                                ),
                              for (final segment in record.draft.segments)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '${segment.label}: ${segment.displayValue}',
                                  ),
                                ),
                              const SizedBox(height: 16),
                              const Text(
                                'Relatório IA',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: darkTextColor,
                                  shadows: textShadows,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (record.aiReport.trim().isEmpty &&
                                  record.isAiReportStreaming)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'A IA já está gerando o relatório. O texto vai aparecer aqui em tempo real.',
                                  ),
                                )
                              else
                                MarkdownBody(
                                  data: record.aiReport.trim().isEmpty
                                      ? 'Relatório indisponível no momento.'
                                      : record.aiReport,
                                  selectable: true,
                                  styleSheet:
                                      MarkdownStyleSheet.fromTheme(
                                        Theme.of(context),
                                      ).copyWith(
                                        p: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(height: 1.45),
                                        h1: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                        h2: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                        h3: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}



class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.record,
    required this.dateLabel,
    required this.pieceOfDayLabel,
    required this.onTap,
    required this.onDownloadPdf,
    required this.onDownloadExcel,
  });

  final MeasurementRecord record;
  final String dateLabel;
  final String? pieceOfDayLabel;
  final VoidCallback onTap;
  final VoidCallback onDownloadPdf;
  final VoidCallback onDownloadExcel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: whiteColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: subtleShadows,
        ),
        child: Row(
          children: [
            _HistoryRecordImage(record: record, width: 52, height: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.pieceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: darkTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF617886),
                      fontSize: 13,
                    ),
                  ),
                  if (pieceOfDayLabel != null)
                    Text(
                      pieceOfDayLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF617886),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (record.isAiReportStreaming) ...[
                    const SizedBox(height: 6),
                    _AiStatusBadge(status: record.aiReportStatus),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${record.primaryValueMm.toStringAsFixed(3)} mm',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 20,
                        color: primaryColor,
                      ),
                      onPressed: onDownloadPdf,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'PDF',
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(
                        Icons.table_chart_outlined,
                        size: 20,
                        color: primaryColor,
                      ),
                      onPressed: onDownloadExcel,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Excel',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class _HistoryRecordImage extends StatefulWidget {
  const _HistoryRecordImage({
    required this.record,
    this.width,
    this.height = 52,
    this.preferDetailedImage = false,
    this.enableZoom = false,
  });

  final MeasurementRecord record;
  final double? width;
  final double height;
  final bool preferDetailedImage;
  final bool enableZoom;

  @override
  State<_HistoryRecordImage> createState() => _HistoryRecordImageState();
}

class _HistoryRecordImageState extends State<_HistoryRecordImage> {
  MemoryImage? _imageProvider;
  String? _lastImageBase64;

  @override
  void initState() {
    super.initState();
    _syncImageProvider();
  }

  @override
  void didUpdateWidget(covariant _HistoryRecordImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncImageProvider();
  }

  void _syncImageProvider() {
    final imageBase64 = widget.preferDetailedImage
        ? (widget.record.photoBase64 ?? widget.record.thumbnailBase64)
        : (widget.record.thumbnailBase64 ?? widget.record.photoBase64);

    if (imageBase64 == _lastImageBase64) return;

    _lastImageBase64 = imageBase64;
    final bytes = imageBase64 == null ? null : _decodeBase64(imageBase64);
    _imageProvider = bytes == null ? null : MemoryImage(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: _imageProvider == null
          ? const Icon(Icons.straighten, color: primaryColor)
          : Image(
              image: _imageProvider!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined, color: primaryColor),
            ),
    );

    if (_imageProvider == null || !widget.enableZoom) return child;

    return GestureDetector(
      onTap: () =>
          ZoomableImageOverlay.show(context, imageProvider: _imageProvider!),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.zoom_in, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Uint8List? _decodeBase64(String raw) {
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}



class _AiStatusBadge extends StatelessWidget {
  const _AiStatusBadge({required this.status});

  final AiReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AiReportStatus.pending => ('IA na fila', const Color(0xFF7F8C8D)),
      AiReportStatus.generating => ('IA gerando', paletteRed),
      AiReportStatus.completed => ('IA concluída', confirmGreen),
      AiReportStatus.failed => ('IA com fallback', primaryColor),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
