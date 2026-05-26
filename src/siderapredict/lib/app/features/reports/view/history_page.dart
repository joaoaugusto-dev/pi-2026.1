import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/reports/viewmodel/history_view_model.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<HistoryViewModel>().onReady());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryViewModel>(
      builder: (context, viewModel, _) {
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
                    child: _RealtimeHistoryList(
                      key: ValueKey(viewModel.realtimeScopeKey),
                      viewModel: viewModel,
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

  static Widget _buildDetailsSheet(BuildContext context, String recordId) {
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

enum _RealtimeHistoryCue { inserted, updated, removed }

class _RealtimeHistoryList extends StatefulWidget {
  const _RealtimeHistoryList({super.key, required this.viewModel});

  final HistoryViewModel viewModel;

  @override
  State<_RealtimeHistoryList> createState() => _RealtimeHistoryListState();
}

class _RealtimeHistoryListState extends State<_RealtimeHistoryList> {
  static const Duration _insertDuration = Duration(milliseconds: 360);
  static const Duration _removeDuration = Duration(milliseconds: 280);
  static const Duration _cueDuration = Duration(milliseconds: 3000);
  static const Duration _emptyStateDuration = Duration(milliseconds: 220);
  static const Duration _cueReplayCooldown = Duration(milliseconds: 5000);

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<MeasurementRecord> _items = <MeasurementRecord>[];
  final Map<String, String> _signatures = <String, String>{};
  final Map<String, int> _cueTokens = <String, int>{};
  final Map<String, _RealtimeHistoryCue> _activeCues =
      <String, _RealtimeHistoryCue>{};
  final Map<String, Timer> _cueTimers = <String, Timer>{};
  final Map<String, DateTime> _cueStartedAt = <String, DateTime>{};

  bool _hydratedInitialSnapshot = false;
  int _pendingRemovals = 0;

  @override
  void initState() {
    super.initState();
    _replaceItemsWithoutAnimation(widget.viewModel.history);
    _hydratedInitialSnapshot = _items.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant _RealtimeHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextRecords = widget.viewModel.history;

    if (!_hydratedInitialSnapshot) {
      if (widget.viewModel.isLoading && nextRecords.isEmpty) {
        return;
      }
      _replaceItemsWithoutAnimation(nextRecords);
      _hydratedInitialSnapshot = true;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _syncWith(nextRecords);
  }

  @override
  void dispose() {
    for (final timer in _cueTimers.values) {
      timer.cancel();
    }
    _cueTimers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showEmptyState = _items.isEmpty && _pendingRemovals == 0;
    final showLoadingState =
        widget.viewModel.isLoading || !_hydratedInitialSnapshot;

    return Stack(
      children: [
        AnimatedList(
          key: _listKey,
          initialItemCount: _items.length,
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          itemBuilder: (context, index, animation) {
            final record = _items[index];
            return _buildAnimatedTile(
              context,
              record: record,
              animation: animation,
            );
          },
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !showEmptyState,
            child: AnimatedOpacity(
              opacity: showEmptyState ? 1 : 0,
              duration: _emptyStateDuration,
              curve: Curves.easeOutCubic,
              child: Center(
                child: showLoadingState
                    ? CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      )
                    : Text(
                        'Nenhuma medição registrada.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _replaceItemsWithoutAnimation(List<MeasurementRecord> records) {
    _items
      ..clear()
      ..addAll(records);
    _signatures
      ..clear()
      ..addEntries(
        records.map((record) => MapEntry(record.id, _signatureFor(record))),
      );
  }

  void _syncWith(List<MeasurementRecord> nextRecords) {
    final nextById = {for (final record in nextRecords) record.id: record};
    var changed = false;

    for (var index = _items.length - 1; index >= 0; index--) {
      final current = _items[index];
      if (nextById.containsKey(current.id)) {
        continue;
      }

      final removed = _items.removeAt(index);
      _signatures.remove(removed.id);
      _clearCue(removed.id);
      _pendingRemovals++;
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildAnimatedTile(
          context,
          record: removed,
          animation: animation,
          forcedCue: _RealtimeHistoryCue.removed,
        ),
        duration: _removeDuration,
      );
      Future<void>.delayed(_removeDuration, () {
        if (!mounted) return;
        setState(() {
          _pendingRemovals = math.max(0, _pendingRemovals - 1);
        });
      });
      changed = true;
    }

    for (var targetIndex = 0; targetIndex < nextRecords.length; targetIndex++) {
      final next = nextRecords[targetIndex];
      final existingIndex = _items.indexWhere((item) => item.id == next.id);

      if (existingIndex == -1) {
        _items.insert(targetIndex, next);
        _signatures[next.id] = _signatureFor(next);
        if (_shouldCue(next)) {
          _activateCue(next.id, _RealtimeHistoryCue.inserted);
        }
        _listKey.currentState?.insertItem(
          targetIndex,
          duration: _insertDuration,
        );
        changed = true;
        continue;
      }

      if (existingIndex != targetIndex) {
        final moved = _items.removeAt(existingIndex);
        _items.insert(targetIndex, moved);
        changed = true;
      }

      final previousSignature = _signatures[next.id];
      final nextSignature = _signatureFor(next);
      final hasChanged = previousSignature != nextSignature;

      _items[targetIndex] = next;
      _signatures[next.id] = nextSignature;

      if (hasChanged && _shouldCue(next)) {
        _activateCue(next.id, _RealtimeHistoryCue.updated);
        changed = true;
      } else if (hasChanged) {
        changed = true;
      }
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  Widget _buildAnimatedTile(
    BuildContext context, {
    required MeasurementRecord record,
    required Animation<double> animation,
    _RealtimeHistoryCue? forcedCue,
  }) {
    final cue = forcedCue ?? _activeCues[record.id];
    final cueToken = _cueTokens[record.id] ?? 0;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.045),
            end: Offset.zero,
          ).animate(curved),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildCueFrame(
              context,
              record: record,
              cue: cue,
              cueToken: cueToken,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCueFrame(
    BuildContext context, {
    required MeasurementRecord record,
    required _RealtimeHistoryCue? cue,
    required int cueToken,
  }) {
    final theme = Theme.of(context);
    final neutralShadowColor = theme.brightness == Brightness.dark
        ? Colors.black
        : theme.colorScheme.shadow;
    final card = _buildRecordTile(context, record);

    if (cue == null) {
      return card;
    }

    if (cue != _RealtimeHistoryCue.removed) {
      return _buildRealtimeRevealCue(
        context,
        card: card,
        record: record,
        cueToken: cueToken,
      );
    }

    final activeCue = cue;

    return TweenAnimationBuilder<double>(
      key: ValueKey('history-cue-${record.id}-$cueToken'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 820),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final eased = Curves.easeOutCubic.transform(value);
        final pulse = math.sin(eased * math.pi);
        final glowAlpha = switch (activeCue) {
          _RealtimeHistoryCue.inserted => 0.10 + (pulse * 0.05),
          _RealtimeHistoryCue.updated => 0.08 + (pulse * 0.04),
          _RealtimeHistoryCue.removed => 0.09 + (pulse * 0.05),
        };
        final scale = activeCue == _RealtimeHistoryCue.removed
            ? 1.0
            : 1 + (pulse * 0.004);

        return Transform.scale(
          scale: scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: neutralShadowColor.withValues(alpha: glowAlpha),
                      blurRadius: 16 + (pulse * 8),
                      offset: Offset(0, 8 - (pulse * 2)),
                      spreadRadius: pulse * 0.15,
                    ),
                  ],
                ),
                child: child,
              ),
            ],
          ),
        );
      },
      child: card,
    );
  }

  Widget _buildRealtimeRevealCue(
    BuildContext context, {
    required Widget card,
    required MeasurementRecord record,
    required int cueToken,
  }) {
    final authorName = record.responsavel?.trim();
    final displayName = authorName == null || authorName.isEmpty
        ? 'Operador remoto'
        : authorName;

    return TweenAnimationBuilder<double>(
      key: ValueKey('history-reveal-${record.id}-$cueToken-$displayName'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: _cueDuration,
      curve: Curves.linear,
      child: card,
      builder: (context, value, child) {
        const coverInEnd = 0.15;
        const typingStart = 0.08;
        const typingEnd = 0.45;
        const holdEnd = 0.82;
        const burstStart = 0.81;
        const burstEnd = 0.94;
        const revealStart = 0.93;

        final coverInProgress = (value / coverInEnd).clamp(0.0, 1.0);
        final typingProgress =
            ((value - typingStart) / (typingEnd - typingStart)).clamp(0.0, 1.0);
        final holdProgress = ((value - typingEnd) / (holdEnd - typingEnd))
            .clamp(0.0, 1.0);
        final burstProgress = ((value - burstStart) / (burstEnd - burstStart))
            .clamp(0.0, 1.0);
        final revealProgress = ((value - revealStart) / (1 - revealStart))
            .clamp(0.0, 1.0);

        final overlayFadeOut = value < burstStart
            ? 0.0
            : Curves.easeOutQuart.transform(burstProgress);
        final overlayOpacity =
            Curves.easeOutCubic.transform(coverInProgress) *
            (1 - overlayFadeOut);
        final holdBreath = math.sin(holdProgress * math.pi);
        final overlayScale = value < burstStart
            ? 0.982 + (Curves.easeOutCubic.transform(coverInProgress) * 0.018)
            : 1 + (Curves.easeOutBack.transform(burstProgress) * 0.10);
        final overlayLift =
            ((1 - Curves.easeOutCubic.transform(coverInProgress)) * 16) -
            (holdBreath * 2.5);
        final cardOpacity = value < revealStart
            ? 0.0
            : Curves.easeOutQuart.transform(revealProgress);
        final cardScale = value < revealStart
            ? 0.974
            : 0.974 + (Curves.easeOutCubic.transform(revealProgress) * 0.026);
        final cardLift = value < revealStart
            ? 8.0
            : (1 - Curves.easeOutQuart.transform(revealProgress)) * 8;
        final showParticles = value >= burstStart && value <= 0.985;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(0, cardLift),
              child: Opacity(
                opacity: cardOpacity,
                child: Transform.scale(
                  scale: cardScale,
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
            ),
            if (overlayOpacity > 0.001)
              Positioned.fill(
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(0, overlayLift),
                    child: Transform.scale(
                      scale: overlayScale,
                      child: Opacity(
                        opacity: overlayOpacity,
                        child: _RealtimeRedCover(
                          title: displayName,
                          coverProgress: Curves.easeOutCubic.transform(
                            coverInProgress,
                          ),
                          typingProgress: Curves.easeInOutCubic.transform(
                            typingProgress,
                          ),
                          holdProgress: Curves.easeInOutSine.transform(
                            holdProgress,
                          ),
                          burstProgress: Curves.easeOutCubic.transform(
                            burstProgress,
                          ),
                          showCaret: value >= typingStart && value < typingEnd,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showParticles)
              Positioned.fill(
                child: IgnorePointer(
                  child: _BurstParticles(
                    progress: Curves.easeOutCubic.transform(burstProgress),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRecordTile(BuildContext context, MeasurementRecord record) {
    final card = _HistoryCard(
      record: record,
      dateLabel: widget.viewModel.dateLabel(record),
      pieceOfDayLabel: widget.viewModel.pieceOfDayLabel(record),
      onTap: widget.viewModel.openDetailsAction(
        context,
        (sheetContext) => ChangeNotifierProvider<HistoryViewModel>.value(
          value: widget.viewModel,
          child: _HistoryPageState._buildDetailsSheet(sheetContext, record.id),
        ),
      ),
      onDownloadPdf: widget.viewModel.exportSingleRecordPdfAction(
        context,
        record,
      ),
      onDownloadExcel: widget.viewModel.exportSingleRecordExcelAction(
        context,
        record,
      ),
    );

    final canDelete = widget.viewModel.canDeleteRecord(record);
    return Dismissible(
      key: ValueKey('history-dismiss-${record.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: widget.viewModel.confirmDeleteRecordAction(
        context,
        record,
      ),
      onDismissed: (_) => _handleLocalDismiss(context, record),
      background: Container(
        decoration: BoxDecoration(
          color: canDelete ? Theme.of(context).primaryColor : Colors.grey,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Icon(
          canDelete ? Icons.delete_outline : Icons.lock_outline,
          color: Colors.white,
          size: 26,
        ),
      ),
      child: card,
    );
  }

  Future<void> _handleLocalDismiss(
    BuildContext context,
    MeasurementRecord record,
  ) async {
    final index = _items.indexWhere((item) => item.id == record.id);
    if (index != -1) {
      final removed = _items.removeAt(index);
      _signatures.remove(removed.id);
      _clearCue(removed.id);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => const SizedBox.shrink(),
        duration: Duration.zero,
      );
      if (mounted) {
        setState(() {});
      }
    }

    await widget.viewModel.onDeleteRecord(context, record);
  }

  bool _shouldCue(MeasurementRecord record) =>
      widget.viewModel.shouldAnimateRealtimeCue(record);

  String _signatureFor(MeasurementRecord record) => jsonEncode(record.toJson());

  void _activateCue(String recordId, _RealtimeHistoryCue cue) {
    if (cue != _RealtimeHistoryCue.removed) {
      if (_activeCues.containsKey(recordId)) {
        return;
      }

      final lastStartedAt = _cueStartedAt[recordId];
      final now = DateTime.now();
      if (lastStartedAt != null &&
          now.difference(lastStartedAt) < _cueReplayCooldown) {
        return;
      }
      _cueStartedAt[recordId] = now;
    }

    _cueTokens[recordId] = (_cueTokens[recordId] ?? 0) + 1;
    _activeCues[recordId] = cue;
    _cueTimers.remove(recordId)?.cancel();
    _cueTimers[recordId] = Timer(_cueDuration, () {
      if (!mounted) return;
      setState(() {
        _activeCues.remove(recordId);
        _cueTimers.remove(recordId);
      });
    });
  }

  void _clearCue(String recordId) {
    _cueTimers.remove(recordId)?.cancel();
    _activeCues.remove(recordId);
    _cueTokens.remove(recordId);
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
    return FutureBuilder<ImageProvider<Object>?>(
      future: viewModel.recordImageProvider(
        record,
        preferDetailedImage: preferDetailedImage,
      ),
      builder: (context, snapshot) {
        final imageProvider = snapshot.data;
        final child = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageProvider == null
              ? snapshot.connectionState == ConnectionState.waiting
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.straighten,
                        color: Theme.of(context).primaryColor,
                      )
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
                  child: const Icon(
                    Icons.zoom_in,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RealtimeRedCover extends StatelessWidget {
  const _RealtimeRedCover({
    required this.title,
    required this.coverProgress,
    required this.typingProgress,
    required this.holdProgress,
    required this.burstProgress,
    required this.showCaret,
  });

  final String title;
  final double coverProgress;
  final double typingProgress;
  final double holdProgress;
  final double burstProgress;
  final bool showCaret;

  @override
  Widget build(BuildContext context) {
    final displayText = _typedText(title, typingProgress);
    final shimmer = ((holdProgress * 1.2) - burstProgress).clamp(0.0, 1.0);
    final breathingGlow = math.sin(holdProgress * math.pi);
    final progressLine = typingProgress < 1
        ? typingProgress
        : 1 + (holdProgress * 0.12);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD84B4B), Color(0xFF9F2525)],
          ),
          boxShadow: [
            BoxShadow(
              color: paletteRed.withValues(
                alpha: 0.24 + (breathingGlow * 0.08),
              ),
              blurRadius: 28 + (breathingGlow * 10),
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -16,
              right: -10,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -24,
              left: -8,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.4 + (shimmer * 2.6), -0.2),
                      end: Alignment(-0.5 + (shimmer * 2.6), 0.4),
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.10 * shimmer),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'LEITURA RECEBIDA',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sincronizando histórico compartilhado',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.50 + (coverProgress * 0.18),
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$displayText${showCaret ? _caretFor(typingProgress) : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20 + (breathingGlow * 0.4),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 2.2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progressLine.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.72 + (breathingGlow * 0.14),
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(
                              alpha: 0.18 + (breathingGlow * 0.08),
                            ),
                            blurRadius: 8,
                            spreadRadius: 0.2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typedText(String text, double progress) {
    if (progress <= 0) return '';
    final visibleCount = (text.length * progress).clamp(0, text.length).ceil();
    return text.substring(0, visibleCount);
  }

  String _caretFor(double progress) {
    final blink = (progress * 10).floor().isEven;
    return blink ? '|' : '';
  }
}

class _BurstParticles extends StatelessWidget {
  const _BurstParticles({required this.progress});

  final double progress;

  static const List<Offset> _vectors = <Offset>[
    Offset(-0.92, -0.40),
    Offset(-0.70, -0.86),
    Offset(-0.28, -1.00),
    Offset(0.22, -0.92),
    Offset(0.74, -0.70),
    Offset(0.98, -0.12),
    Offset(0.84, 0.48),
    Offset(0.30, 0.94),
    Offset(-0.18, 1.00),
    Offset(-0.78, 0.72),
    Offset(-1.00, 0.18),
    Offset(-0.46, 0.14),
  ];

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final opacity = (1 - eased).clamp(0.0, 1.0);

    if (opacity <= 0.001) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < _vectors.length; index++)
              _ParticleDot(
                center: Offset(centerX, centerY),
                direction: _vectors[index],
                distance: 16 + (index % 4) * 8 + (eased * 56),
                size: 4.5 + (index.isEven ? 1.5 : 0),
                color: (index % 3 == 0 ? Colors.white : const Color(0xFFFFC6C6))
                    .withValues(alpha: 0.22 + (opacity * 0.58)),
              ),
          ],
        );
      },
    );
  }
}

class _ParticleDot extends StatelessWidget {
  const _ParticleDot({
    required this.center,
    required this.direction,
    required this.distance,
    required this.size,
    required this.color,
  });

  final Offset center;
  final Offset direction;
  final double distance;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final offset = Offset(
      center.dx + (direction.dx * distance) - (size / 2),
      center.dy + (direction.dy * distance) - (size / 2),
    );

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
