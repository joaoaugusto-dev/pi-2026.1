import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/reports/viewmodel/history_view_model.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryViewModel>(
      builder: (context, viewModel, _) {
        final records = viewModel.history;

        return Scaffold(
          appBar: buildAppBar(
            context: context,
            title: 'Histórico',
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: viewModel.exportHistoryPdfAction(context),
                tooltip: 'Exportar PDF Geral',
              ),
              IconButton(
                icon: const Icon(Icons.table_chart_outlined),
                onPressed: viewModel.exportHistoryExcelAction(context),
                tooltip: 'Exportar Excel Geral',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: Theme.of(context).primaryColor,
                    onRefresh: viewModel.loadHistory,
                    child: records.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.6,
                                child: Center(
                                  child: viewModel.isLoading
                                      ? CircularProgressIndicator(
                                          color: Theme.of(context).primaryColor,
                                        )
                                      : Text(
                                          'Nenhuma medição registrada.',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
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
                                confirmDismiss: viewModel
                                    .confirmDeleteRecordAction(context, record),
                                onDismissed: viewModel.deleteRecordAction(
                                  context,
                                  record,
                                ),
                                background: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
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
                                  dateLabel: viewModel.dateLabel(record),
                                  pieceOfDayLabel: viewModel.pieceOfDayLabel(
                                    record,
                                  ),
                                  onTap: viewModel.openDetailsAction(
                                    context,
                                    (sheetContext) =>
                                        ChangeNotifierProvider<
                                          HistoryViewModel
                                        >.value(
                                          value: viewModel,
                                          child: _buildDetailsSheet(
                                            sheetContext,
                                            record.id,
                                          ),
                                        ),
                                  ),
                                  onDownloadPdf: viewModel
                                      .exportSingleRecordPdfAction(
                                        context,
                                        record,
                                      ),
                                  onDownloadExcel: viewModel
                                      .exportSingleRecordExcelAction(
                                        context,
                                        record,
                                      ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsSheet(BuildContext context, String recordId) {
    return Consumer<HistoryViewModel>(
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
        final pieceOfDayLabel = viewModel.pieceOfDayLabel(record);
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          record.pieceName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${record.primaryValueMm.toStringAsFixed(3)} mm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _ConformityBadge(
                            status: record.conformityStatus,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: viewModel.exportSingleRecordPdfAction(
                              context,
                              record,
                            ),
                            icon: Icon(
                              Icons.picture_as_pdf_outlined,
                              color: Theme.of(context).primaryColor,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: viewModel.exportSingleRecordExcelAction(
                              context,
                              record,
                            ),
                            icon: Icon(
                              Icons.table_chart_outlined,
                              color: Theme.of(context).primaryColor,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
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
                        viewModel.dateLabel(record),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (pieceOfDayLabel != null)
                        Text(
                          pieceOfDayLabel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      _AiStatusBadge(status: record.aiReportStatus),
                      _ConformityBadge(status: record.conformityStatus),
                    ],
                  ),
                  if (record.conformityStatus == ConformityStatus.nok) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: paletteRed.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: paletteRed.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: paletteRed,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'MOTIVO DA REPROVAÇÃO',
                                style: TextStyle(
                                  color: paletteRed,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record.nonConformityReason ??
                                'Motivo não especificado',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (record.nonConformityObservation?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 8),
                            Text(
                              record.nonConformityObservation!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
                          Text(
                            'Resumo',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                              shadows: textShadows,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Responsável: ${record.responsavel ?? 'n/a'}'),
                          Text('Data: ${viewModel.dateLabel(record)}'),
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
                          const SizedBox(height: 16),
                          Text(
                            'Segmentos medidos',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
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
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${segment.label}: ${segment.displayValue}',
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Relatório IA',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
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
                                    p: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(height: 1.45),
                                    h1: Theme.of(context).textTheme.titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                    h2: Theme.of(context).textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                    h3: Theme.of(context).textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: subtleShadows,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _HistoryRecordImage(record: record, width: 48, height: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    record.pieceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$dateLabel • ${record.responsavel ?? 'n/a'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF617886),
                      fontSize: 12,
                    ),
                  ),
                  if (pieceOfDayLabel != null)
                    Text(
                      pieceOfDayLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF617886),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (record.isAiReportStreaming) ...[
                    const SizedBox(height: 4),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                _ConformityBadge(
                  status: record.conformityStatus,
                  compact: true,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: onDownloadPdf,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'PDF',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.table_chart_outlined,
                        size: 18,
                        color: Theme.of(context).primaryColor,
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

class _HistoryRecordImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final viewModel = context.read<HistoryViewModel>();
    final imageProvider = viewModel.recordImageProvider(
      record,
      preferDetailedImage: preferDetailedImage,
    );
    final child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageProvider == null
          ? Icon(Icons.straighten, color: Theme.of(context).primaryColor)
          : Image(
              image: imageProvider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).primaryColor,
              ),
            ),
    );

    if (imageProvider == null || !enableZoom) return child;

    return GestureDetector(
      onTap: viewModel.showImageAction(context, imageProvider),
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
}

class _AiStatusBadge extends StatelessWidget {
  const _AiStatusBadge({required this.status});

  final AiReportStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      AiReportStatus.pending => ('IA na fila', const Color(0xFF7F8C8D)),
      AiReportStatus.generating => ('IA gerando', theme.colorScheme.error),
      AiReportStatus.completed => ('IA concluída', confirmGreen),
      AiReportStatus.failed => ('IA com fallback', theme.primaryColor),
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

class _ConformityBadge extends StatelessWidget {
  const _ConformityBadge({required this.status, this.compact = false});

  final ConformityStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOk = status == ConformityStatus.ok;
    final color = isOk
        ? confirmGreen
        : (isDark ? theme.colorScheme.primary : theme.colorScheme.error);
    final label = isOk ? 'CONFORME' : 'NÃO CONFORME';
    final icon = isOk ? Icons.check_circle : Icons.cancel;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
