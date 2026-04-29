import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/routes/app_pages.dart';
import 'package:siderapredict/app/routes/app_routes.dart';
import 'package:siderapredict/app/core/theme/theme.dart';
import 'package:siderapredict/app/core/widgets/info_card.dart';
import 'package:siderapredict/app/core/widgets/zoomable_image_overlay.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_viewmodel.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/validation_viewmodel.dart';

class ValidacaoPage extends StatefulWidget {
  const ValidacaoPage({super.key, required this.draft});

  final MeasurementDraft draft;

  @override
  State<ValidacaoPage> createState() => _ValidacaoPageState();
}

class _ValidacaoPageState extends State<ValidacaoPage> {
  late final TextEditingController _pieceNameController;
  final FocusNode _pieceNameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<ValidationViewModel>();
    _pieceNameController = TextEditingController(text: viewModel.pieceName);
    _pieceNameController.addListener(() {
      viewModel.updatePieceName(_pieceNameController.text);
    });
  }

  @override
  void dispose() {
    _pieceNameController.dispose();
    _pieceNameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final viewModel = context.read<ValidationViewModel>();
    final record = await viewModel.save();

    if (!mounted) return;

    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.lastError ?? 'Não foi possível salvar.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Medição salva com sucesso.')));

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.menuPrincipal, (route) => false);
  }

  void _retake() {
    final viewModel = context.read<ValidationViewModel>();
    final inspectionViewModel = context.read<InspectionViewModel>();
    viewModel.retake();
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.camera,
      arguments: CameraArgs(cameras: inspectionViewModel.availableCameras),
    );
  }

  void _showImageOverlay() {
    if (widget.draft.processedImagePath.isEmpty) return;
    ZoomableImageOverlay.show(
      context,
      imageProvider: FileImage(File(widget.draft.processedImagePath)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final viewModel = context.watch<ValidationViewModel>();
    final isLoading = viewModel.isLoading;

    final primaryDisplay = draft.isValidMeasurement
        ? '${draft.primaryValueMm.toStringAsFixed(3)} mm'
        : '--';
    final primaryLabel = draft.isValidMeasurement
        ? 'Medida principal'
        : 'Aguardando medida válida';

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: buildAppBar(
        context: context,
        title: 'Validação',
        toolbarHeight: 86,
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
                  primaryDisplay,
                  primaryLabel,
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
                primaryDisplay,
                primaryLabel,
              ),
            );
          },
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        
        GestureDetector(
          onTap: _showImageOverlay,
          child: Hero(
            tag: 'result_image',
            child: Container(
              height: 240,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: whiteColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: subtleShadows,
                border: Border.all(color: whiteColor, width: 4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    draft.processedImagePath.isNotEmpty
                        ? Image.file(
                            File(draft.processedImagePath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Text('Imagem indisponível'),
                            ),
                          )
                        : const Center(child: Text('Imagem indisponível')),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: blackColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.zoom_out_map,
                          color: whiteColor,
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
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        shadows: textShadows,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  Text(
                    primaryLabel.toUpperCase(),
                    style: TextStyle(
                      color: darkTextColor.withValues(alpha: 0.6),
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
            color: whiteColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: subtleShadows,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pieceNameController,
                  focusNode: _pieceNameFocus,
                  style: const TextStyle(
                    color: darkTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'IDENTIFICAÇÃO DA PEÇA',
                    labelStyle: TextStyle(
                      color: darkTextColor.withValues(alpha: 0.4),
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
                  color: backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_note, color: primaryColor),
                  onPressed: () =>
                      FocusScope.of(context).requestFocus(_pieceNameFocus),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        
        if (draft.isValidMeasurement) ...[
          InfoCard(
            title: 'Largura',
            value: '${draft.widthMm.toStringAsFixed(3)} mm',
            delay: const Duration(milliseconds: 100),
          ),
          InfoCard(
            title: 'Altura',
            value: '${draft.heightMm.toStringAsFixed(3)} mm',
            delay: const Duration(milliseconds: 200),
          ),
          InfoCard(
            title: 'Perímetro',
            value: '${draft.perimeterMm.toStringAsFixed(3)} mm',
            delay: const Duration(milliseconds: 300),
          ),
          InfoCard(
            title: 'Área',
            value: '${draft.areaMm2.toStringAsFixed(3)} mm²',
            delay: const Duration(milliseconds: 400),
          ),
          if (draft.scaleMicronsPerPx != null)
            InfoCard(
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
                color: darkTextColor.withValues(alpha: 0.5),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: whiteColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: subtleShadows,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < draft.segments.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: backgroundLight),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      title: Text(
                        draft.segments[i].label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        draft.segments[i].type.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: darkTextColor.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Text(
                        draft.segments[i].displayValue,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
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
              color: whiteColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: subtleShadows,
              border: Border.all(color: paletteRed.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: paletteRed,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _getErrorMessage(draft),
                    style: const TextStyle(
                      color: darkTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 40),

        
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 64,
                child: OutlinedButton(
                  onPressed: isLoading ? null : _retake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: darkTextColor.withValues(alpha: 0.6),
                    side: BorderSide(
                      color: darkTextColor.withValues(alpha: 0.1),
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
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: (isLoading || !draft.isValidMeasurement)
                      ? null
                      : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmGreen,
                    foregroundColor: whiteColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: whiteColor,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, color: whiteColor),
                            const SizedBox(width: 12),
                            const Text(
                              'SALVAR',
                              style: TextStyle(
                                color: whiteColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  String _getErrorMessage(MeasurementDraft draft) {
    if (!draft.calibrationSuccess) {
      return draft.extraInfo?.trim().isNotEmpty == true
          ? draft.extraInfo!
          : 'Falha na calibração de Ar Markers. Mantenha as bordas visíveis ao redor da peça e recapture.';
    }
    if (!draft.objectFound) {
      return draft.extraInfo?.trim().isNotEmpty == true
          ? draft.extraInfo!
          : 'Calibração Ar Markers concluída, mas a peça não foi isolada para medição. Ajuste o enquadramento e refaça.';
    }
    return draft.extraInfo?.trim().isNotEmpty == true
        ? draft.extraInfo!
        : 'A homografia Ar Markers foi calculada, mas nenhuma medida válida da peça foi extraída nesta captura.';
  }
}
