import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/inspection_plan.dart';
import '../models/inspection_result.dart';
import '../models/inspection_step.dart';
import '../services/native_metrology_service.dart';
import 'inspection_report_screen.dart';

class InspectionFlowScreen extends StatefulWidget {
  const InspectionFlowScreen({super.key, required this.plan});

  final InspectionPlan plan;

  @override
  State<InspectionFlowScreen> createState() => _InspectionFlowScreenState();
}

class _InspectionFlowScreenState extends State<InspectionFlowScreen> {
  final ImagePicker _picker = ImagePicker();
  final NativeMetrologyService _metrologyService = NativeMetrologyService();

  static const double _markerSizeMm = 23.0;

  int _currentIndex = 0;
  XFile? _capturedValidationImage;
  bool _isProcessing = false;
  String? _error;

  final Map<String, InspectionResult> _resultsByStepId =
      <String, InspectionResult>{};

  InspectionStep get _currentStep => widget.plan.steps[_currentIndex];

  InspectionResult? get _currentResult => _resultsByStepId[_currentStep.id];

  bool get _isLastStep => _currentIndex >= widget.plan.steps.length - 1;

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 100,
      maxWidth: 4096,
    );
    if (image == null) {
      return;
    }

    setState(() {
      _capturedValidationImage = image;
      _error = null;
    });
  }

  Future<void> _validateCurrentStep() async {
    if (_capturedValidationImage == null) {
      setState(() {
        _error = 'Capture ou selecione a foto desta etapa antes de validar.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final result = await _metrologyService.processStep(
        step: _currentStep,
        imagePath: _capturedValidationImage!.path,
        markerSizeMm: _markerSizeMm,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessing = false;
        _resultsByStepId[_currentStep.id] = result;
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _error = error.message ?? 'Falha na medição nativa.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _error = error.toString();
      });
    }
  }

  void _goToNextStep() {
    if (_currentResult == null) {
      setState(() {
        _error = 'Valide a etapa atual antes de continuar.';
      });
      return;
    }

    if (_isLastStep) {
      final orderedResults = widget.plan.steps
          .map((step) => _resultsByStepId[step.id])
          .whereType<InspectionResult>()
          .toList();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => InspectionReportScreen(
            plan: widget.plan,
            results: orderedResults,
          ),
        ),
      );
      return;
    }

    setState(() {
      _currentIndex += 1;
      _capturedValidationImage = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;
    final result = _currentResult;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Etapa ${_currentIndex + 1} de ${widget.plan.steps.length}',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildInstructionCard(step),
              const SizedBox(height: 12),
              if (_capturedValidationImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_capturedValidationImage!.path),
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Nenhuma foto capturada nesta etapa.'),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      _capturedValidationImage == null
                          ? 'Capturar foto'
                          : 'Refazer foto',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(
                      _capturedValidationImage == null
                          ? 'Selecionar da galeria'
                          : 'Trocar imagem',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _validateCurrentStep,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rule),
                    label: Text(
                      _isProcessing ? 'Validando...' : 'Validar etapa',
                    ),
                  ),
                ],
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (result != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildResultCard(result),
              ],
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _isProcessing ? null : _goToNextStep,
                icon: const Icon(Icons.navigate_next),
                label: Text(
                  _isLastStep ? 'Finalizar inspeção' : 'Próxima etapa',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard(InspectionStep step) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              step.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Vista requerida: ${step.requiredView}'),
            const SizedBox(height: 8),
            Text(step.instruction),
            const SizedBox(height: 8),
            Text('Alvo metrologico: ${step.targetHint}'),
            if (step.sourceCallout.isNotEmpty)
              Text('Cota no desenho: ${step.sourceCallout}'),
            Text(
              'Modo/eixo: ${step.measurementMode.channelValue} / ${step.axisPreference.channelValue}',
            ),
            Text('Classe detectada: ${_labelForClass(step.stepClass)}'),
            Text(
              'Pose sugerida: ${step.recommendedCapturePose} | Risco de oclusao: ${step.occlusionRisk.toUpperCase()}',
            ),
            if (step.hiddenFeatureCandidate)
              const Text(
                'Alerta: etapa com potencial de feature oculta. Considere capturar lado oposto.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 10),
            Text(
              'Esperado: ${step.expectedValue.toStringAsFixed(3)} ${step.unit} | Tolerancia: ±${step.tolerance.toStringAsFixed(3)} ${step.unit}',
            ),
            if (step.verificationFocus.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text('Foco de verificacao:'),
              const SizedBox(height: 4),
              for (final item in step.verificationFocus) Text('- $item'),
            ],
            if (step.captureChecklist.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text('Checklist de captura:'),
              const SizedBox(height: 4),
              for (final item in step.captureChecklist) Text('- $item'),
            ],
            if (step.requiresAllMarkers &&
                step.analysisType == AnalysisType.aruco2d) ...<Widget>[
              const SizedBox(height: 10),
              const Text(
                'Requisito de precisao: os 4 ArUco de 23 mm devem estar totalmente visiveis na foto.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelForClass(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'base':
        return 'BASE';
      case 'height':
        return 'ALTURA';
      case 'thickness':
        return 'ESPESSURA';
      case 'hole':
        return 'FURO';
      case 'chamfer':
        return 'CHANFRO';
      case 'bend':
        return 'DOBRA';
      case 'u_cutout':
        return 'RECORTE_U';
      default:
        return raw.toUpperCase();
    }
  }

  Widget _buildResultCard(InspectionResult result) {
    final statusColor = result.approved
        ? const Color(0xFF1B7F3B)
        : const Color(0xFFB3261E);

    return Card(
      color: result.approved
          ? const Color(0xFFEAF7EE)
          : const Color(0xFFFFF0EE),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              result.approved ? 'Status: APROVADO' : 'Status: REPROVADO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Medido: ${result.measuredValue.toStringAsFixed(3)} ${result.unit}',
            ),
            Text('Delta: ${result.delta.toStringAsFixed(3)} ${result.unit}'),
            Text('Marcadores detectados: ${result.markerCount}'),
            Text('Confianca: ${(result.confidence * 100).toStringAsFixed(1)}%'),
            if (result.debug.isNotEmpty) Text('Debug: ${result.debug}'),
          ],
        ),
      ),
    );
  }
}
