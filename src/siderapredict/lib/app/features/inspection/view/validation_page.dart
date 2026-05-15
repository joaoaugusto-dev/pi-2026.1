import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/core/widgets/measurement_info_card.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/validation_view_model.dart';

class ValidationPage extends StatelessWidget {
  const ValidationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ValidationViewModel>();
    final draft = viewModel.currentDraft;
    final isLoading = viewModel.isLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: buildAppBar(
        context: context,
        title: 'Validação',
        toolbarHeight: 86,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: viewModel.closeAction(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

            if (keyboardOpen) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  18,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: _buildContent(
                  context,
                  draft,
                  viewModel,
                  isLoading,
                  viewModel.primaryDisplay,
                  viewModel.primaryLabel,
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: _buildContent(
                context,
                draft,
                viewModel,
                isLoading,
                viewModel.primaryDisplay,
                viewModel.primaryLabel,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(
        context,
        viewModel,
        draft,
        isLoading,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MeasurementDraft draft,
    ValidationViewModel viewModel,
    bool isLoading,
    String primaryDisplay,
    String primaryLabel,
  ) {
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;
    final processedImageProvider = viewModel.processedImageProvider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: viewModel.showImageAction(context),
          child: Hero(
            tag: 'result_image',
            child: Container(
              height: 240,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: isHighContrast
                    ? BorderRadius.zero
                    : BorderRadius.circular(20),
                boxShadow: isHighContrast ? null : subtleShadows,
                border: Border.all(
                  color: isHighContrast
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  width: isHighContrast ? 2 : 4,
                ),
              ),
              child: ClipRRect(
                borderRadius: isHighContrast
                    ? BorderRadius.zero
                    : BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    processedImageProvider != null
                        ? Image(
                            image: processedImageProvider,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                'Imagem indisponível',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              'Imagem indisponível',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.zoom_out_map,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      primaryDisplay,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                        shadows: isHighContrast ? null : textShadows,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  Text(
                    primaryLabel.toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 32),

        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: isHighContrast
                ? BorderRadius.zero
                : BorderRadius.circular(16),
            boxShadow: isHighContrast ? null : subtleShadows,
            border: isHighContrast
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: viewModel.pieceNameController,
                  focusNode: viewModel.pieceNameFocus,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'IDENTIFICAÇÃO DA PEÇA',
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? Colors.transparent
                      : theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.edit_note, color: theme.colorScheme.primary),
                  onPressed: viewModel.editPieceNameAction(context),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'STATUS DA INSPEÇÃO',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildConformityButton(
                context,
                label: 'CONFORME',
                icon: Icons.check_circle_outline,
                status: ConformityStatus.ok,
                selected: viewModel.conformityStatus == ConformityStatus.ok,
                color: confirmGreen,
                onPressed: viewModel.conformityAction(ConformityStatus.ok),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildConformityButton(
                context,
                label: 'NÃO CONFORME',
                icon: Icons.error_outline,
                status: ConformityStatus.nok,
                selected: viewModel.conformityStatus == ConformityStatus.nok,
                color: theme.colorScheme.error,
                onPressed: viewModel.conformityAction(ConformityStatus.nok),
              ),
            ),
          ],
        ),

        if (viewModel.conformityStatus == ConformityStatus.nok) ...[
          const SizedBox(height: 16),
          _buildNonConformityDetails(context, viewModel, theme, isHighContrast),
        ],

        const SizedBox(height: 24),

        if (draft.isValidMeasurement) ...[
          MeasurementInfoCard(
            title: 'Largura',
            value: '${draft.widthMm.toStringAsFixed(3)} mm',
            delay: const Duration(milliseconds: 100),
          ),
          MeasurementInfoCard(
            title: 'Altura',
            value: '${draft.heightMm.toStringAsFixed(3)} mm',
            delay: const Duration(milliseconds: 200),
          ),
          MeasurementInfoCard(
            title: 'Perímetro',
            value: '${draft.perimeterMm.toStringAsFixed(3)} mm',
            delay: const Duration(milliseconds: 300),
          ),
          MeasurementInfoCard(
            title: 'Área',
            value: '${draft.areaMm2.toStringAsFixed(3)} mm²',
            delay: const Duration(milliseconds: 400),
          ),
          if (draft.scaleMicronsPerPx != null)
            MeasurementInfoCard(
              title: 'Escala',
              value: '${draft.scaleMicronsPerPx!.toStringAsFixed(3)} µm/px',
              delay: const Duration(milliseconds: 500),
            ),

          const SizedBox(height: 24),

          if (draft.segments.isNotEmpty) ...[
            Text(
              'SEGMENTOS DETALHADOS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: isHighContrast
                    ? BorderRadius.zero
                    : BorderRadius.circular(16),
                boxShadow: isHighContrast ? null : subtleShadows,
                border: isHighContrast
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < draft.segments.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: isHighContrast
                            ? theme.colorScheme.primary
                            : Colors.grey.shade200,
                      ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      title: Text(
                        draft.segments[i].label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        draft.segments[i].type.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Text(
                        draft.segments[i].displayValue,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: isHighContrast
                  ? BorderRadius.zero
                  : BorderRadius.circular(16),
              boxShadow: isHighContrast ? null : subtleShadows,
              border: Border.all(
                color: isHighContrast
                    ? theme.colorScheme.primary
                    : paletteRed.withValues(alpha: 0.3),
                width: isHighContrast ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: isHighContrast
                      ? theme.colorScheme.primary
                      : paletteRed,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    viewModel.validationErrorMessage,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBottomButtons(
    BuildContext context,
    ValidationViewModel viewModel,
    MeasurementDraft draft,
    bool isLoading,
  ) {
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 8
            : 20,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isHighContrast
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.05),
            width: isHighContrast ? 2 : 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 60,
              child: OutlinedButton(
                onPressed: isLoading ? null : viewModel.retakeAction(context),
                style:
                    theme.outlinedButtonTheme.style ??
                    OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                child: const Text(
                  'REFAZER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: isHighContrast
                    ? BorderRadius.zero
                    : BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: (isLoading || !draft.isValidMeasurement)
                    ? null
                    : viewModel.saveAction(context),
                style:
                    theme.elevatedButtonTheme.style?.copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.disabled)) return null;
                        return isHighContrast
                            ? theme.colorScheme.primary
                            : confirmGreen;
                      }),
                    ) ??
                    ElevatedButton.styleFrom(
                      backgroundColor: confirmGreen,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: theme.colorScheme.onPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SALVAR',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConformityButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required ConformityStatus status,
    required bool selected,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        decoration: BoxDecoration(
          color: selected
              ? (isHighContrast
                    ? theme.colorScheme.primary
                    : (theme.brightness == Brightness.dark
                          ? theme.colorScheme.primary
                          : color))
              : theme.colorScheme.surface,
          borderRadius: isHighContrast
              ? BorderRadius.zero
              : BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? (isHighContrast
                      ? theme.colorScheme.primary
                      : (theme.brightness == Brightness.dark
                            ? theme.colorScheme.primary
                            : color))
                : (isHighContrast
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            width: 2,
          ),
          boxShadow: selected && !isHighContrast
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : (isHighContrast
                        ? theme.colorScheme.primary
                        : (theme.brightness == Brightness.dark
                              ? theme.colorScheme.primary
                              : color)),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? theme.colorScheme.onPrimary
                    : (isHighContrast
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface),
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonConformityDetails(
    BuildContext context,
    ValidationViewModel viewModel,
    ThemeData theme,
    bool isHighContrast,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'MOTIVO DA REPROVAÇÃO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: viewModel.nonConformityReasons.map((reason) {
            final isSelected = viewModel.nonConformityReason == reason;
            return RawChip(
              label: Text(reason),
              selected: isSelected,
              onSelected: viewModel.nonConformityReasonAction(reason),
              showCheckmark: false,
              selectedColor: isHighContrast
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondaryContainer,
              backgroundColor: theme.colorScheme.surface,
              pressElevation: 0,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isHighContrast
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSecondaryContainer)
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: isHighContrast
                    ? BorderRadius.zero
                    : BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? (isHighContrast
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: isHighContrast
                ? BorderRadius.zero
                : BorderRadius.circular(12),
            border: Border.all(
              color: isHighContrast
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: TextField(
            onChanged: viewModel.onNonConformityObservationChanged,
            maxLines: 2,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Observações adicionais (opcional)...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                fontSize: 14,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
